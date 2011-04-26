# barryfrost.com

This is my personal website. It consists of a little Sinatra app that imports my feeds and assembles items into an aggregated chronological page, plus static blog articles that were generated using Jekyll.

Building this has been a simple exercise that I'm using to help me learn and experiment with Ruby, Sinatra, Heroku and other things.

## TODO

- Short URLs - bfr.st?
- Sort out timezones
- Finish sidebar "about"
- Microformats and rel="me"s
- sitemap.xml
- Foursquare check-ins
- geolocation maps from Tweets/check-ins

## SETUP

This is a bit hacky and not really intended for anyone else to use, but if you really want to please a) let me know, b) remove my design and references to me, c) set up a PostgreSQL database, d) configure the following

### Environment Variables

These can either be environment variables or Heroku config keys:

- `FLICKR_API_KEY` -- your private Flickr API key
- `LASTFM_API_KEY` -- your private Last.fm API key
- `ADMIN_PASSWORD` -- a password you want to use to protect unauthorised building

### Heroku Add-ons

If you're using Heroku you'll need:

- `memcache:5mb`

## COPYRIGHT

The design and blog articles are not to be re-used or reproduced. Not terribly exciting anyway.

Copyright (c) 2011 [Barry Frost](http://barryfrost.com).
