class PrintOrder < ActiveResource::Base
  self.headers['Authorization'] = 'Token token="REDACTED_TKTPRINT_TOKEN"'

  self.site = $TKTPRINT['service']
  self.format = :json
  self.element_name = "order"
  # self.ssl_options={:verify_mode=>OpenSSL::SSL::VERIFY_NONE}
  self.timeout = 120
  has_many :tickets
end