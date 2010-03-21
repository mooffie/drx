#!/usr/bin/ruby

require 'rubygems'
require 'drx'

class Instrument
  include Enumerable
end

class Guitar < Instrument
  def initialize
    @strings = 5
  end

  def self.add_some
    @max_strings = 10
    @@approved = 'by team obama'
  end
end

Guitar.add_some
o = Guitar.new
def o.unq
  def g;end
end

o.see
