---
layout: post
title: Sinatra and Heroku tips
date: 2011-04-19 21:04:00
---

While [building this site](/articles/a-new-start) I read several useful articles that promoted best practices for [Sinatra](http://sinatrarb.com/) and [Heroku](http://www.heroku.com/). What follows are fairly raw tips and code snippets that I found useful and might be handy for you.

## Use Bundler for your gems

Some of the older Heroku documentation suggests using a `.gems` file. At the time of writing, best practice is to [use Bundler](http://devcenter.heroku.com/articles/bundler):

    $ sudo gem install bundler
    
Create a file called `Gemfile` in your application root:

    source :gemcutter
    gem 'sinatra'
    # add any other gems you need here
    
Then run:

    $ bundle install
    
Don't forget to add the `Gemfile` and `Gemfile.lock` to your repo:

    $ git add Gemfile Gemfile.lock
    $ git commit -m "Adding Gemfile and Gemfile.lock for Bundler."
    
When you come to deploy your application Heroku will pick these files up and install any dependencies your application needs. Magic.

Further information is in the [Heroku Bundler article](http://devcenter.heroku.com/articles/bundler).

## Use memcached to store page content

In your `configure` block add the following:

    configure do
      ...
      require 'memcached'
      CACHE = Memcached.new
      ...
    end

Then in actions where you want to save the content:

    get '/' do
      begin
        content = CACHE.get("home")
      rescue Memcached::NotFound
        content = erb(:home)
        CACHE.set("home", content)
      end
      content
    end

You'll need to make sure you have a local Memcached instance running while developing. I leave this running in a Terminal window via `memcached -vv` to get verbose debugging output.

## Use Heroku's Varnish caching

Heroku includes a built-in server-side page cache. If you set HTTP headers in your response then Varnish will do the rest. I've set up a simple helper for this:

    helpers do
      ...
      def cache_for(mins = 1)
        if settings.environment != :development
          response['Cache-Control'] = "public, max-age=#{60*mins}"
        end
      end
      ...
    end

Because browsers also pick up on these cache directives you get the double benefit of your visitors' browsers caching pages, plus the server. 

I don't want the caching to kick in when developing, however, so only do this when not in development mode.

## Escape variables output in HTML

When outputting content, especially anything entered by a user, it's best to escape it to prevent malicious users stealing cookies or other bad behaviour. In your controller, include the following in your `helpers` block:

    helpers do
      ...
      include Rack::Utils
      alias_method :h, :escape_html
      ...
    end

Then, in your view, you can escape any variable as follows:

    <p><%= h @my_potentially_naughty_variable %></p>

## Use UTF-8

You want to use UTF-8 right? 

> Save your pages as UTF-8, whenever you can.

--[W3C Internationalization tutorial](http://www.w3.org/International/tutorials/tutorial-char-enc/)

Add this `before` block and forget about it:

    before do
      ...
      headers "Content-Type" => "text/html; charset=utf-8"
      ...
    end
    
## Miscellany

Other useful things I found:

- In Ruby, if you want to use a substring, you can simply treat a string as an array (almost everything's an object). So, for example, `"Barry Frost"[0..4]` == `"Barry"`
- Learn to use the ternary operator. Code becomes much more readable as a result, e.g. `content = @items.length > 0 ? erb(:index, :layout => !request.xhr?) : ''`
- Having `irb` to hand to try out code without a compile/page reload cycle is so refreshing. Try out and debug regular expressions before writing any code.