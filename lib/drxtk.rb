require 'drx'
require 'tk'

module Drx
  def self.examinetk(obj)
    app = Drx::TkGUI::DrxWindow.new
    app.see(obj)
    app.run
  end

  # easier to type...
  def self.see(obj)
    examinetk(obj)
  end
end

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
        @list = (ScrolledListbox.new(root) {
          pack :side => 'left', :fill => 'both', :expand => true
        }).the_list
        @list.width 52
        @list.height 25
        @list.focus
        @varsbox = (ScrolledListbox.new(root) {
          pack :side => 'left', :fill => 'both', :expand => true
        }).the_list
        @methodsbox = (ScrolledListbox.new(root) {
          pack :side => 'left', :fill => 'both', :expand => true
        }).the_list

        @list.bind('<ListboxSelect>') {
          @current_object = @objs[@list.get_index]
          display_variables(current_object)
          display_methods(current_object)
        }
        @list.bind('ButtonRelease-3') {
          back
        }
        @list.bind('Double-Button-1') {
          descend_iclass
        }
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
        place = Drx.locate_method(obj, method_name)
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
        Drx.get_ivar(current_object, @varsbox.get_selection)
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
        if Drx.get_type(@current_object) == Drx::T_ICLASS
          Drx.get_klass(@current_object)
        else
          @current_object
        end
      end

      def display_variables(obj)
        @varsbox.delete('0', 'end')
        if (Drx.has_iv_tbl(obj)) 
          vars = Drx.get_iv_tbl(obj).keys.map do |v| v.to_s end.sort
          # Get rid of gazillions of Tk classes:
          vars = vars.reject { |v| v =~ /Tk|Ttk/ }
          @varsbox.insert('end', *vars)
        end
      end
      
      def display_methods(obj)
        @methodsbox.delete('0', 'end')
        if (Drx.is_class_like(obj)) 
          methods = Drx.get_m_tbl(obj).keys.map do |v| v.to_s end.sort
          @methodsbox.insert('end', *methods)
        end
      end
      
      def display_hierarchy(obj)
        @list.delete('0', 'end')
        @objs = []
        Drx.examine(obj) do |line, o|
          @list.insert('end', line)
          @objs << o
        end
      end
      
      def see(obj)
        @current_object = obj
        @stack << obj
        display_hierarchy(obj)
        display_variables(obj)
        display_methods(obj)
      end
      
      def descend_iclass
        # current_object() descends T_ICLASS for us.
        see(current_object)
      end

      def run
        # @todo Skip this if Tk is already running.
        Tk.mainloop
        Tk.restart # So that Tk doesn't complain 'can't invoke "frame" command:  application has been destroyed' next time.
      end
    end

  end # module TkGUI
end # module Drx
