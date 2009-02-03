require 'drx'
require 'tk'

module Drx
  def self.examinetk(obj)
    app = Drx::TkGUI::DrxWindow.new
    app.display_value(obj)
    app.run
  end

  # easier to type...
  def self.see(obj)
    examinetk(obj)
  end
end

module Drx
  module TkGUI

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
        root = TkRoot.new
        @list = (ScrolledListbox.new(root) {
          #pack :side => 'left', :fill => 'y'
          pack :side => 'left', :fill => 'both', :expand => true
        }).the_list
        @list.width 52
        @list.height 25
        @list.focus
        @varsbox = (ScrolledListbox.new(root) {
          #pack :side => 'left', :fill => 'y'
          pack :side => 'left', :fill => 'both', :expand => true
        }).the_list
        @methodsbox = (ScrolledListbox.new(root) {
          #pack :side => 'left', :fill => 'y'
          pack :side => 'left', :fill => 'both', :expand => true
        }).the_list

        @list.bind('<ListboxSelect>') {
          @current_object = @objs[@list.get_index]
          display_variables(current_object)
          display_methods(current_object)
        }
        @varsbox.bind('<ListboxSelect>') {
          inspect_variable(current_object, @varsbox.get_selection)
        }
      end

    #  def current_object=(obj)
    #    @current_object = obj
    #  end
      
      def current_object
        @current_object
      end

      def display_variables(obj)
        @varsbox.delete('0', 'end')
        if (Drx.has_iv_tbl(obj)) 
          vars = Drx.get_iv_tbl(obj).keys.map do |v| v.to_s end.sort
          @varsbox.insert('end', *vars)
        end
      end
      
      def inspect_variable(obj, var_name)
        print "\n== Variable #{var_name}\n\n"
        p Drx.get_ivar(obj, var_name)
      end
      
      def display_methods(obj)
        @methodsbox.delete('0', 'end')
        if (Drx.is_class_like(obj)) 
          methods = Drx.get_m_tbl(obj).keys.map do |v| v.to_s end.sort
          @methodsbox.insert('end', *methods)
        end
      end
      
      def display_value(value)
        @objs = []
        Drx.examine(value) do |line, obj|
          @list.insert('end', line)
          @objs << obj
        end
      end
      
      def run
        Tk.mainloop
      end
    end

  end # module TkGUI
end # module Drx
