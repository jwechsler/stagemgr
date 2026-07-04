if Rails.configuration.x.server_config.key?('resque_admin_password')

  Resque::Server.use(Rack::Auth::Basic) do |_user, password|
    password == Rails.configuration.x.server_config['resque_admin_password']
  end

end
