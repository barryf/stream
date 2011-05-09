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

  # site config (dev/prd split)
  SITE = YAML.load(File.read('config/site.yml'))

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
  
  # find the source from item type
  def type_to_source(type)
    case type
    when 'articles'
      'blog'
    when 'tweets'
      'twitter'
    when 'links'
      'delicious'
    when 'photos'
      'flickr'
    when 'videos'
      'youtube'
    when 'music'
      'lastfm'
    end
  end
  
  # urls
  def shorturl
    SITE[settings.environment.to_s]['shorturl']
  end
  def canonicalurl
    SITE[settings.environment.to_s]['canonicalurl']
  end
end

before do
  # always use utf-8 (unless overridden)
  headers "Content-Type" => "text/html; charset=utf-8"

  # flush cache if we're in development mode
  CACHE.flush if settings.environment == :development
  
  # if we're coming via the shorturl host, redirect to / unless it's a four-char path (ignoring slash)
  if request.env['HTTP_HOST'] == 'bfr.st' && request.path.length != 5
    redirect canonicalurl
  end
  # check we're not coming via a www. and redirect to canonical url (omitting first slash)
  if request.env['HTTP_HOST'][0..3] == 'www.'
    redirect canonicalurl + request.path[1..request.path.length]
  end
end

get '/build/?' do
  protected!
  @imports = fetch_all
  CACHE.flush
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

get '/destroy/:shortcode/?' do
  protected!
  @success = destroy_item(params[:shortcode])
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

get '/articles/:title/?' do
  cache_for 60
  # fetch from memcached
  begin
    content = CACHE.get("article_#{params[:title]}")
  rescue Memcached::NotFound
    begin
      items = Item.where({:source => 'blog', :uid => params[:title]})
      not_found if items.length.zero?
      @item = items[0]
      @body_class = 'article'
      @title = @item.title
      @shortcode = @item.shortcode
      @article = File.read("blog/_site/#{params[:title]}.html")
      content = erb(:article)
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

get %r{^/(articles|tweets|links|photos|videos|music)/?$} do |type|
  cache_for 10
  source = type_to_source(type)
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

get '/:year/:month/:day/?:type?/?' do
  cache_for 10
  source = type_to_source(params[:type])
  date = Time.local(params[:year], params[:month], params[:day])
  @body_class = 'archive'
  @title = "Barry Frost: archive"
  where = { :created_at => date..(date+86400) }
  where['source'] = source unless source == nil
  @items = Item.where(where).order('created_at DESC')
  erb :index
end

get '/about/?' do 
  cache_for 60
  @body_class = 'static'
  @title = 'About Barry Frost'
  erb :about
end

get '/sitemap.xml' do
  cache_for 60
  headers "Content-Type" => "text/xml; charset=utf-8"
  # TODO: include archive pages - don't rely on Jekyll
  File.read("blog/_site/sitemap.xml")
end

# short url redirector, e.g. /77xH => http://twitter.com/barryf/status/66118106933772290
get %r{^/([A-Za-z0-9]{4})/?$} do |sc|
  cache_for 60
  begin
    url = CACHE.get("shortcode_#{sc}")
  rescue Memcached::NotFound
    item = Item.where(:shortcode => sc)
    not_found if item.length.zero?
    url = item[0].url
    CACHE.set("shortcode_#{sc}", url)
  end
  # 302 redirect
  redirect url
end
  
not_found do
  @body_class = 'static'
  @title = '404 - not found'
  erb :'404'
end