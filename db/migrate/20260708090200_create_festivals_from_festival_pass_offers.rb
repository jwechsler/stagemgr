class CreateFestivalsFromFestivalPassOffers < ActiveRecord::Migration[6.1]
  # Model stubs so this migration stays valid as app models evolve
  class MigrationFestival < ActiveRecord::Base
    self.table_name = 'festivals'
  end

  class MigrationFlexPassOffer < ActiveRecord::Base
    self.table_name = 'flex_pass_offers'
  end

  class MigrationProduction < ActiveRecord::Base
    self.table_name = 'productions'
  end

  class MigrationPerformance < ActiveRecord::Base
    self.table_name = 'performances'
  end

  def up
    # A festival grouping is any offer that productions point at via
    # flex_pass_offer_id ("Festival Pass Offer" in the production form).
    # treat_as_festival_pass alone is not reliable: it postdates the oldest
    # festival offers and was never backfilled.
    festival_offer_ids = MigrationProduction.where.not(flex_pass_offer_id: nil)
                                            .distinct.pluck(:flex_pass_offer_id)
    MigrationFlexPassOffer.where(id: festival_offer_ids).find_each do |offer|
      productions = MigrationProduction.where(flex_pass_offer_id: offer.id)

      festival = MigrationFestival.create!(
        name: offer.name,
        description: offer.description,
        short_description: offer.short_description,
        status: festival_status(productions),
        starts_on: derived_start(productions),
        ends_on: derived_end(productions)
      )
      productions.update_all(festival_id: festival.id)
      offer.update_column(:festival_id, festival.id)
    end
  end

  def down
    festival_ids = MigrationFestival.pluck(:id)
    MigrationProduction.where(festival_id: festival_ids).update_all(festival_id: nil)
    MigrationFlexPassOffer.where(festival_id: festival_ids).update_all(festival_id: nil)
    MigrationFestival.where(id: festival_ids).delete_all
  end

  private

  def festival_status(productions)
    open = productions.any? do |p|
      closing = p.closing_at || latest_performance_date(p)
      closing.nil? || closing >= Date.today
    end
    open ? 'Active' : 'Inactive'
  end

  def derived_start(productions)
    productions.filter_map { |p| p.first_preview_at || p.press_opening_at || p.opening_at }.min
  end

  def derived_end(productions)
    productions.filter_map { |p| p.closing_at || latest_performance_date(p) }.max
  end

  def latest_performance_date(production)
    MigrationPerformance.where(production_id: production.id, status: 'Active')
                        .maximum(:performance_date)
  end
end
