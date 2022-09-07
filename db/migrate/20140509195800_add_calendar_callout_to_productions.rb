class AddCalendarCalloutToProductions < ActiveRecord::Migration[4.2]
  def change
    add_column :productions, :calendar_callout, :text
  end
end
