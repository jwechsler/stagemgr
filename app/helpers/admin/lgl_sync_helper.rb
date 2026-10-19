module Admin
  module LglSyncHelper
    # The first column of an LGL Review row (an Lgl::ReviewList::Row). A
    # several-matches row shows the email the flagged customers share, linked
    # to the customer list searched by it; any other row links each customer
    # to their page.
    def lgl_review_identity(row)
      emails = row.several_matches? ? row.emails : []
      links = if emails.any?
                emails.map { |email| link_to email, admin_addresses_path(search: email), title: "Customers with #{email}" }
              else
                row.tags.map { |tag| lgl_review_customer_link(tag) }.uniq
              end
      safe_join(links, ', ')
    end

    # The Merge button on a several-matches row, naming the customers in its
    # confirm. The server reads the flagged set again on the click.
    def lgl_review_merge_button(row)
      return unless row.several_matches? && row.addresses.size > 1

      names = row.addresses.map { |address| lgl_review_customer_label(address) }
      confirm = "Merge #{names.to_sentence} into ##{row.addresses.first.id}?"
      path = admin_lgl_sync_merge_path(constituent_id: row.constituent_id)
      button_to 'Merge', path, method: :post, class: 'button tiny', data: { confirm: confirm }
    end

    private

    def lgl_review_customer_link(tag)
      return "##{tag.address_id}" unless tag.address

      link_to lgl_review_customer_label(tag.address), admin_address_path(tag.address_id)
    end

    def lgl_review_customer_label(address)
      name = address.full_name.to_s.strip
      name.empty? ? "##{address.id}" : "#{name} (##{address.id})"
    end
  end
end
