#!/usr/bin/ruby

require 'rubygems'

require 'drx'

class Instrument
  include Enumerable
end

class Guitar < Instrument
  def initialize
    @strings = 5
#    puts class # .add_some
  end

  def self.add_some
    @max_strings = 10
    @@approved = 'by obama team'
  end
end

require 'dm-core'
class Post
  include DataMapper::Resource
  property :id, Serial
end

o = Guitar.new
o = Post.new
def o.unq
  def g;end
end

o.see
