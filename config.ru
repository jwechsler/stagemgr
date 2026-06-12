# This file is used by Rack-based servers to start the application.

require_relative 'config/environment'

run Rails.application
Rails.application.load_server

# map '/' do
#  run Stagemgr::Application
# end

map '/admin/resque' do
  run Stagemgr::Resque
end
