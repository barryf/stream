require 'rubygems'
require 'json'
require 'net/http'
require 'cgi'
require 'active_record'
require 'base58'
require 'digest/md5'

class Item < ActiveRecord::Base; end

# fetch all, return counts of each type imported (if any)
def fetch_all
  imports = {}
  ["flickr", "youtube", "twitter", "delicious", "lastfm"].each do |s|
    imports[s] = send('fetch_' + s)
  end
  imports
end

# parse tweets

# url shortening - max 40 characters, remove http:// and www.
def shorten_url(url)
  short = url[0,39]
  if short.length < url.length
    short << '&hellip;'
  end
  short = short.sub(/^http\:\/\//,'').sub(/^www\./,'')
  short
end

# follow redirects and return final url
def fetch(uri_str, limit = 10)
  raise ArgumentError, 'HTTP redirect too deep' if limit == 0
  begin
    uri = URI.parse(uri_str)
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Get.new(uri.request_uri)
    # spoof the user agent string, specifically for facebook which gets huffy
    request.initialize_http_header({"User-Agent" => "Mozilla/5.0 (Windows; U; MSIE 9.0; Windows NT 9.0; en-US))"})
    response = http.request(request)
    case response
    when Net::HTTPSuccess     then uri_str
    when Net::HTTPRedirection then fetch(response['location'], limit - 1)
    else
      # response.error!
      uri_str
    end
  rescue
    uri_str
  end
end

# interrogate tweet. find any embedded media and return oembed json via oohembed
def parse_tweet(tweet)
  oembeds = []
  # link urls:
  re = Regexp.new('(^|[\n ])([\w]+?://[\w]+[^ \"\n\r\t<]*)')
  # find urls through redirects
  urls = []
  tweet.scan(re) do |s|
    # find final url
    url = fetch(s[1])
    # replace url with found url
    urls << [s[1], url]
  end
  # do url link replacements
  urls.each do |url|
    # test each url for oembed data
    oohembed_url = "http://oohembed.com/oohembed/?url=#{url[1]}"
    resp = Net::HTTP.get_response(URI.parse(oohembed_url))
    if resp.code == '200' && resp.body.length > 0
      oembeds << resp.body
    end
    # replace urls with links
    tweet.gsub!(url[0], "<a href=\"#{url[0]}\" title=\"#{CGI.escapeHTML(url[1])}\">#{shorten_url(url[1])}</a>")
  end
  # link usernames
  re = Regexp.new('(\@)([\w]+)')
  tweet.gsub!(re, '<a href="http://twitter.com/\2">@\2</a>')
  # link hashtags (needs to start the string or have a space before so we don't link #s in urls)
  re = Regexp.new('(\s|^)(\#)([\w]+)')
  tweet.gsub!(re, '\1<a href="http://twitter.com/search/%23\3">#\3</a>')
  # return tweet and any oembed data
  [tweet, oembeds]
end

# import tweets

def fetch_twitter(count=5, screen_name=ACCOUNTS['twitter']['screen_name'])
  imported = 0
  url = "http://api.twitter.com/1/statuses/user_timeline.json?screen_name=#{screen_name}&include_rts=1&trim_user=1&count=#{count}"
  resp = Net::HTTP.get_response(URI.parse(url))
  if resp.code == '200'
    twitter = JSON.parse(resp.body)
    source = 'twitter'
    twitter.each do |remote|
      # don't import replies/mentions
      if Item.where('uid = ? and source = ?', remote['id'].to_s, source).count.zero? && remote['text'][0..0] != '@'
        # parse tweet and get any oembed data
        tweet, oembed = parse_tweet(remote['text'])
        # get co-ordinates and place name if available
        geo_name = remote['place'] ? remote['place']['full_name'] : ""
        geo_lat = remote['coordinates'] ? remote['coordinates']['coordinates'][1] : nil
        geo_lng = remote['coordinates'] ? remote['coordinates']['coordinates'][0] : nil
        # strip newlines from oembed json
        oembed = oembed.to_s.gsub(/\n/,'')
        Item.create(:uid => remote['id'].to_s,
                    :body => tweet,
                    :url => "http://twitter.com/#{screen_name}/status/#{remote['id'].to_s}",
                    :oembed => oembed,
                    :geo_name => geo_name,
                    :geo_lat => geo_lat,
                    :geo_lng => geo_lng,
                    :shortcode => unique_shortcode,
                    :source => source,
                    :imported_at => Time.now,
                    :created_at => remote['created_at'])
        imported += 1
      end
    end
  end
  imported
end

# import links from delicious

def fetch_delicious(count=5, user=ACCOUNTS['delicious']['user'])
  imported = 0
  url = "http://feeds.delicious.com/v2/json/#{user}?count=#{count}"
  resp = Net::HTTP.get_response(URI.parse(url))
  if resp.code == '200'
    delicious = JSON.parse(resp.body)
    source = 'delicious'
    delicious.each do |remote|
      uid = Digest::MD5.hexdigest(remote['u'])
      if Item.where('uid = ? and source = ?', uid, source).count.zero?
        Item.create(:uid => uid,
                    :title => remote['d'],
                    :body => remote['n'],
                    :url => remote['u'],
                    :tags => remote['t'].join(' '),
                    :shortcode => unique_shortcode,
                    :source => source,
                    :imported_at => Time.now,
                    :created_at => remote['dt'])
        imported += 1
      end
    end
  end
  imported
end

# import last.fm loved tracks

def fetch_lastfm(count=5, user=ACCOUNTS['lastfm']['user'], api_key=ACCOUNTS['lastfm']['api_key'])
  imported = 0
  url = "http://ws.audioscrobbler.com/2.0/?method=user.getlovedtracks&format=json&user=#{user}&api_key=#{api_key}&limit=#{count}"
  resp = Net::HTTP.get_response(URI.parse(url))
  if resp.code == '200'
    lastfm = JSON.parse(resp.body)
    source = 'lastfm'
    lastfm['lovedtracks']['track'].each do |remote|
      uid = Digest::MD5.hexdigest(remote['url'])
      if Item.where('uid = ? and source = ?', uid, source).count.zero?
        thumbnail_url = remote.has_key?('image') ? remote['image'][1]['#text'] : ''
        Item.create(:uid => uid,
                    :title => '&lsquo;' + remote['name'] + '&rsquo; by ' + remote['artist']['name'],
                    :url => remote['url'],
                    :thumbnail_url => thumbnail_url,
                    :source => source,
                    :shortcode => unique_shortcode,
                    :imported_at => Time.now,
                    :created_at => Time.at(remote['date']['uts'].to_i))
        imported += 1
      end
    end
  end
  imported
end

# import youtube favorites tracks

def fetch_youtube(count=5, user=ACCOUNTS['youtube']['user'])
  imported = 0
  url = "http://gdata.youtube.com/feeds/api/users/#{user}/favorites?v=2&alt=json&max-results=#{count}"
  resp = Net::HTTP.get_response(URI.parse(url))
  if resp.code == '200'
    youtube = JSON.parse(resp.body)
    source = 'youtube'
    youtube['feed']['entry'].each do |remote|
      uid = Digest::MD5.hexdigest(remote['id']['$t'])
      if Item.where('uid = ? and source = ?', uid, source).count.zero?
        Item.create(:uid => uid,
                    :title => "&lsquo;#{remote['title']['$t']}&rsquo;",
                    :url => remote['link'][0]['href'],
                    :thumbnail_url => remote['media$group']['media$thumbnail'][1]['url'],
                    :source => source,
                    :shortcode => unique_shortcode,
                    :imported_at => Time.now,
                    :created_at => remote['published']['$t'])
        imported += 1
      end
    end
  end
  imported
end

# import flickr photos

def fetch_flickr(count=5, user_id=ACCOUNTS['flickr']['user_id'], api_key=ACCOUNTS['flickr']['api_key'])
  imported = 0
  url = "http://api.flickr.com/services/rest/?method=flickr.people.getPublicPhotos&format=json&api_key=#{api_key}&user_id=#{user_id}&extras=date_taken,geo,url_sq,description&per_page=#{count}"
  resp = Net::HTTP.get_response(URI.parse(url))
  if resp.code == '200'
    # remove callback function name and trailing bracket
    clean = resp.body.sub(/jsonFlickrApi\(/, '').sub(/\)$/,'')
    flickr = JSON.parse(clean)
    source = 'flickr'
    flickr['photos']['photo'].each do |remote|
      if Item.where('uid = ? and source = ?', remote['id'].to_s, source).count.zero?
        Item.create(:uid => remote['id'].to_s,
                    :title => remote['title'],
                    :url => "http://www.flickr.com/photos/#{ACCOUNTS['flickr']['user']}/#{remote['id']}",
                    :thumbnail_url => remote['url_sq'],
                    :source => source,
                    :shortcode => unique_shortcode,
                    :imported_at => Time.now,
                    :created_at => remote['datetaken'])
        imported += 1
      end
    end
  end
  imported
end

# import entries from the blog

def fetch_blog(count=5)
  json = File.read("blog/_site/posts.json")
  blog = JSON.parse(json)
  # import to database
  source = 'blog'
  imported = 0
  blog.each do |remote|
    # sanitise uids, stripping non-alphanumerics and leading slash
    uid = remote['id'].to_s.gsub(/[^A-Za-z0-9-]/,'-')[1..(remote['id'].to_s.length)]
    if Item.where('uid = ? and source = ?', uid, source).count.zero?
      Item.create(:uid => uid,
                  :title => remote['title'],
                  :body => remote['summary'],
                  :url => remote['url'],
                  :source => source,
                  :shortcode => unique_shortcode,
                  :imported_at => Time.now,
                  :created_at => remote['posted'])
      imported += 1
    end
  end
  imported
end

# destroy an item

def destroy_item(sc)
  # does the item exist?
  return false if Item.where(:shortcode => sc).count.zero?
  # destroy the item
  Item.destroy_all(:shortcode => sc)
  true
end

# random four-char string

def shortcode
  # we want a number between 200,000 and 1,200,000
  num = rand(1000000) + 200000
  # use base58 (https://github.com/dougal/base58) to turn this into chars
  Base58.encode(num)
end

def unique_shortcode
  found = true
  while found == true
    sc = shortcode
    item = Item.where(:shortcode => sc)
    found = !item.length.zero?
  end
  sc
end