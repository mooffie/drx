require 'rubygems'
require 'sequel'

#
# This is part of a blogging website. Users write posts. A post
# belongs to a user.
#

DB = Sequel.sqlite(':memory:')

DB.create_table :posts do
  primary_key :id
  Integer :user_id
  String :title
  String :body
end

DB.create_table :users do
  primary_key :id
  String :name
  String :email
end

class Post < Sequel::Model
  many_to_one :user
end

class User < Sequel::Model
  one_to_many :posts
end

post = Post.create(:title => 'Lies', :user => User.create(:name => 'David'))

require 'drx'
post.see
