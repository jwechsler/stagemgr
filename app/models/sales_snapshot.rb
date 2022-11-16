class SalesSnapshot < ApplicationRecord
  belongs_to :production_stat, inverse_of: :sales_snapshots
end
