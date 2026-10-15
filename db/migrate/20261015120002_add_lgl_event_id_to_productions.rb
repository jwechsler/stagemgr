class AddLglEventIdToProductions < ActiveRecord::Migration[6.1]
  # The LGL event standing for this production, so gifts given around a show
  # are attributed to it.
  def change
    add_column :productions, :lgl_event_id, :bigint
  end
end
