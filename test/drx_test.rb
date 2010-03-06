require 'rubygems'
require 'drx'

require 'date'

##############################

class Zeman < DateTime
  def int
  end
end

zmn = Zeman.new

def zmn.koko
 9090
end

Drx.examine(zmn)

#############################

Drx.see(zmn)
