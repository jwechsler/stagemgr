class AddPerformanceSpecificSpecialFeaturesToPerformances < ActiveRecord::Migration[4.2]
  def change
    add_column :performances, :special_feature_display_markdown, :text
    add_column :performances, :special_feature_email_markdown, :text
  end
end
