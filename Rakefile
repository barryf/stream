desc "This task is called by the Heroku cron add-on"
task :cron do
  require 'barryfrost'
  fetch_all
  CACHE.flush
end