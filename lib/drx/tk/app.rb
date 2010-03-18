require 'tk'
#Tk.default_widget_set = :Ttk
require 'drx/tk/imagemap'

module Drx
  module TkGUI

    # The 'DRX_EDITOR_COMMAND' environment variable overrides this.
    EDITOR_COMMAND = 'gedit +%d "%s"'

    class Application

      def toplevel
        @toplevel ||= TkRoot.new
      end

      def initialize
        @stack = []
        @eval_history = LineHistory.new

        @eval_entry = TkEntry.new(toplevel) {
          font 'Courier'
        }
        @eval_result = TkText.new(toplevel) {
          font 'Courier'
          height 4
          foreground 'black'
          background 'white'
          tag_configure('error', :foreground => 'red')
          tag_configure('info', :foreground => 'blue')
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

        @varsbox = TkListbox.new(toplevel) {
          width 25
        }
        @methodsbox = TkListbox.new(toplevel) {
          width 35
        }

        layout

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
          code = @eval_entry.value.strip
          if code != ''
            @eval_history.add code.dup
            eval_code code
            @eval_entry.value = ''
          end
        }
        @eval_entry.bind('Key-Up') {
          @eval_entry.value = @eval_history.prev!
        }
        @eval_entry.bind('Key-Down') {
          @eval_entry.value = @eval_history.next!
        }
        toplevel.bind('Control-l') {
          @eval_entry.focus
        }
        toplevel.bind('Control-r') {
          # Refresh the display. Useful if you eval'ed some code that changes the
          # object inspected.
          navigate_to tip
          # Note: it seems that #instance_eval creates a singleton for the object.
          # So after eval'ing something and pressing C-r, you're going to see this
          # extra class.
        }

        output "Please visit the homepage, http://drx.rubyforge.org/, for usage instructions.\n", 'info'
      end

      # Arrange the main widgets inside layout widgets.
      def layout
        main_frame = TkPanedwindow.new(toplevel, :orient => :vertical) {
          pack :side => :top, :expand => true, :fill=> :both, :pady => 2, :padx => 2
          # We push layout widgets below the main widgets in the stacking order.
          # We don't want them to obscure the main ones.
          lower
        }
        main_frame.add VBox.new toplevel, [
          [Scrolled.new(toplevel, @eval_result, :vertical => true), { :expand => true, :fill => 'both' } ],
          TkLabel.new(toplevel, :anchor => 'w') {
            text 'Type some code to eval; \'self\' is the object at tip of diagram; prepend with "see" to examine result.'
          },
          @eval_entry,
        ]

        panes = TkPanedwindow.new(main_frame, :orient => :horizontal) {
          lower
        }
        panes.add VBox.new toplevel, [
          TkLabel.new(toplevel, :text => 'Object graph (klass and super):', :anchor => 'w'),
          [@im, { :expand => true, :fill => 'both' } ],
        ]
        panes.add VBox.new toplevel, [
          TkLabel.new(toplevel, :text => 'Variables (iv_tbl):', :anchor => 'w'),
          [Scrolled.new(toplevel, @varsbox), { :expand => true, :fill => 'both' } ]
        ]
        panes.add VBox.new toplevel, [
          TkLabel.new(toplevel, :text => 'Methods (m_tbl):', :anchor => 'w'),
          [Scrolled.new(toplevel, @methodsbox), { :expand => true, :fill => 'both' } ]
        ]

        main_frame.add(panes)
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

      def eval_code(code)
        see = !!code.sub!(/^see\s/, '')
        begin
          result = tip.instance_eval(code)
          output result.inspect + "\n"
        rescue StandardError, ScriptError => ex
          gist = "%s: %s" % [ex.class, ex.message]
          trace = ex.backtrace.reverse.drop_while { |line| line !~ /eval_code/ }.reverse
          output gist + "\n" + trace.join("\n") + "\n", 'error'
        end
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
        require 'drx/tempfiles'
        @objs = {}
        Tempfiles.new do |files|
          ObjInfo.new(obj).generate_diagram(files) do |info|
            @objs[info.dot_url] = info
          end
          @im.image = files['gif']
          @im.image_map = files['map']
        end
      end

      # Makes `obj` the primary object seen (the one which is the tip of the diagram).
      def navigate_to(obj)
        @current_object = obj
        @stack << obj
        display_graph(obj)
        # Trigger the update of the variables and methods tables by selecting this object
        # in the imagemap.
        @im.active_url = @im.urls.first
      end
      alias see navigate_to

      # Returns the tip object in the diagram (the one passed to navigate_to())
      def tip
        #@objs[@im.urls.first].the_object
        @stack.last
      end

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

    # Manages history for an input line.
    class LineHistory
      def initialize
        @entries = []
        @pos = 0
      end
      def past_end?
        @pos >= @entries.size
      end
      def add(s)
        @entries.reject! { |ent| ent == s }
        @entries << s
        @pos = @entries.size
      end
      def prev!
        @pos -= 1 if @pos > 0
        current
      end
      def next!
        @pos += 1 if not past_end?
        current
      end
      def current
        past_end? ? '' : @entries[@pos]
      end
    end

    # Wraps scrollbars around a widget.
    class Scrolled < TkFrame
      def initialize(parent, the_widget, opts = { :vertical => true, :horizontal => true })
        super(parent)
        @the_widget = the_widget
        if opts[:vertical]
          TkScrollbar.new(self) { |s|
            pack :side => 'right', :fill => 'y'
            command { |*args| the_widget.yview *args }
            the_widget.yscrollcommand { |first,last| s.set first,last }
          }
        end
        if opts[:horizontal]
          TkScrollbar.new(self) { |s|
            orient 'horizontal'
            pack :side => 'bottom', :fill => 'x'
            command { |*args| the_widget.xview *args }
            the_widget.xscrollcommand { |first,last| s.set first,last }
          }
        end
        the_widget.raise  # Since the frame is created after the widget, it obscures it by default.
        the_widget.pack(:in => self, :side => 'left', :expand => 'true', :fill => 'both')
      end
      def raise
        super
        @the_widget.raise
      end
    end

    # Arranges widgets one below the other.
    class VBox < TkFrame
      def initialize(parent, widgets)
        super(parent)
        widgets.each { |w, layout|
          layout = {} if layout.nil?
          layout = { :in => self, :side => 'top', :fill => 'x' }.merge layout
          w.raise
          w.pack(layout)
        }
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

  end # module TkGUI
end # module Drx
