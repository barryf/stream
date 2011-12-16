desc "This task is called by the Heroku scheduler add-on"
task :fetch_all do
  require './barryfrost'
  fetch_all
  CACHE.flush
end