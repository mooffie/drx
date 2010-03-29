require 'rubygems'

spec = Gem::Specification.new do |s|
  s.name          = 'drx'
  s.version       = '0.3.1'
  s.author        = 'Mooffie'
  s.email         = 'mooffie@gmail.com'
  s.platform      = Gem::Platform::RUBY
  s.rubyforge_project = 'drx'
  s.homepage      = 'http://drx.rubyforge.org/'
  s.summary       = "Inspect Ruby objects."
  s.required_ruby_version = '~> 1.8.0'

  candidates = ['README'] + Dir.glob("{bin,docs,lib,ext,tests,examples}/**/*")
  s.files = candidates.delete_if { |f| f =~ /(~|Makefile|\.o|\.so)$/ }
  #p s.files

  s.require_path  = 'lib' 
  s.extensions = ["ext/extconf.rb"]
end

if $0 == __FILE__
  Gem::Builder.new(spec).build
end
