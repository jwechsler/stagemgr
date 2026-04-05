class ChangeTheatersAcceptsDonationsDefaultToFalse < ActiveRecord::Migration[6.1]
  def change
    change_column_default :theaters, :accepts_donations, from: true, to: false
  end
end
