require 'rubygems'
require 'activerecord'

#
# This is part of a blogging website. Users write posts. A post
# belongs to a user.
#

ActiveRecord::Base.logger = Logger.new(STDERR)
ActiveRecord::Base.colorize_logging = false

ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :database  => ':memory:'
)

ActiveRecord::Schema.define do
  create_table :users do |table|
    table.column :name, :string
    table.column :mail, :string
  end
  create_table :posts do |table|
    table.column :user_id, :integer
    table.column :title, :string
    table.column :body, :string
  end
end

class User < ActiveRecord::Base
  has_many :posts
end

class Post < ActiveRecord::Base
  belongs_to :users
end

david = User.create(:name => 'David')
david.posts.create(:title => 'Lies')
david.posts.create(:title => 'Truths')

post = User.find(1).posts.first

require 'drx'
post.see
