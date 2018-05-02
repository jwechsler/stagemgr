class DefaultTicketClass < ActiveRecord::Base

  def to_hash
    h = self.attributes
    h.delete('id')
    h.delete('created_at')
    h.delete('updated_at')
    h
  end

end
