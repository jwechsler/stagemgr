class AddFlexPassCodeToOrders < ActiveRecord::Migration[6.1]
  # flex_pass_code was an attr_accessor, so it only survived as long as the
  # request that set it. A flex pass order parked in HOLD (season seating, or a
  # box office hold) therefore lost every reference to its pass -- nothing links
  # the order to the FlexPass until the FlexPassPayment is built at PROCESSED --
  # and FinalizeSeasonSeating could never release it.
  def change
    add_column :orders, :flex_pass_code, :string
    add_index :orders, :flex_pass_code
  end
end
