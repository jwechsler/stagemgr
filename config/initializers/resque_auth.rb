
if $SERVER_CONFIG.has_key?('resque_admin_password')

  Resque::Server.use(Rack::Auth::Basic) do |user, password|
    password == $SERVER_CONFIG['resque_admin_password']
  end

end
