module Admin::MembershipAnalysisHelper
  EMPTY_CELL = "—".freeze

  # Money the way the reports print it ($1,234.50), or a dash when there is no
  # value (an economics spread over no memberships).
  def membership_money(value)
    value.nil? ? EMPTY_CELL : value.to_money.formatted_with_symbol
  end

  # "14.2 months", or a dash when there are no memberships to average.
  def membership_length(days)
    return EMPTY_CELL if days.nil?

    "#{(days / MembershipMetrics::AVERAGE_DAYS_PER_MONTH).round(1).to_f} months"
  end

  # The Total row has no offer; offer rows carry an Inactive label when the
  # offer is no longer active.
  def membership_offer_cell(offer)
    return 'Total' if offer.nil?

    safe_join([offer.name, (tag.span('Inactive', class: 'label secondary') unless offer.active?)].compact, ' ')
  end

  # The Total row (no offer) is set in bold.
  def total_row_class(stats)
    'membership-analysis__total' if stats.offer.nil?
  end

  # A min or max figure with the member code it came from, linked to the
  # membership's admin page.
  def membership_extreme(value, membership)
    return EMPTY_CELL if value.nil?

    safe_join([membership_money(value), ' (', link_to(membership.member_code, admin_membership_path(membership.id)),
               ')'])
  end
end
