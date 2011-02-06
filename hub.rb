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

class Item < ActiveRecord::Base; end

# import tweets

def fetch_twitter(count=10, screen_name='barryf')
  url = "http://api.twitter.com/1/statuses/user_timeline.json?screen_name=#{screen_name}&count=#{count}"
  resp = Net::HTTP.get_response(URI.parse(url))
  twitter = JSON.parse(resp.body)
  source = 'twitter'
  imported = 0
  twitter.each do |remote|
    # don't import replies/mentions
    if !Item.find_by_uid(source + remote['id'].to_s) && remote['text'][0..0] != '@'
      Item.create(:uid => source + remote['id'].to_s,
                  :title => remote['text'],
                  :body => remote['text'],
                  :source => source,
                  :imported_at => Time.now,
                  :created_at => remote['created_at'])
      imported += 1
    end
  end
  imported
end

# import links from delicious

def fetch_delicious(count=10,user='barryf')
  url = "http://feeds.delicious.com/v2/json/#{user}?count=#{count}"
  resp = Net::HTTP.get_response(URI.parse(url))
  delicious = JSON.parse(resp.body)
  source = 'delicious'
  imported = 0
  delicious.each do |remote|
    if !Item.find_by_uid(source + remote['u'].hash.to_s)
      Item.create(:uid => source + remote['u'].hash.to_s,
                  :title => remote['d'],
                  :body => remote['n'],
                  :url => remote['u'],
                  :tags => remote['t'].join(' '),
                  :source => source,
                  :imported_at => Time.now,
                  :created_at => remote['dt'])
      imported += 1
    end
  end
  imported
end

# import last.fm loved tracks

def fetch_lastfm(count=10,user='barryf',api_key='1288fde3d6ed69a00b6671cf032e7668')
  url = "http://ws.audioscrobbler.com/2.0/?method=user.getlovedtracks&format=json&user=#{user}&api_key=#{api_key}&limit=#{count}"
  resp = Net::HTTP.get_response(URI.parse(url))
  lastfm = JSON.parse(resp.body)
  source = 'lastfm'
  imported = 0
  lastfm['lovedtracks']['track'].each do |remote|
    if !Item.find_by_uid(source + remote['url'].hash.to_s)
      thumbnail_url = remote.has_key?('image') ? remote['image'][1]['#text'] : ''
      Item.create(:uid => source + remote['url'].hash.to_s,
                  :title => '&lsquo;' + remote['name'] + '&rsquo; by ' + remote['artist']['name'],
                  :url => remote['url'],
                  :thumbnail_url => thumbnail_url,
                  :source => source,
                  :imported_at => Time.now,
                  :created_at => Time.at(remote['date']['uts'].to_i))
      imported += 1
    end
  end
  imported
end

# import youtube favorites tracks

def fetch_youtube(count=10,user='barryfrost')
  url = "http://gdata.youtube.com/feeds/api/users/#{user}/favorites?v=2&alt=json&max-results=#{count}"
  resp = Net::HTTP.get_response(URI.parse(url))
  youtube = JSON.parse(resp.body)
  # import to database  
  source = 'youtube'
  imported = 0
  youtube['feed']['entry'].each do |remote|
    if !Item.find_by_uid(source + remote['id']['$t'].hash.to_s)
      Item.create(:uid => source + remote['id']['$t'].hash.to_s,
                  :title => "&lsquo;#{remote['title']['$t']}&rsquo;",
                  :url => remote['link'][0]['href'],
                  :thumbnail_url => remote['media$group']['media$thumbnail'][1]['url'],
                  :source => source,
                  :imported_at => Time.now,
                  :created_at => remote['published']['$t'])
      imported += 1
    end
  end
  imported
end

# import flickr photos

def fetch_flickr(count=10,user_id='32626558@N00',api_key='00bd943e7e761623f70e50b09f537629')
  url = "http://api.flickr.com/services/rest/?method=flickr.people.getPublicPhotos&format=json&api_key=#{api_key}&user_id=#{user_id}&extras=date_taken,geo,url_sq,description&per_page=#{count}"
  resp = Net::HTTP.get_response(URI.parse(url))
  # remove callback function name and trailing bracket
  clean = resp.body.sub(/jsonFlickrApi\(/, '').sub(/\)$/,'')
  flickr = JSON.parse(clean)
  # import to database
  source = 'flickr'
  imported = 0
  flickr['photos']['photo'].each do |remote|
    if !Item.find_by_uid(source + remote['id'].to_s)
      Item.create(:uid => source + remote['id'].to_s,
                  :title => remote['title'],
                  :url => "http://www.flickr.com/photos/barryf/#{remote['id']}",
                  :thumbnail_url => remote['url_sq'],
                  :source => source,
                  :imported_at => Time.now,
                  :created_at => remote['datetaken'])
      imported += 1
    end
  end
  imported
end

helpers do
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
    today_date = Time.utc(Time.now.year, Time.now.month, Time.now.day)
    date = Time.utc(time.year, time.month, time.day)
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
  date = Time.utc(params[:year], params[:month], params[:day])
  @items = Item.find(:all,
                     :conditions => ['created_at > ? and created_at < ?', date, date+86400],
                     :limit => 30,
                     :order => 'created_at DESC')
  erb :index
end