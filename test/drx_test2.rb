require 'rubygems'
require 'dm-core'

class Post
  include DataMapper::Resource
 
  property :post_id,  Integer, :serial => true
  property :title,    String
  property :body,     Text
  
  belongs_to :user
end

class User
  include DataMapper::Resource
 
  property :user_uid,  Integer, :serial => true
  property :name,      String
  property :mail,      String
end

post = Post.new

require 'drx'
Drx.see(post)
