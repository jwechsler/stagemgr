class AddDonationAppealsToTheaters < ActiveRecord::Migration[6.1]
  # Editable, markdown-enabled donation appeals shown in the ticket and flex
  # pass checkouts. donation_appeal stays blank so Theater::DEFAULT_DONATION_APPEAL
  # applies. The default theater's secondary appeal (shown on resident,
  # visiting and guest company orders) is seeded with the wording the checkout
  # used before the field existed, with placeholders in place of the names.
  SECONDARY_APPEAL = 'In addition to its own award-winning programming, {{theater}} subsidizes facilities ' \
                     'and support for groups like {{company}}. Help us bring theater, laughter and debate ' \
                     'to our community. Please add a tax-deductible contribution to this order.'.freeze

  def up
    change_table :theaters, bulk: true do |t|
      t.text :donation_appeal
      t.text :secondary_donation_appeal
    end
    backfill_secondary_appeal
  end

  def down
    change_table :theaters, bulk: true do |t|
      t.remove :donation_appeal
      t.remove :secondary_donation_appeal
    end
  end

  private

  def backfill_secondary_appeal
    default_id = select_value("SELECT MIN(id) FROM theaters WHERE theater_class = 'Default'")
    return if default_id.nil?

    execute(<<~SQL.squish)
      UPDATE theaters SET secondary_donation_appeal = #{quote(SECONDARY_APPEAL)}
      WHERE id = #{Integer(default_id)} AND secondary_donation_appeal IS NULL
    SQL
  end
end
