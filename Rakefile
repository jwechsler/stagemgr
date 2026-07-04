# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path('config/application', __dir__)
require 'rake'

begin
  require 'single_test'
  require 'single_test/tasks'
rescue LoadError
  # development-only helper; absent in production bundle
end

Stagemgr::Application.load_tasks
