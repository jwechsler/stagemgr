class PrintLineItem < ActiveResource::Base
  self.format = :xml
  self.site = Rails.configuration.x.tktprint['service']
  self.element_name = 'line_item'
  self.ssl_options = { verify_mode: OpenSSL::SSL::VERIFY_NONE }
end
