class Ticket < ActiveResource::Base
  self.site = Rails.configuration.x.tktprint['service']
  self.format = :json
  self.element_name = 'ticket'
  belongs_to :print_order
end
