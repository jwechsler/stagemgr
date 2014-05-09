class AddCalendarCalloutToProductions < ActiveRecord::Migration
  def change
    add_column :productions, :calendar_callout, :text
  end
end
