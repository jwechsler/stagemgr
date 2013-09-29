class DefaultTicketClass < ActiveRecord::Base
  attr_accessible :class_code, :class_name, :minutes_before_show, :ticket_price, :ticket_type, :ticketing_fee, :web_visible, :auto_attach, :software_managed, :holds_seats

  def to_hash
    h = self.attributes
    h.delete(:id)
    h
  end

end
