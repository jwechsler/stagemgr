class PrintOrder < ActiveResource::Base
  uri = URI.parse(Rails.configuration.x.tktprint['service'])
  if uri.user && uri.password
    self.user = uri.user
    self.password = uri.password
    # Remove credentials from URL for clean site setting
    uri.userinfo = nil
    self.site = uri.to_s
  else
    self.site = Rails.configuration.x.tktprint['service']
  end
  self.format = :json
  self.element_name = 'order'
  # self.ssl_options={:verify_mode=>OpenSSL::SSL::VERIFY_NONE}
  self.timeout = 120
  has_many :tickets
end
