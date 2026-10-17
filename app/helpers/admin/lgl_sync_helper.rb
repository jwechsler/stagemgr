module Admin
  module LglSyncHelper
    # The flagged customer's name, linked to their page; when several customers
    # matched one constituent, linked to the customer list filtered by their
    # last name so the duplicates can be selected and merged together.
    def lgl_review_customer_link(tag)
      address = tag.address
      label = address.full_name.presence || "##{tag.address_id}"
      last_name = address.last_name.to_s.strip
      if last_name.present? && tag.tag_value.to_s.include?(Lgl::ConstituentReplicator::SEVERAL_MATCHES_REASON)
        link_to label, admin_addresses_path(search: last_name), title: "Customers named #{last_name}"
      else
        link_to label, admin_address_path(tag.address_id)
      end
    end
  end
end
