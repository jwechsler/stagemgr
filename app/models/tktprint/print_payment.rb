class PrintPayment < ActiveResource::Base
  self.site = Rails.configuration.x.tktprint['service']
  self.element_name = 'line_item'
  self.format = :xml
  self.ssl_options = { verify_mode: OpenSSL::SSL::VERIFY_NONE }
end
