require 'rubygems'
require 'sinatra'
require 'json'
require 'net/http'
require 'active_record'

configure do
  ActiveRecord::Base.establish_connection(:adapter => 'postgresql',
                                          :host => 'localhost',
                                          :username => 'postgres',
                                          :database => 'hub')
end

class Item < ActiveRecord::Base
end

def get_tweets(screen_name='barryf',count=50)
  url = "http://api.twitter.com/1/statuses/user_timeline.json?screen_name=#{screen_name}&count=#{count}"
  resp = Net::HTTP.get_response(URI.parse(url))
  tweets = JSON.parse(resp.body)
  return tweets
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
  items = Item.order('created_at').find(:all)
  output = ""
  items.each do |i|
    output << "<p>#{i.created_at} - #{i.body}</p>"
  end
  return output
end