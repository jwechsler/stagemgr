require 'rails_helper'

RSpec.describe SpecialOffer, type: :model do
  describe 'status scopes' do
    let!(:active_offer)   { FactoryBot.create(:percent_off_special_offer, status: SpecialOffer::ACTIVE) }
    let!(:inactive_offer) { FactoryBot.create(:percent_off_special_offer, status: SpecialOffer::INACTIVE) }
    let!(:expired_offer)  { FactoryBot.create(:percent_off_special_offer, status: SpecialOffer::EXPIRED) }

    describe '.status_active' do
      it 'returns only Active offers' do
        expect(described_class.status_active).to contain_exactly(active_offer)
      end
    end

    describe '.status_inactive_or_expired' do
      it 'returns Inactive and Expired offers' do
        expect(described_class.status_inactive_or_expired)
          .to contain_exactly(inactive_offer, expired_offer)
      end
    end
  end

  describe '.deactivate_stale_offers' do
    # Pin the clock so "1 month ago" is stable regardless of when specs run
    # (late-evening Pacific runs cross the UTC date boundary).
    around do |example|
      travel_to(Time.zone.local(2026, 6, 15, 12, 0, 0)) { example.run }
    end

    let(:cutoff) { 1.month.ago.to_date }

    def create_offer(attrs = {})
      FactoryBot.create(:percent_off_special_offer, { status: SpecialOffer::ACTIVE }.merge(attrs))
    end

    context 'with performance-scoped offers' do
      it 'deactivates offers whose performance is more than a month past' do
        performance = FactoryBot.create(:performance, performance_date: cutoff - 1.month)
        offer = create_offer(performance: performance)

        expect { described_class.deactivate_stale_offers }
          .to change { offer.reload.status }
          .from(SpecialOffer::ACTIVE).to(SpecialOffer::INACTIVE)
      end

      it 'leaves offers whose performance is within the last month' do
        performance = FactoryBot.create(:performance, performance_date: Date.current - 1.week)
        offer = create_offer(performance: performance)

        expect { described_class.deactivate_stale_offers }
          .not_to(change { offer.reload.status })
      end
    end

    context 'with production-scoped offers' do
      it 'deactivates offers whose production closed more than a month ago' do
        production = FactoryBot.create(:production, closing_at: cutoff - 1.month)
        offer = create_offer(production: production)

        expect { described_class.deactivate_stale_offers }
          .to change { offer.reload.status }.to(SpecialOffer::INACTIVE)
      end

      it 'leaves offers whose production closed within the last month' do
        production = FactoryBot.create(:production, closing_at: Date.current - 2.weeks)
        offer = create_offer(production: production)

        expect { described_class.deactivate_stale_offers }
          .not_to(change { offer.reload.status })
      end

      context 'when the production has no closing date' do
        # Production now validates closing_at presence; NULLs exist only on
        # legacy rows, so bypass validation the way those rows arose.
        def production_without_closing_date
          FactoryBot.create(:production).tap { |p| p.update_column(:closing_at, nil) }
        end

        it 'falls back to the latest active performance date' do
          production = production_without_closing_date
          FactoryBot.create(:performance, production: production,
                                          performance_date: cutoff - 2.months)
          offer = create_offer(production: production)

          expect { described_class.deactivate_stale_offers }
            .to change { offer.reload.status }.to(SpecialOffer::INACTIVE)
        end

        it 'leaves offers when the latest performance is recent' do
          production = production_without_closing_date
          FactoryBot.create(:performance, production: production,
                                          performance_date: Date.current - 1.week)
          offer = create_offer(production: production)

          expect { described_class.deactivate_stale_offers }
            .not_to(change { offer.reload.status })
        end

        it 'leaves offers when the production has no performances at all' do
          production = production_without_closing_date
          offer = create_offer(production: production)

          expect { described_class.deactivate_stale_offers }
            .not_to(change { offer.reload.status })
        end
      end
    end

    context 'with expiration dates' do
      it 'deactivates offers whose auto_expire is more than a month past' do
        offer = create_offer(auto_expire: cutoff - 1.day)

        expect { described_class.deactivate_stale_offers }
          .to change { offer.reload.status }.to(SpecialOffer::INACTIVE)
      end

      it 'leaves offers expiring exactly at the cutoff (strict comparison)' do
        offer = create_offer(auto_expire: cutoff)

        expect { described_class.deactivate_stale_offers }
          .not_to(change { offer.reload.status })
      end

      it 'leaves offers with no expiration date' do
        offer = create_offer(auto_expire: nil)

        expect { described_class.deactivate_stale_offers }
          .not_to(change { offer.reload.status })
      end
    end

    context 'with performance date range filters' do
      it 'deactivates offers whose performances-on-or-before date is more than a month past' do
        offer = create_offer(performance_end_range: cutoff - 1.week)

        expect { described_class.deactivate_stale_offers }
          .to change { offer.reload.status }.to(SpecialOffer::INACTIVE)
      end

      it 'leaves offers whose end range is recent' do
        offer = create_offer(performance_end_range: Date.current - 1.week)

        expect { described_class.deactivate_stale_offers }
          .not_to(change { offer.reload.status })
      end
    end

    context 'with theater-scoped offers' do
      it 'does not deactivate based on the theater having only past productions' do
        theater = FactoryBot.create(:theater)
        FactoryBot.create(:production, theater: theater, closing_at: cutoff - 6.months)
        offer = create_offer(theater: theater)

        expect { described_class.deactivate_stale_offers }
          .not_to(change { offer.reload.status })
      end
    end

    context 'with non-Active offers' do
      it 'leaves Inactive and Expired offers untouched even with stale dates' do
        inactive = create_offer(status: SpecialOffer::INACTIVE, auto_expire: cutoff - 1.year)
        expired = create_offer(status: SpecialOffer::EXPIRED, auto_expire: cutoff - 1.year)

        described_class.deactivate_stale_offers

        expect(inactive.reload.status).to eq(SpecialOffer::INACTIVE)
        expect(expired.reload.status).to eq(SpecialOffer::EXPIRED)
      end
    end

    it 'returns the number of deactivated offers and bumps updated_at' do
      offers = Array.new(2) { create_offer(auto_expire: cutoff - 1.week) }
      offers.each { |o| o.update_column(:updated_at, 1.year.ago) }
      create_offer(auto_expire: nil)

      expect(described_class.deactivate_stale_offers).to eq(2)
      offers.each do |offer|
        expect(offer.reload.updated_at).to be > 1.day.ago
      end
    end
  end
end
