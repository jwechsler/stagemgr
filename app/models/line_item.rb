class LineItem < ActiveRecord::Base
  belongs_to :performance
  belongs_to :ticket_class
  belongs_to :order
end
