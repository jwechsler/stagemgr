class Ticket < ActiveResource::Base
  self.site = $TKTPRINT['service']
  self.format = :json
  self.element_name = "ticket"
  belongs_to :print_order
end
