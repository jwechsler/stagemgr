class RenameHeardAboutToMarketingSource < ActiveRecord::Migration
  def self.up
    rename_column :orders, :heard_about, :marketing_source
  end

  def self.down
    rename_column :orders, :marketing_source, :heard_about
  end

end
