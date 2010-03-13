require 'tk'
require 'drx/tk/imagemap'

module Drx
  module TkGUI

    # The 'DRX_EDITOR_COMMAND' environment variable overrides this.
    EDITOR_COMMAND = 'gedit +%d "%s"'

    class ScrolledListbox < TkFrame
      def initialize(*args, &block)
        super(*args, &block)
        @the_list = the_list = TkListbox.new(self) {
          #pack :side => 'left'#, :expand => 'true', :fill => 'both'
        }
        TkScrollbar.new(self) { |s|
          pack :side => 'right', :fill => 'y'
          command { |*args| the_list.yview *args }
          the_list.yscrollcommand { |first,last| s.set first,last }
        }
        TkScrollbar.new(self) { |s|
          orient 'horizontal'
          pack :side => 'bottom', :fill => 'x'
          command { |*args| the_list.xview *args }
          the_list.xscrollcommand { |first,last| s.set first,last }
        }
        @the_list.pack(:side => 'left', :expand => 'true', :fill => 'both')
      end
      def the_list
        @the_list
      end
      def winfo_reqwidth
        return the_list.winfo_reqwidth + 10
      end
    end

    class ::TkListbox
      def get_selection
        idx = curselection[0]
        return get(idx)
      end
      def get_index
        curselection[0]
      end
    end

    class DrxWindow
      def initialize
        @stack = []
        root = TkRoot.new
        @evalbox = TkEntry.new(root) {
          font 'Courier'
          pack(:side => 'bottom', :fill => 'both')
        }
        TkLabel.new(root, :anchor => 'w') {
          text 'Type some code to eval in the context of the selected object; prepend with "see" to examine it.'
          pack(:side => 'bottom', :fill => 'both')
        }

        @panes = TkPanedwindow.new(root, :orient => :horizontal)
        @panes.pack(:side => :top, :expand => true, :fill=> :both, :pady => 2, :padx => '2m')

        @im = TkImageMap::ImageMap.new(@panes)
        @panes.add(@im, :minsize => 400)
        @im.select_command { |url|
          if url
            puts 'clicked: ' + @objs[url].repr
            select_object @objs[url].the_object
          else
            puts 'cleared'
            select_object nil
          end
        }
        @im.double_select_command { |url|
          puts 'going to ' + url
          navigate_to_selected
        }
        @im.bind('ButtonRelease-3') {
          back
        }

        @varsbox = (ScrolledListbox.new(@panes) {
          #pack :side => 'left', :fill => 'both', :expand => true
        })
        @varsbox.the_list.width 25
        @panes.add(@varsbox, :minsize => @varsbox.winfo_reqwidth)
        @varsbox = @varsbox.the_list

        @methodsbox = (ScrolledListbox.new(@panes) {
          #pack :side => 'left', :fill => 'both', :expand => true
        })
        @methodsbox.the_list.width 35
        @panes.add(@methodsbox, :minsize => @methodsbox.winfo_reqwidth)
        @methodsbox = @methodsbox.the_list

        @varsbox.bind('<ListboxSelect>') {
          print "\n== Variable #{@varsbox.get_selection}\n\n"
          p selected_var
        }
        @varsbox.bind('Double-Button-1') {
          see selected_var
        }
        @varsbox.bind('ButtonRelease-3') {
          require 'pp'
          print "\n== Variable #{@varsbox.get_selection}\n\n"
          pp selected_var
        }
        @evalbox.bind('Key-Return') {
          eval_code
        }
        @methodsbox.bind('Double-Button-1') {
          locate_method(current_object, @methodsbox.get_selection)
        }
      end

      def open_up_editor(filename, lineno)
        command = sprintf(ENV['DRX_EDITOR_COMMAND'] || EDITOR_COMMAND, lineno, filename)
        puts "Execting: #{command}..."
        if !fork
          if !Kernel.system(command)
            puts "Could not execure the command '#{command}'"
          end
          exit!
        end
      end

      def locate_method(obj, method_name)
        place = ObjInfo.new(obj).locate_method(method_name)
        if !place
          puts "Method #{method_name} doesn't exist"
        else
          if place =~ /\A(\d+):(.*)/
            open_up_editor($2, $1)
          else
            puts "Can't locate method, because: #{place}"
          end
        end
      end

      def back
        if @stack.size > 1
          @stack.pop
          see @stack.pop
        end
      end

      def selected_var
        ObjInfo.new(current_object).__get_ivar(@varsbox.get_selection)
      end

      def eval_code
        code = @evalbox.get.strip
        see = !!code.sub!(/^see\s/, '')
        result = current_object.instance_eval(code)
        p result
        see(result) if see
      end

      def current_object
        # For some reason, even though ICLASS contains a copy of the iv_tbl of
        # its 'klass', these variables are all nil. I think in all cases we'd
        # want to see the module itself, so that's what we're going to do:
        info = Drx::ObjInfo.new(@current_object)
        if info.t_iclass?
          # The following line is equivalent to 'Core::get_klass(@current_object)'
          info.klass.the_object
        else
          @current_object
        end
      end

      # Fills the variables listbox with a list of the object's instance variables.
      def display_variables(obj)
        @varsbox.delete('0', 'end')
        info = ObjInfo.new(obj)
        if obj and info.has_iv_tbl?
          vars = info.iv_tbl.keys.map do |v| v.to_s end.sort
          # Get rid of gazillions of Tk classes:
          vars = vars.reject { |v| v =~ /Tk|Ttk/ }
          @varsbox.insert('end', *vars)
        end
      end

      # Fills the methods listbox with a list of the object's methods.
      def display_methods(obj)
        @methodsbox.delete('0', 'end')
        info = ObjInfo.new(obj)
        if obj and info.class_like?
          methods = info.m_tbl.keys.map do |v| v.to_s end.sort
          @methodsbox.insert('end', *methods)
        end
      end

      # Loads the imagemap widget with a diagram of the object.
      def display_graph(obj)
        @objs = {}
        files = ObjInfo.new(obj).get_diagram do |info|
          @objs[info.dot_url] = info
        end
        @im.image = files['gif']
        @im.image_map = files['map']
      ensure
        files.unlink if files
      end

      # Makes `obj` the primary object seen (the one who is the root of the diagram).
      def navigate_to(obj)
        @current_object = obj
        @stack << obj
        display_graph(obj)
        # Trigger the update of the variables and methods tables by selecting this object
        # in the imagemap.
        @im.active_url = @im.urls.first
      end
      alias see navigate_to

      # Make `obj` the selected object. That is, the one the variable and method boxes reflect.
      def select_object(obj)
         @current_object = obj
         display_variables(current_object)
         display_methods(current_object)
      end

      # Navigate_to the selected object.
      def navigate_to_selected
        # current_object() descends T_ICLASS for us.
        navigate_to(current_object)
      end

      def run
        # @todo Skip this if Tk is already running.
        Tk.mainloop
        Tk.restart # So that Tk doesn't complain 'can't invoke "frame" command: application has been destroyed' next time.
      end
    end

  end # module TkGUI
end # module Drx
