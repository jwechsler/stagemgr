class AddAcceptsDonationsToTheater < ActiveRecord::Migration[6.1]
  def change
    add_column :theaters, :accepts_donations, :boolean, default: true
  end
end
