# Builds ActionMailer's default_url_options from server.yml.
#
# The app is mounted under a sub-URI (server.yml `sub_uri`, e.g. "/tickets").
# Route helpers only know about that mount when Passenger exports
# RAILS_RELATIVE_URL_ROOT into the process; the Resque worker that delivers
# most of our mail has no such env and would otherwise emit unprefixed paths.
# Passing :script_name explicitly settles it for every process --
# ActionDispatch::Routing::RouteSet#find_script_name prefers it over
# relative_url_root -- so the mount point appears exactly once whether the mail
# is delivered from a worker or inline from a web request.
#
# Folding sub_uri into :host instead, as production did from 2019 until this
# change, doubled the prefix under Passenger (/tickets/tickets/...), which 404'd
# the sidebar images and links of any mail sent inline from a request.
module MailerUrlOptions
  DEFAULT_HOST = 'localhost'.freeze
  DEFAULT_PROTOCOL = 'http'.freeze

  def self.for(server_config)
    config = server_config || {}

    {
      host: config['host'].presence || DEFAULT_HOST,
      protocol: config['host_protocol'].presence || DEFAULT_PROTOCOL,
      script_name: config['sub_uri'].presence
    }.compact
  end
end
