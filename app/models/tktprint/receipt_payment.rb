class ReceiptPayment < ActiveResource::Base
  self.site = $TKTPRINT['service']
  self.element_name = "payment"
end