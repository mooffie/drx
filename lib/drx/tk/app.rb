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

      def toplevel
        @toplevel ||= TkRoot.new
      end

      def initialize
        @stack = []

        layout_begin

        @eval_entry = TkEntry.new(toplevel) {
          font 'Courier'
        }
        @eval_result = TkText.new(toplevel) {
          font 'Courier'
        }
        @eval_label = TkLabel.new(toplevel, :anchor => 'w') {
          text 'Type some code to eval in the context of the selected object; prepend with "see" to examine it.'
        }

        @im = TkImageMap::ImageMap.new(toplevel)
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

        @varsbox = ScrolledListbox.new(toplevel)
        @varsbox.the_list.width 25

        @methodsbox = ScrolledListbox.new(toplevel)
        @methodsbox.the_list.width 35

        layout_finish

        @methodsbox = @methodsbox.the_list
        @varsbox = @varsbox.the_list

        @varsbox.bind('<ListboxSelect>') {
          require 'pp'
          output "\n== Variable #{@varsbox.get_selection}\n\n", 'info'
          output PP.pp(selected_var, '')
        }
        @varsbox.bind('ButtonRelease-3') {
          output "\n== Variable #{@varsbox.get_selection}\n\n", 'info'
          output selected_var.inspect + "\n"
        }
        @varsbox.bind('Double-Button-1') {
          see selected_var
        }
        @methodsbox.bind('Double-Button-1') {
          locate_method(current_object, @methodsbox.get_selection)
        }
        @eval_entry.bind('Key-Return') {
          eval_code
        }

        @eval_result.tag_configure('error', :foreground => 'red')
        @eval_result.tag_configure('info', :foreground => 'blue')

        output "Please visit the homepage, http://drx.rubyforge.org/, for usage instructions.\n", 'info'
      end

      # Create layout widgets.
      #
      # A layout widget must be created before the widget it wishes
      # to control is created (it's a Tk issue); that's why this method
      # is called early on.
      def layout_begin
        @main_frame = TkPanedwindow.new(toplevel, :orient => :vertical)
        @panes = TkPanedwindow.new(@main_frame, :orient => :horizontal)
        @eval_combo = TkFrame.new(toplevel)
      end

      # Arrange the main widgets inside layout widgets.
      def layout_finish
        @main_frame.pack(:side => :top, :expand => true, :fill=> :both, :pady => 2, :padx => '2m')

        @eval_result.height = 4
        @eval_result.pack(:in => @eval_combo, :side => 'top', :fill => 'both', :expand => true)
        @eval_entry.pack(:in => @eval_combo, :side => 'bottom', :fill => 'both')
        @eval_label.pack(:in => @eval_combo, :side => 'bottom', :fill => 'both')

        @main_frame.add(@eval_combo)

        # @todo Tk::Tile::PanedWindow doesn't support :minsize ?
        #@panes.add(@im, :minsize => 400)
        #@panes.add(@varsbox, :minsize => @varsbox.winfo_reqwidth)
        #@panes.add(@methodsbox, :minsize => @methodsbox.winfo_reqwidth)
        @panes.add(@im)
        @panes.add(@varsbox)
        @panes.add(@methodsbox)

        @main_frame.add(@panes)
      end

      # Output some text. It goes to the result textarea.
      def output(s, tag=nil)
        @eval_result.insert('end', s, Array(tag))
        # Scroll to the bottom.
        @eval_result.mark_set('insert', 'end')
        @eval_result.see('end')
      end

      def open_up_editor(filename, lineno)
        command = sprintf(ENV['DRX_EDITOR_COMMAND'] || EDITOR_COMMAND, lineno, filename)
        output "Execting: #{command}...\n", 'info'
        if !fork
          if !Kernel.system(command)
            output "Could not execute the command '#{command}'\n", 'error'
          end
          exit!
        end
      end

      def locate_method(obj, method_name)
        place = ObjInfo.new(obj).locate_method(method_name)
        if !place
          output "Method #{method_name} doesn't exist\n", 'info'
        else
          if place =~ /\A(\d+):(.*)/
            open_up_editor($2, $1)
          else
            output "Can't locate method, because: #{place}\n", 'info'
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
        code = @eval_entry.get.strip
        see = !!code.sub!(/^see\s/, '')
        result = current_object.instance_eval(code)
        output result.inspect + "\n"
        #require 'pp'; output PP.pp(result, '')
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
