# frozen_string_literal: true

module Admin
  # The Merge customers page (admin/address_merges/new): one column per
  # customer of an Address::ManualMerge, a radio per value only where the
  # customers' values differ, and a summary of what the merge will do. The
  # page's script rebuilds the "comes from" sentence the same way
  # address_merge_sources_sentence does when a radio changes.
  module AddressMergesHelper
    FIELD_LABELS = {
      name: 'Name', address: 'Street address', email: 'Email', phone: 'Phone', lgl_id: 'LGL constituent'
    }.freeze
    SUMMARY_LABELS = {
      name: 'name', address: 'street address', email: 'email', phone: 'phone', lgl_id: 'LGL constituent'
    }.freeze

    # "#id Full Name" linking to the customer, the master's marked as kept.
    def address_merge_header(merge, address)
      title = link_to("##{address.id} #{address.full_name}".strip, admin_address_path(address))
      address.id == merge.master.id ? safe_join([title, ' (master, kept)']) : title
    end

    # +address+'s value for +field+: blank when it has none, a radio (checked
    # for the current choice) before it when the customers' values differ.
    # An LGL constituent link stays outside the radio's label, so following
    # it does not change the choice.
    def address_merge_cell(merge, field, address)
      value = merge.values_for(field)[address.id]
      return if value.nil?

      linked = field == :lgl_id
      shown = linked ? lgl_constituent_id_link(value) : value
      return shown unless merge.differs?(field)

      dom_id = "choices_#{field}_#{address.id}"
      radio = radio_button_tag("choices[#{field}]", address.id, merge.choice_for(field) == address.id,
                               id: dom_id, data: { label: SUMMARY_LABELS.fetch(field), customer: address.id })
      return safe_join([label_tag(dom_id, radio, 'aria-label': "LGL constituent #{value}"), ' ', shown]) if linked

      label_tag(dom_id, safe_join([radio, ' ', shown]))
    end

    # Data for a field's row. A row without radios carries the label and the
    # customer its value comes from for the page's script.
    def address_merge_row_data(merge, field)
      data = { merge_field: field }
      return data if merge.differs?(field)

      data.merge(label: SUMMARY_LABELS.fetch(field), customer: address_merge_source(merge, field))
    end

    # The customer whose value the master ends up with: the choice when values
    # differ; otherwise the master itself when it has the (same) value, or
    # the record that has one. nil when no customer has a value.
    def address_merge_source(merge, field)
      return merge.choice_for(field) if merge.differs?(field)

      merge.values_for(field)[merge.master.id] ? merge.master.id : merge.choice_for(field)
    end

    # "Name and email come from #2; phone comes from #3." for the fields whose
    # value comes from a customer other than the master; "" when none does.
    def address_merge_sources_sentence(merge)
      sources = Address::ManualMerge::FIELDS.map { |field| [SUMMARY_LABELS.fetch(field), address_merge_source(merge, field)] }
      groups = sources.reject { |_label, id| id.nil? || id == merge.master.id }.group_by(&:last)
      return '' if groups.empty?

      text = groups.map do |id, pairs|
        labels = pairs.map(&:first)
        "#{labels.to_sentence(last_word_connector: ' and ')} #{labels.one? ? 'comes' : 'come'} from ##{id}"
      end.join('; ')
      "#{text[0].upcase}#{text[1..]}."
    end

    # The #merge-summary paragraph's content for the current choices.
    def address_merge_summary(merge, constituent_id:)
      master = merge.master
      others = merge.addresses.drop(1)
      sources = address_merge_sources_sentence(merge)
      parts = ["Keeps ##{master.id} and deletes #{others.map { |a| "##{a.id}" }.join(', ')}.",
               tag.span(sources.empty? ? '' : " #{sources}", id: 'merge-summary-sources', data: { master: master.id })]
      moves = address_merge_moves(others, master)
      parts << " #{moves}" if moves
      parts << " Re-links LGL constituent #{constituent_id} to ##{master.id}." if constituent_id && Lgl.enabled?
      safe_join(parts)
    end

    def address_merge_member(address)
      return 'No' unless address.is_current_member?

      expires_on = address.current_membership&.expires_on
      expires_on ? "Yes, through #{expires_on.to_formatted_s(:long)}" : 'Yes'
    end

    # The donor-tier labels the customer page shows, or a dash.
    def address_merge_donor(address)
      labels = []
      last_year = address.donor_tier_for_last_fiscal_year
      current_year = address.donor_tier_for_current_fiscal_year
      labels << tag.span("Previous FY: #{last_year}", class: 'label warning') if last_year.present?
      labels << tag.span("Current FY: #{current_year}", class: 'label success') if current_year.present?
      labels.empty? ? '—' : safe_join(labels, ' ')
    end

    # The date of the customer's newest order (any status), or a dash.
    def address_merge_last_order(address)
      last_ordered_at = address.orders.maximum(:created_at)
      last_ordered_at ? last_ordered_at.to_date.to_formatted_s(:long) : '—'
    end

    private

    # "2 orders and 1 membership move to #1.", or nil when nothing moves.
    def address_merge_moves(others, master)
      counts = { 'order' => others.sum { |a| a.orders.count }, 'membership' => others.sum { |a| a.memberships.count } }
      things = counts.reject { |_noun, count| count.zero? }
      return if things.empty?

      verb = counts.values.sum == 1 ? 'moves' : 'move'
      "#{things.map { |noun, count| pluralize(count, noun) }.join(' and ')} #{verb} to ##{master.id}."
    end
  end
end
