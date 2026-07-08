class RenameFestivalSlugAndDropStoredDates < ActiveRecord::Migration[6.1]
  def change
    rename_column :festivals, :slug, :url_name

    # Festival dates are always derived from the member productions; storing a
    # second, manually maintained range invited data-entry drift.
    remove_column :festivals, :starts_on, :date
    remove_column :festivals, :ends_on, :date
  end
end
