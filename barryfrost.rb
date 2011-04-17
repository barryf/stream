require 'rubygems'
require 'sinatra'
require 'active_record'

require 'fetchers'

configure do
  # activerecord setup
  dbconfig = YAML.load(File.read('config/database.yml'))
  ActiveRecord::Base.establish_connection dbconfig['production']

  # account api keys
  ACCOUNTS = YAML.load(File.read('config/accounts.yml'))
  # if private api keys weren't included in accounts.yml, try to get from env vars
  ACCOUNTS['lastfm']['api_key'] ||= ENV['LASTFM_API_KEY']
  ACCOUNTS['flickr']['api_key'] ||= ENV['FLICKR_API_KEY']

  # set up memcached
  require 'memcached'
  CACHE = Memcached.new

  # authentication password
  ADMIN_PASSWORD = ENV['ADMIN_PASSWORD'] || 'admin'
end

# we're using activerecord to talk to the database
class Item < ActiveRecord::Base; end

helpers do  
  # html escaping
  include Rack::Utils
  alias_method :h, :escape_html

  # authentication for fetchers/builders
  def protected!
    unless authorized?
      response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
      throw(:halt, [401, "Not authorized\n"])
    end
  end
  def authorized?
    @auth ||= Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == ['admin', ADMIN_PASSWORD]
  end
  
  # http caching if not development
  def cache_for(mins = 1)
    response['Cache-Control'] = "public, max-age=#{60*mins}" unless settings.environment == :development
  end
  
  # find h1 title within article
  def parse_article_title(article)
    re = Regexp.new('<h1>(.*)</h1>')
    article.scan(re)[0][0]
  end    
end

before do
  # always use utf-8 (unless overridden)
  headers "Content-Type" => "text/html; charset=utf-8"

  # flush cache if we're in development mode
  CACHE.flush if settings.environment == :development
end

get '/build/?' do
  protected!
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
  protected!
  @imports = {}
  # make sure a blank count is maxed at 10
  count = params[:count].to_i
  count = count < 10 ? count : 10
  # is the param a valid source?
  if ["flickr", "youtube", "twitter", "delicious", "lastfm", "blog"].include?(params[:source])
    @imports[params[:source]] = send('fetch_' + params[:source], params[:count])
    # do we need to flush the cache?
    CACHE.flush if @imports[params[:source]] > 0
    erb :build, :layout => false
  else
    redirect '/'
  end
end  

get '/destroy/:source/:uid/?' do
  protected!
  @success = destroy_item(params[:source], params[:uid])
  CACHE.flush if @success
  erb :destroy, :layout => false
end

get '/flush/?' do
  protected!
  CACHE.flush
  erb "Flushed cache at #{Time.now}", :layout => false
end

get '/' do
  cache_for 10
  page = params[:page].to_i
  page = page > 0 ? page : 1
  begin
    content = CACHE.get("page_#{page}")
  rescue Memcached::NotFound
    @items = Item.offset((page-1)*50).limit(50).order('created_at DESC')
    @title = "Barry Frost"
    @page = page
    @body_class = 'home'
    @latest_article = Item.where(:source => 'blog').order('created_at DESC').first
    content = @items.length > 0 ? erb(:index, :layout => !request.xhr?) : ''
    CACHE.set("page_#{page}", content)
  end
  content
end

get '/articles/:title' do
  cache_for 60
  # fetch from memcached
  begin
    content = CACHE.get("article_#{params[:title]}")
  rescue Memcached::NotFound
    begin
      article = File.read("blog/_site/#{params[:title]}.html")
      @body_class = 'article'
      @title = parse_article_title(article)
      content = erb(article)
      CACHE.set("article_#{params[:title]}", content)
    rescue Errno::ENOENT
      not_found
    end
  end
  content
end

get %r{/rss/?|feed/?|atom\.xml} do
  cache_for 10
  headers "Content-Type" => "application/atom+xml; charset=utf-8"
  File.read("blog/_site/atom.xml")
end

get %r{/(articles|tweets|links|photos|videos|music)/?} do |type|
  cache_for 10
  case type
  when 'articles'
    source = 'blog'
  when 'tweets'
    source = 'twitter'
  when 'links'
    source = 'delicious'
  when 'photos'
    source = 'flickr'
  when 'videos'
    source = 'youtube'
  when 'music'
    source = 'lastfm'
  end
  page = params[:page].to_i
  page = page > 0 ? page : 1
  begin
    content = CACHE.get("#{source}_page_#{page}")
  rescue Memcached::NotFound
    @items = Item.where(:source => source).offset((page-1)*50).limit(50).order('created_at DESC')
    @title = "Barry Frost: #{type}"
    @source = source
    @body_class = 'archive'
    @page = page
    content = @items.length > 0 ? erb(:index, :layout => !request.xhr?) : ''
    CACHE.set("#{source}_page_#{page}", content)
  end
  content
end

get '/:year/:month/:day/?' do
  cache_for 10
  date = Time.utc(params[:year], params[:month], params[:day])
  @body_class = 'archive'
  @items = Item.where(:created_at => date..(date+86400)).order('created_at DESC')
  erb :index
end

get '/about/?' do 
  cache_for 60
  @body_class = 'static'
  erb :about
end

get '/favicon.ico' do
  # cache for 1 week
  cache_for 7*24*60
  status 404
end

not_found do
  @body_class = 'static'
  erb :'404'
end