class RenameHeardAboutToMarketingSource < ActiveRecord::Migration[4.2]
  def self.up
    rename_column :orders, :heard_about, :marketing_source
  end

  def self.down
    rename_column :orders, :marketing_source, :heard_about
  end

end
