class AddCheckPaymentType < ActiveRecord::Migration
  def up
    payment = CheckPaymentType.new(:display_name=>"Check")
    payment.save!
  end

  def down
  end
end
