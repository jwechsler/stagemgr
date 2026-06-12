class UpdateTheaterIdsForFlexPasses < ActiveRecord::Migration[4.2]
  def self.up
    FlexPassLineItem.all.each do |fli|
      if !fli.flex_pass_offer.theater_id.nil? && fli.order.theater.nil?
        fli.order.theater = fli.flex_pass_offer.theater
        fli.order.save!
      end
    end
  end

  def self.down; end
end
