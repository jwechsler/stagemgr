# frozen_string_literal: true

module Lgl
  # Merges two Stagemgr addresses that LGL says are one person: the rule shared
  # by Lgl::Reconciler (LGL merged two constituents) and LglSyncAddressJob (an
  # unlinked address's email is on a constituent linked to its same-name twin).
  #
  # The keeper is the lower id, matching ConsolidateDuplicateAddresses and
  # Address#find_original. Never calls LGL; re-pointing the constituent at the
  # keeper is left to the caller (an enqueued LglSyncAddressJob).
  module AddressMerger
    # [:merged, keeper] | [:in_flight, nil] | [:not_duplicates, nil]
    def self.merge_pair(first, second)
      return [:not_duplicates, nil] unless duplicates?(first, second)

      if ConsolidateDuplicateAddresses.in_flight?([first, second])
        Rails.logger.info("[LGL] ##{first.id} / ##{second.id} in flight; merge skipped")
        return [:in_flight, nil]
      end

      keeper, duplicate = [first, second].sort_by(&:id)
      keeper.merge_and_purge(duplicate)
      Rails.logger.info("[LGL] merged address ##{duplicate.id} into ##{keeper.id} (LGL merge)")
      [:merged, keeper]
    end

    # Same non-blank search_name, or same non-blank email: Stagemgr's own
    # duplicate test, looser than ConsolidateDuplicateAddresses because LGL has
    # already said the two are one person.
    def self.duplicates?(first, second)
      same_present?(first.search_name, second.search_name) ||
        same_present?(first.email.to_s.strip.downcase, second.email.to_s.strip.downcase)
    end

    def self.same_present?(first, second)
      first.present? && first == second
    end
    private_class_method :same_present?
  end
end
