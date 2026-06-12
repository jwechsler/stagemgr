class ReceiptPayment < ActiveResource::Base
  self.site = $TKTPRINT['service']
  self.element_name = "payment"
  self.format = :xml
  self.ssl_options = { :verify_mode => OpenSSL::SSL::VERIFY_NONE }
end
