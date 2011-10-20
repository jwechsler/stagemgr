class Ticket < ActiveResource::Base
  self.site = $TKTPRINT['service']
  self.ssl_options={:verify_mode=>OpenSSL::SSL::VERIFY_NONE}
end