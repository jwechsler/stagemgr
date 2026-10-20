module Admin
  module LglSyncHelper
    # The first column of an LGL Review row (an Lgl::ReviewList::Row). A
    # several-matches row shows one line per flagged customer: a link to
    # their page, then their email as plain text. Each customer matched
    # because their email is one of the constituent's emails, so differing
    # emails are expected. Any other row links each customer to their page.
    def lgl_review_identity(row)
      return safe_join(row.tags.map { |tag| lgl_review_customer_link(tag) }.uniq, ', ') unless row.several_matches?

      lines = row.addresses.map do |address|
        email = address.email.to_s.strip
        parts = [lgl_review_address_link(address)]
        parts << email unless email.empty?
        safe_join(parts, ' ')
      end
      safe_join(lines, tag.br)
    end

    # "LGL constituent N", N linking to the constituent in LGL when
    # littlegreenlight.web_url is set. A row with no single constituent (an
    # :other row) lists each constituent its reason names, comma-separated;
    # nil when there are none.
    def lgl_review_constituent(row)
      ids = row.constituent_id ? [row.constituent_id] : Lgl::ReviewList.constituent_ids_in(row.reason)
      return if ids.empty?

      safe_join(ids.map { |id| safe_join(['LGL constituent ', lgl_constituent_id_link(id)]) }, ', ')
    end

    # An LGL Review reason as HTML, each LGL constituent id it names
    # (Lgl::ReviewList::CONSTITUENT_LIST) linked to LGL when
    # littlegreenlight.web_url is set. Customer ids ("#5678") and external ids
    # stay text; everything else is escaped.
    def lgl_review_reason_html(reason)
      text = reason.to_s
      pieces = []
      pos = 0
      text.to_enum(:scan, Lgl::ReviewList::CONSTITUENT_LIST).each do
        match = Regexp.last_match
        pieces << text[pos...match.begin(1)] << lgl_constituent_list_links(match[1])
        pos = match.end(1)
      end
      safe_join(pieces << text[pos..])
    end

    # The Merge button on a several-matches row with 2+ customers (either
    # wording): a link to the Merge customers page for those customers, which
    # re-links the kept one to the row's constituent afterwards.
    def lgl_review_merge_button(row)
      return unless row.several_matches? && row.addresses.size > 1

      path = new_admin_address_merge_path(ids: row.addresses.map(&:id), constituent_id: row.constituent_id)
      link_to('Merge', path, class: 'button tiny')
    end

    # The distinct first names of +addresses+, as "Glen, Beth".
    def lgl_review_first_names(addresses)
      Lgl::ReviewList.first_names(addresses).join(', ')
    end

    # +id+ linked to the constituent in LGL, or plain text when no web URL is set.
    def lgl_constituent_id_link(id)
      url = Lgl.constituent_url(id)
      url ? link_to(id.to_s, url, target: '_blank', rel: 'noopener') : id.to_s
    end

    def lgl_review_customer_label(address)
      name = address.full_name.to_s.strip
      name.empty? ? "##{address.id}" : "#{name} (##{address.id})"
    end

    private

    def lgl_constituent_list_links(list)
      safe_join(list.split(/(\d+)/).map { |part| part.match?(/\A\d+\z/) ? lgl_constituent_id_link(part.to_i) : part })
    end

    def lgl_review_customer_link(tag)
      return "##{tag.address_id}" unless tag.address

      lgl_review_address_link(tag.address)
    end

    def lgl_review_address_link(address)
      link_to lgl_review_customer_label(address), admin_address_path(address.id)
    end
  end
end
