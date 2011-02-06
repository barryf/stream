require 'rubygems'
require 'sinatra'
require 'json'
require 'net/http'
require 'active_record'

class Item < ActiveRecord::Base; end

# import tweets

def fetch_twitter(count=10, screen_name=ACCOUNTS['twitter']['screen_name'])
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

def fetch_delicious(count=10, user=ACCOUNTS['delicious']['user'])
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

def fetch_lastfm(count=10, user=ACCOUNTS['lastfm']['user'], api_key=ACCOUNTS['lastfm']['api_key'])
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

def fetch_youtube(count=10, user=ACCOUNTS['youtube']['user'])
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

def fetch_flickr(count=10, user_id=ACCOUNTS['flickr']['user_id'], api_key=ACCOUNTS['flickr']['api_key'])
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
                  :url => "http://www.flickr.com/photos/#{ACCOUNTS['flickr']['user']}/#{remote['id']}",
                  :thumbnail_url => remote['url_sq'],
                  :source => source,
                  :imported_at => Time.now,
                  :created_at => remote['datetaken'])
      imported += 1
    end
  end
  imported
end
