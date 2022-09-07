class AddMyEmmaGroupToTheater < ActiveRecord::Migration[4.2]
  def change
    add_column :theaters, :myemma_attendee_group, :string
  end
end
