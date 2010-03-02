require 'rubygems'
require 'drxtk'

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

Drx.examinetk(zmn)
#Drx.examinetk("some_string")
