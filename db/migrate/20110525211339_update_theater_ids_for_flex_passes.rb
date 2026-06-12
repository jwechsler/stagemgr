class UpdateTheaterIdsForFlexPasses < ActiveRecord::Migration[4.2]
  def self.up
    FlexPassLineItem.all.each { |fli|
      if !fli.flex_pass_offer.theater_id.nil? && fli.order.theater.nil? then
        fli.order.theater = fli.flex_pass_offer.theater
        fli.order.save!
      end
    }
  end

  def self.down
  end
end
