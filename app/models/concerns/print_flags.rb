# frozen_string_literal: true

# Which icons a TicketOrder asks tktprint to print on its box office receipt.
# tktprint holds no business rules: it only knows icon names (its
# config/flags.yml). What each icon means is decided here, in one place.
#
# Every rule reads stored columns, so building the payload inside PrintBatchJob
# makes no extra queries and no LGL calls.
module PrintFlags
  extend ActiveSupport::Concern

  # Icon names are tktprint's; the meaning is ours. Rule order is print order.
  PRINT_FLAG_RULES = [
    [:star, ->(order) { order.address.vip? }],
    [:flag, ->(order) { order.address.flagged_donor? }],
    [:checkmark, ->(order) { order.notes.present? }]
  ].freeze

  # tktprint prints at most this many icons.
  MAX_PRINT_FLAGS = 3

  # Icon names for this order, as strings in rule order; [] when none apply.
  def print_flags
    PRINT_FLAG_RULES.select { |_, rule| rule.call(self) }.map { |name, _| name.to_s }.first(MAX_PRINT_FLAGS)
  end
end
