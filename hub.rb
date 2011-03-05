require 'rubygems'
require 'sinatra'
require 'active_record'

require 'fetchers'

configure do
  ACCOUNTS = YAML.load(File.read('config/accounts.yml'))
  # if private api keys weren't included in accounts.yml, try to get from env vars
  ACCOUNTS['lastfm']['api_key'] ||= ENV['LASTFM_API_KEY']
  ACCOUNTS['flickr']['api_key'] ||= ENV['FLICKR_API_KEY']
  # activerecord setup
  dbconfig = YAML.load(File.read('config/database.yml'))
  ActiveRecord::Base.establish_connection dbconfig['production']
  # setup memcached
  require 'memcached'
  CACHE = Memcached.new
end

class Item < ActiveRecord::Base; end

helpers do
  # html escaping
  include Rack::Utils
  alias_method :h, :escape_html
  # date parsing
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
  flush = false
  ["flickr", "youtube", "twitter", "delicious", "lastfm"].each do |s|
    @imports[s] = send('fetch_' + s)
    flush = true if @imports[s] > 0
  end
  # do we need to flush the cache?
  CACHE.flush if flush
  erb :build, :layout => false
end

get '/build/:source/:count?' do
  @imports = {}
  # make sure a blank count is maxed at 10
  count = params[:count].to_i
  count = count < 10 ? count : 10
  # is the param a valid source?
  if ["flickr", "youtube", "twitter", "delicious", "lastfm"].include?(params[:source])
    @imports[params[:source]] = send('fetch_' + params[:source], params[:count])
    # do we need to flush the cache?
    CACHE.flush if @imports[params[:source]] > 0
    erb :build, :layout => false
  else
    redirect '/'
  end
end  

get '/' do
  page = params[:page].to_i
  page = page > 0 ? page : 1
  begin
    @items = CACHE.get("page_#{page}")
  rescue Memcached::NotFound
    @items = Item.offset((page-1)*50).limit(50).order('created_at DESC')
    CACHE.set("page_#{page}",@items)
  end
  @title = "Barry Frost&rsquo;s Aggregator"
  @page = page
  erb :index, :layout => !request.xhr?
end

get '/:year/:month/:day/?' do
  date = Time.local(params[:year], params[:month], params[:day])
  @items = Item.where(:created_at => date..(date+86400)).order('created_at DESC')
  erb :index
end

get '/post' do
  @body_class = 'content'
  erb :post
end