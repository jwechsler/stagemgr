class PrintPayment < ActiveResource::Base
  self.site = $TKTPRINT['service']
  self.element_name = "line_item"
end