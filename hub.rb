require 'rubygems'
require 'sinatra'
require 'active_record'
require 'parsedate'
require 'digest/md5'

require 'fetchers'

configure do
  ACCOUNTS = YAML.load(File.read('config/accounts.yml'))
  # if private api keys weren't included in accounts.yml, try to get from env vars
  ACCOUNTS['lastfm']['api_key'] ||= ENV['LASTFM_API_KEY']
  ACCOUNTS['flickr']['api_key'] ||= ENV['FLICKR_API_KEY']
  # activerecord setup
  dbconfig = YAML.load(File.read('config/database.yml'))
  ActiveRecord::Base.establish_connection dbconfig['production']
end

class Item < ActiveRecord::Base; end

helpers do
  include Rack::Utils
  alias_method :h, :escape_html
  def parse_tweet(tweet)
    # urls
    re = Regexp.new('(^|[\n ])([\w]+?://[\w]+[^ \"\n\r\t<]*)')
    tweet.gsub!(re, '\1<a href="\2">\2</a>')
    # usernames
    re = Regexp.new('(\@)([\w]+)')
    tweet.gsub!(re, '<a href="http://twitter.com/\2">@\2</a>')
    # hashtags
    re = Regexp.new('(\#)([\w]+)')
    tweet.gsub!(re, '<a href="http://twitter.com/search/%23\2">#\2</a>')
    tweet
  end
  def relative_date(time)
    today_date = Time.local(Time.now.year, Time.now.month, Time.now.day)
    date = Time.local(time.year, time.month, time.day)
    day_diff = ((today_date-date)/86400).ceil
    if day_diff == 0 then return 'Today' end
    if day_diff == 1 then return 'Yesterday' end
    if day_diff == 7 then return '1 week ago' end
    if day_diff >= 2 && day_diff < 7 then return "#{day_diff} days ago" end
    if time.year != Time.now.year then return time.strftime('%d %b %Y') end
    time.strftime('%d %B')
  end
end

before do
  headers "Content-Type" => "text/html; charset=utf-8"
end

get '/build/?' do
  @imports = {}
  ["flickr", "youtube", "twitter", "delicious", "lastfm"].each do |s|
    @imports[s] = send('fetch_' + s)
  end
  erb :build, :layout => false
end

get '/build/:source/:count?' do
  @imports = {}
  # make sure a blank count is maxed at 10
  params[:count] ||= 10
  # is the param a valid source?
  if ["flickr", "youtube", "twitter", "delicious", "lastfm"].include?(params[:source])
    @imports[params[:source]] = send('fetch_' + params[:source], params[:count])
    erb :build, :layout => false
  else
    redirect '/'
  end
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

get '/:year/:month/:day/?' do
  date = Time.local(params[:year], params[:month], params[:day])
  @items = Item.find(:all,
                     :conditions => ['created_at >= ? and created_at < ?', date, date+86400],
                     :limit => 30,
                     :order => 'created_at DESC')
  erb :index
end