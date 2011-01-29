require 'rubygems'
require 'sinatra'
require 'json'
require 'net/http'
require 'active_record'

configure do
  ActiveRecord::Base.establish_connection(:adapter => 'postgresql',
                                          :database => ENV['DATABASE_URL'])
end

class Item < ActiveRecord::Base
end

def get_tweets(screen_name='barryf',count=10)
  url = "http://api.twitter.com/1/statuses/user_timeline.json?screen_name=#{screen_name}&count=#{count}"
  resp = Net::HTTP.get_response(URI.parse(url))
  JSON.parse(resp.body)
end

get '/build/?' do
  ['barryf','globaldev'].each do |account|
    tweets = get_tweets(account)
    tweets.each do |t|
      if !Item.find_by_uid(t['id'].to_s)
        Item.create(:uid => t['id'],
                    :title => t['text'],
                    :body => t['text'],
                    :created_at => t['created_at'])
      end
    end
  end
  "Built"
end

get '/' do
  @items = Item.find(:all, :order => 'created_at DESC')
  erb :index
end

