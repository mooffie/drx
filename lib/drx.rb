# Bootstraps the library and defines some utility functions for the end-user.

require 'drx_core' # The C extension.
require 'drx/objinfo'
require 'drx/graphviz'

module Drx

  def self.see_using_tk(obj)
    require 'drx/tk/app'
    app = Drx::TkGUI::Application.new
    app.see(obj)
    app.run
  end

  class << self
    # DrX::see() launches the GUI for inspecting an object. It is perhaps the only
    # function the end-user is going to know about. It can also be invoked via
    # Object#see().
    #
    #   my_obj = "foobar"
    #   my_object.see
    alias :see :see_using_tk
  end

end

class Object
  def see
    Drx.see(self)
  end
end
