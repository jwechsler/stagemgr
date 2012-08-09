class PrintPayment < ActiveResource::Base
  self.site = $TKTPRINT['service']
  self.element_name = "line_item"
  self.format = :xml
   self.ssl_options={:verify_mode=>OpenSSL::SSL::VERIFY_NONE}
end