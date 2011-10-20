class PrintOrder < ActiveResource::Base
  self.site = $TKTPRINT['service']
  self.element_name = "order"


end