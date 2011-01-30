require 'rubygems'
require 'sinatra'
require 'json'
require 'net/http'
require 'active_record'
require 'parsedate'
require 'digest/md5'
  
configure do
  dbconfig = YAML.load(File.read('config/database.yml'))
  ActiveRecord::Base.establish_connection dbconfig['production']
end

class Item < ActiveRecord::Base
end

def get_tweets(screen_name='barryf',count=50)
  url = "http://api.twitter.com/1/statuses/user_timeline.json?screen_name=#{screen_name}&count=#{count}"
  resp = Net::HTTP.get_response(URI.parse(url))
  JSON.parse(resp.body)
end

def get_links(user='barryf')
  url = "http://feeds.delicious.com/v2/json/#{user}"
  resp = Net::HTTP.get_response(URI.parse(url))
  JSON.parse(resp.body)
end

def get_loved_tracks(user='barryf',api_key='1288fde3d6ed69a00b6671cf032e7668',limit=10)
  url = "http://ws.audioscrobbler.com/2.0/?method=user.getlovedtracks&format=json&user=#{user}&api_key=#{api_key}&limit=#{limit}"
  resp = Net::HTTP.get_response(URI.parse(url))
  JSON.parse(resp.body)
end

def parse_tweet(tweet)
  # urls
  re = Regexp.new('(^|[\n ])([\w]+?://[\w]+[^ \"\n\r\t<]*)')
  tweet.gsub!(re, '\1<a href="\2">\2</a>')
  # usernames
  re = Regexp.new('(\@)([\w]+)')
  tweet.gsub!(re, '<a href="http://twitter.com/\2">@\2</a>')
  # hashtags
  re = Regexp.new('(\#)([\w]+)')
  tweet.gsub!(re, '<a href="http://twitter.com/search/\2">#\2</a>')
  tweet
end

before do
  headers "Content-Type" => "text/html; charset=utf-8"
end

get '/build/?' do
  # import tweets
  tweets = get_tweets
  tweets.each do |remote|
    if !Item.find_by_uid(remote['id'].to_s) && remote['text'][0..0] != '@'
      Item.create(:uid => remote['id'],
                  :title => remote['text'],
                  :body => remote['text'],
                  :source => 'twitter',
                  :imported_at => Time.now,
                  :created_at => remote['created_at'])
    end
  end
  # import links from delicious
  links = get_links
  links.each do |remote|
    if !Item.find_by_uid(remote['u'].hash.to_s)
      Item.create(:uid => remote['u'].hash.to_s,
                  :title => remote['d'],
                  :body => remote['n'],
                  :url => remote['u'],
                  :tags => remote['t'].join(' '),
                  :source => 'delicious',
                  :imported_at => Time.now,
                  :created_at => remote['dt'])
    end
  end
  # import last.fm loved tracks
  loved_tracks = get_loved_tracks
  loved_tracks['lovedtracks']['track'].each do |remote|
    if !Item.find_by_uid(remote['url'].hash.to_s)
      thumbnail_url = remote.has_key?('image') ? remote['image'][1]['#text'] : ''
      Item.create(:uid => remote['url'].hash.to_s,
                  :title => '&lsquo;' + remote['name'] + '&rsquo; by ' + remote['artist']['name'],
                  :url => remote['url'],
                  :thumbnail_url => thumbnail_url,
                  :source => 'lastfm',
                  :imported_at => Time.now,
                  :created_at => Time.at(remote['date']['uts'].to_i))
    end
  end
  "Built"
end

get '/' do
  ts = params[:ts] ||= 99999999999
  @items = Item.find(:all, 
                     :conditions => ['created_at < ?', Time.at(ts.to_i)],
                     :limit => 30,
                     :order => 'created_at DESC')
  @title = "Barry Frost&rsquo;s Aggregator"
  erb :index, :layout => !request.xhr?
end

