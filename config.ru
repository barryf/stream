require 'rubygems'
require 'bundler'

Bundler.require

ENV['DATABASE_URL'] ||= 'hub'

require 'hub'
run Sinatra::Application