class AddMyEmmaGroupToTheater < ActiveRecord::Migration
  def change
    add_column :theaters, :myemma_attendee_group, :string
  end
end
