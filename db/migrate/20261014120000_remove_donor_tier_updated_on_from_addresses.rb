class RemoveDonorTierUpdatedOnFromAddresses < ActiveRecord::Migration[6.1]
  # Donor tiers are now kept current by LglDonorImport (customers missing from
  # the LGL report are cleared), so the date stamp has no reader left.
  def change
    remove_column :addresses, :donor_tier_updated_on, :date
  end
end
