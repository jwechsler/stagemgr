class PrintOrder < ActiveResource::Base
  self.site = $TKTPRINT['service']
  self.format = :xml
  self.element_name = "order"
  # self.ssl_options={:verify_mode=>OpenSSL::SSL::VERIFY_NONE}
  self.timeout = 120
end