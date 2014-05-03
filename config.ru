# This file is used by Rack-based servers to start the application.

require ::File.expand_path('../config/environment',  __FILE__)
map '/' do
  run Stagemgr::Application
end

map '/admin/resque' do
  run Stagemgr::Resque
end
