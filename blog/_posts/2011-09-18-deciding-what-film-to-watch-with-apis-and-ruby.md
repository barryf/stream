---
layout: post
title: Deciding what film to watch with APIs and Ruby
date: 2011-09-18 20:49:00

---

As part of my Sky <s>tax</s>subscription, I get [Anytime+](http://www.sky.com/shop/tv/anytime-plus/), a video-on-demand (VOD) service that gives you access to hundreds of films for download over the internet. Sky's set-top box shows you a selection of what's available grouped into genres and the website [lists them alphabetically](http://www.sky.com/shop/tv/anytime-plus/whats-on/full-movies-list/). 

The problem is deciding what to watch. I can Google the name of each film from the big list and check the individual ratings on a movie website, but there's just too many to choose from. I may waste an evening on the sofa with Vampires Suck and miss out on Raging Bull. What I need is a way of ranking these films so that I can cherrypick the best.

[Anytom](https://github.com/barryf/anytom) is my hacker's solution. It's a set of scripts that scrapes Sky's public film list, queries the Rotten Tomatoes API for critics' ratings, running times, year and synopsis and displays each in ratings order. I can then find the hidden gems and ignore the dross.

I'm using [hpricot](http://hpricot.com/) to parse Sky's HTML and [Rotten Tomatoes' API](http://developer.rottentomatoes.com/) to get the ratings and other data for each of the films. [Sinatra](http://www.sinatrarb.com/) serves up the list in rankings order and Ruby glues it all together.

[Check out the source on GitHub](https://github.com/barryf/anytom).

The name? ANYtime rotten TOMatoes.
