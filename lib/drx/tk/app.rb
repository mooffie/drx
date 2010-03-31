require 'tk'
require 'drx/tk/imagemap'

Tk.default_widget_set = :Ttk

module Drx
  module TkGUI

    # The 'DRX_EDITOR_COMMAND' environment variable overrides this.
    EDITOR_COMMAND = 'gedit +%d "%s"'

    class Application

      def toplevel
        @toplevel ||= TkRoot.new
      end

      def initialize
        @navigation_history = []
        @eval_history = LineHistory.new
        @graph_opts = { :size => '100%', :style => 'default' }

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
            select_object @objs[url].the_object
          else
            select_object nil
          end
        }
        @im.double_select_command { |url|
          navigate_to_selected
        }
        @im.bind('ButtonRelease-3') {
          navigate_back
        }

        @varsbox = Tk::Tile::Treeview.new(toplevel) {
          columns 'name value'
          heading_configure('name', :text => 'Name')
          heading_configure('value', :text => 'Value')
          column_configure('name', :stretch => false )
          column_configure('value', :stretch => false )
          show 'headings'
        }
        @methodsbox = Tk::Tile::Treeview.new(toplevel) {
          columns 'name location'
          heading_configure('name', :text => 'Name')
          heading_configure('location', :text => 'Location')
          column_configure('name', :stretch => false )
          column_configure('location', :stretch => false )
          show 'headings'
        }

        @graph_size_menu = Tk::Tile::Combobox.new(toplevel) {
          set '100%'
          values ['100%', '90%', '80%', '60%']
          state :readonly
          width 6
        }
        @graph_style_menu = Tk::Tile::Combobox.new(toplevel) {
          set 'default'
          values ['default', 'crazy']
          state :readonly
          width 10
        }
        @save_btn = TkButton.new(toplevel) {
          text 'Save...'
        }
        @save_btn.command {
          save_graph tip
        }

        layout

        @varsbox.bind('<TreeviewSelect>') {
          if @varsbox.has_selection?
            require 'pp'
            output "\n== Variable #{@varsbox.get_selection}\n\n", 'info'
            output PP.pp(selected_var, '')
          end
        }
        @varsbox.bind('ButtonRelease-3') {
          if @varsbox.has_selection?
            output "\n== Variable #{@varsbox.get_selection}\n\n", 'info'
            output selected_var.inspect + "\n"
          end
        }
        @varsbox.bind('Double-Button-1') {
          if @varsbox.has_selection?
            see selected_var
          end
        }
        @methodsbox.bind('Double-Button-1') {
          if @methodsbox.has_selection?
            edit(current_object, @methodsbox.get_selection)
          end
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
          refresh
          # Note: it seems that #instance_eval creates a singleton for the object.
          # So after eval'ing something and pressing C-r, you're going to see this
          # extra class.
        }
        @graph_size_menu.bind('<ComboboxSelected>') {
          @graph_opts[:size] = @graph_size_menu.get
          refresh
        }
        @graph_style_menu.bind('<ComboboxSelected>') {
          @graph_opts[:style] = @graph_style_menu.get
          refresh
        }

        output "Please visit the homepage, http://drx.rubyforge.org/, for usage instructions.\n", 'info'

        one_time_initialization
        user_customizations
      end

      def one_time_initialization
        @@one_time_initialization ||= begin
          # Try to make the Unixy GUI less ugly.
          if Tk.windowingsystem == 'x11' and Ttk.themes.include? 'clam'
            Ttk.set_theme 'clam'
          end
          rc = File.join(ENV['HOME'] || Dir.pwd, '.drxrc')
          load rc if File.exist? rc
          1
        end
      end

      # Users may redefine this method in their ~/.drxrc
      # to fine-tune the app.
      def user_customizations
      end

      def vbox(*args); VBox.new(toplevel, args); end
      def hbox(*args); HBox.new(toplevel, args); end
      def separator; TkLabel.new(toplevel, :text => '  '); end

      # Arrange the main widgets inside layout widgets.
      def layout
        main_frame = TkPanedwindow.new(toplevel, :orient => :vertical) {
          pack :side => :top, :expand => true, :fill=> :both, :pady => 2, :padx => 2
          # We push layout widgets below the main widgets in the stacking order.
          # We don't want them to obscure the main ones.
          lower
        }
        main_frame.add vbox(
          [Scrolled.new(toplevel, @eval_result, :vertical => true), { :expand => true, :fill => 'both' } ],
          TkLabel.new(toplevel, :anchor => 'w') {
            text 'Type some code to eval; \'self\' is the object at the base of the graph; prepend with "see" to inspect result.'
          },
          @eval_entry
        )

        panes = TkPanedwindow.new(main_frame, :orient => :horizontal) {
          lower
        }
        # Note the :weight's on the followings.
        panes.add vbox(
          TkLabel.new(toplevel, :text => 'Object graph (klass and super):', :anchor => 'w'),
          [Scrolled.new(toplevel, @im), { :expand => true, :fill => 'both' } ],
          hbox(TkLabel.new(toplevel, :text => 'Size: '), @graph_size_menu,
               separator,
               TkLabel.new(toplevel, :text => 'Style: '), @graph_style_menu,
               separator,
               [@save_btn, { :pady => 5 }])
        ), :weight => 10
        panes.add vbox(
          TkLabel.new(toplevel, :text => 'Variables (iv_tbl):', :anchor => 'w'),
          [Scrolled.new(toplevel, @varsbox), { :expand => true, :fill => 'both' } ]
        ), :weight => 50
        panes.add vbox(
          TkLabel.new(toplevel, :text => 'Methods (m_tbl):', :anchor => 'w'),
          [Scrolled.new(toplevel, @methodsbox), { :expand => true, :fill => 'both' } ]
        ), :weight => 10

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
        output "Executing: #{command}...\n", 'info'
        if !fork
          if !Kernel.system(command)
            output "Could not execute the command '#{command}'\n", 'error'
          end
          exit!
        end
      end

      def edit(obj, method_name)
        location = ObjInfo.new(obj).locate_method(method_name) rescue nil
        if !location
          output "Method #{method_name} doesn't exist\n", 'info'
        else
          if location.is_a? String
            output "Can't locate method, because it's a: #{location}\n", 'info'
          else
            open_up_editor(location[0], location[1])
          end
        end
      end

      def navigate_back
        if @navigation_history.size > 1
          @navigation_history.pop
          see @navigation_history.pop
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
        allowed_names = [/^@/, /^[A-Z]/, '__classpath__', '__tmp_classpath__', '__classid__', '__attached__']
        @varsbox.clear
        info = ObjInfo.new(obj)
        if obj and info.has_iv_tbl?
          vars = info.iv_tbl.keys.map do |v| v.to_s end.sort
          # Get rid of gazillions of Tk classes:
          vars = vars.reject { |v| v =~ /Tk|Ttk/ }
          vars.each do |name|
            value = if allowed_names.any? { |p| p === name }
                      info.__get_ivar(name).inspect
                    else
                      # We don't want to inspect ruby's internal variables (because
                      # they may not be Ruby values at all).
                      ''
                    end
            @varsbox.insert('', 'end', :text => name, :values => [ name, value ] )
          end
        end
      end

      # Returns a terse method location, for use in GUIs.
      def pretty_location(info, method)
        location = begin
                     info.locate_method(method)
                   rescue NameError
                     if method != '<Allocator>'
                       # Since we're using the GUI, the method has to exist. The
                       # only possibility here is that it's an undef'ed method entry.
                       '<undef>'
                     end
                   end
        if location.nil?
          ''
        elsif location.is_a? String
          location
        else
          File.basename location[0]
        end
      end

      # Fills the methods listbox with a list of the object's methods.
      def display_methods(obj)
        @methodsbox.clear
        info = ObjInfo.new(obj)
        if obj and info.class_like?
          methods = info.m_tbl.keys.map do |v| v.to_s end.sort
          methods.each do |name|
            @methodsbox.insert('', 'end', :text => name, :values => [ name, pretty_location(info, name) ] )
          end
        end
      end

      # Loads the imagemap widget with a diagram of the object.
      def display_graph(obj)
        require 'drx/tempfiles'
        @objs = {}
        Tempfiles.new do |files|
          ObjInfo.new(obj).generate_diagram(files, @graph_opts) do |info|
            @objs[info.dot_url] = info
          end
          @im.image = files['gif']
          @im.image_map = files['map']
        end
      end

      # Saves the graph to a file.
      def save_graph(obj)
        require 'drx/tempfiles'
        Tempfiles.new do |files|
          ObjInfo.new(obj).generate_diagram(files, @graph_opts)
          if (output = Tk.getSaveFile(:parent => toplevel, :defaultextension => '.gif')) != ''
            FileUtils.cp(files['gif'], output)
          end
        end
      end

      # Makes `obj` the primary object seen (the one which is the tip of the diagram).
      def navigate_to(obj)
        @current_object = obj
        @navigation_history << obj
        display_graph(obj)
        # Trigger the update of the variables and methods tables by selecting this object
        # in the imagemap.
        @im.active_url = @im.urls.first
      end
      alias see navigate_to

      # Returns the tip object in the diagram (the one passed to navigate_to())
      def tip
        @navigation_history.last
      end

      # Refreshes the display.
      def refresh
        navigate_to tip
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
            grid(:row => 0, :column => 1, :rowspan => 1, :columnspan => 1, :sticky => 'news')
            command { |*args| the_widget.yview *args }
            the_widget.yscrollcommand { |first,last| s.set first,last }
          }
        end
        if opts[:horizontal]
          TkScrollbar.new(self) { |s|
            orient 'horizontal'
            grid(:row => 1, :column => 0, :rowspan => 1, :columnspan => 1, :sticky => 'news')
            command { |*args| the_widget.xview *args }
            the_widget.xscrollcommand { |first,last| s.set first,last }
          }
        end
        the_widget.raise  # Since the frame is created after the widget, it obscures it by default.
        the_widget.grid(:in => self, :row => 0, :column => 0, :rowspan => 1, :columnspan => 1, :sticky => 'news')
        TkGrid.rowconfigure(self, 0, :weight => 1, :minsize => 0)
        TkGrid.columnconfigure(self, 0, :weight => 1, :minsize => 0)
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
          layout = default_layout.merge(layout || {})
          w.raise
          w.pack(layout)
        }
      end
      def default_layout
        { :in => self, :side => 'top', :fill => 'x' }
      end
      def raise
        pack_slaves.each {|w| w.raise }
      end
    end

    # Arranges widgets one beside the other.
    class HBox < VBox
      def default_layout
        { :in => self, :side => 'left', :fill => 'none' }
      end
    end

    class ::Tk::Tile::Treeview
      def get_selection
        selection[0].text
      end
      def has_selection?
        not selection.empty?
      end
      def clear
        children('').each { |i| delete i }
      end
    end

  end # module TkGUI
end # module Drx
