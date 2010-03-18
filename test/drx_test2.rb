require 'rubygems'
require 'dm-core'

#
# This is part of a blogging website. Users write posts. A post
# belongs to a user.
#

class Post
  include DataMapper::Resource

  property :post_id,  Serial
  property :title,    String
  property :body,     Text

  belongs_to :user
end

class User
  include DataMapper::Resource

  property :user_uid,  Serial
  property :name,      String
  property :mail,      String
end

post = Post.new

require 'drx'
post.see
