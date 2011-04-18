---
layout: post
title: A new start
date: 2011-04-18 22:41:00
---

Earlier this year, back in January in fact, I had a few nagging aims/resolutions on my to-do list. I wanted to:

- Improve my rusty and weak Ruby
- Migrate from Subversion to git and put some code up on [GitHub](http://github.com/barryf)
- Try out [Sinatra](http://sinatrarb.com/), a lightweight Ruby web framework built on [Rack](http://rack.rubyforge.org/)
- Investigate [Heroku](http://www.heroku.com/) for hosting something in Ruby
- Get blogging! For the occasions when I have something to share

Meanwhile my personal website had become rather clunky, outdated and in dire need of a refresh.  

> What made it click for me was programming in anger. ... When you’re learning on a mission, the order of things come really naturally.
--[David Heinemeier Hansson, 37signals](http://37signals.com/svn/posts/2582-how-do-i-learn-to-program)

As DHH wrote, the best way to learn a programming language or technology is to build something real. So I set about killing multiple birds with one stone by learning and experimenting while dragging my website into the two-thousand-and-tens.

This website is the end result. Here's a screenshot from the new homepage, captured as I write this:

![April 2011 screenshot of barryfrost.com](http://dl.dropbox.com/u/207451/Screenshots/barryfrost.com_redesign_apr_2011.png)

## Design and concept

Back before [FriendFeed was gobbled up by Facebook](http://techcrunch.com/2009/08/10/facebook-acquires-friendfeed/), lifestream services were [hot](http://techcrunch.com/2008/03/10/watch-out-friendfeed-socialthing-is-even-easier-to-use/). I've used Twitter, Delicious, Last.fm, Flickr and others for several years and there's a lot of content and attention data I've accumulated with third parties. I wanted to aggregate my decentralised data into a chronological stream on my own site, as much for my own interest as a potentially useful collection for visitors inexplicably interested in what I do.

A couple of years ago I knocked up a design for a stream with indenting and colour-coding for each service. Tweaking this prototype a bit, it formed the central theme for the redesign. Articles would also be pulled in and listed via this "hub".

I used this redesign as a good opportunity to play with web fonts -- [LFT Etica Web](http://typekit.com/fonts/lft-etica-web) through [Typekit](http://typekit.com/) -- and HTML5 markup (e.g. `<header>`, `<footer>` and `<article>` tags) and some new-to-me CSS in terms of text shadows and `position: fixed` elements.

I've also experimented with [media queries](http://mediaqueri.es/) so that when the page is resized or displayed on small screens the layout and content adjusts via CSS.

## Hosting with Heroku

I'm hosting everything with [Heroku](http://www.heroku.com/), a ridiculously simple Ruby hosting platform that's built on top of Amazon's infrastructure. Deploying is simply a matter of a `git push heroku master` and you're given a wealth of [add-on services](http://addons.heroku.com/) to choose from that require zero-setup. 

I'm using PostgreSQL to store my stream data and sort by date/source, although you can also use Redis, CouchDB and other popular nosql engines with Heroku if you only need key/value pairs. MySQL isn't available, but that's not a big problem for a greenfield project like this and it's fun to be using the very able PostgreSQL RDBMS again.

Whole page content variables are cached with the built-in Memcached store for performance and I'm also making thorough use of cache-control headers which are picked up by Heroku's Varnish layer and also client browsers. If I'm ever lucky enough to be Fireballed, Slashdotted, Reditted or HackerNews'd I've got multiple layers of caching protection for almost no effort.

## Blogging with Jekyll

I wanted to start a blog. I knew that I wouldn't go from never blogging to become prolific, but for the rare occasions when I do have something to share, I wanted an outlet.

Initially I flirted with the idea of using a hosted blog system like Wordpress, Tumblr or Posterous but this seemed overkill. As a sometime hacker I wanted something I could tinker with and that I could host with the main site on Heroku. Using a separate domain (or subdomain) with an external service felt unnecessarily messy.

Searching around I (re)read [Tom Preston-Werner](http://tom.preston-werner.com/)'s [Blogging Like a Hacker](http://tom.preston-werner.com/2008/11/17/blogging-like-a-hacker.html) post which describes his desire for a lo-fi solution that resulted in [Jekyll](http://github.com/mojombo/jekyll). Bingo. Jekyll means I can write articles in [Simplenote](http://simplenoteapp.com/) or Textmate in [Markdown](http://daringfireball.net/projects/markdown/), run them through the Jekyll server which generates simple static HTML files and an Atom feed. I then deploy all these via Git to my site and Sinatra serves them up.

## Stream in Ruby

The Sinatra app is [fairly simple](http://github.com/barryf/barryfrost.com): a collection of fetchers pull down JSON feeds from each of the services and insert new items into a table. The results are pulled out and aggregated into the stream. 

For tweets in the stream, I've linked up usernames, links and hashtags. Any links with redirects that have been shortened are followed to get the canonical URL. Plus all links are sent to [oohEmbed](http://oohembed.com/) to see if they support oEmbed and there's a thumbnail to display, for example with [Twitpic](http://twitpic.com/) images.

## What's left

I've brushed up on Ruby, but I neglected to spend any time on tests. Naughty Barry. Rather than go back and retrospectively add them, I'll set myself a new project to apply good TDD principles.

You can find all the code in my [repo on GitHub](http://github.com/barryf/barryfrost.com). Feel free to poke around and fork but please don't steal my design or stylesheets.