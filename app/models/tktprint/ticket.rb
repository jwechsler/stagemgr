class Ticket < ActiveResource::Base
    self.site = $TKTPRINT['service']
end