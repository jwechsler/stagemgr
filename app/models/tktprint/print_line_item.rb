class PrintLineItem < ActiveResource::Base
  self.format = :xml
  self.site = $TKTPRINT['service']
  self.element_name = "line_item"
  self.ssl_options={:verify_mode=>OpenSSL::SSL::VERIFY_NONE}
end
