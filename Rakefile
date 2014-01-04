desc "This task is called by the Heroku scheduler add-on"
task :fetch_all do
  require './stream'
  fetch_all
  CACHE.flush
end