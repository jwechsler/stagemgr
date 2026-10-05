require 'rails_helper'

RSpec.describe MembershipOffer do
  it 'defaults membership_type to production' do
    expect(MembershipOffer.new.membership_type).to eq(MembershipOffer::PRODUCTION)
  end

  it 'rejects a membership_type outside the allowed set' do
    offer = FactoryBot.build(:membership_offer, membership_type: 'bogus')

    expect(offer).not_to be_valid
    expect(offer.errors[:membership_type]).to be_present
  end

  it 'does not require a price_id for an active timed offer' do
    offer = FactoryBot.build(:membership_offer, :timed, status: MembershipOffer::ACTIVE, price_id: nil)

    expect(offer).to be_valid
  end

  it 'still requires a price_id for an active production offer' do
    offer = FactoryBot.build(:membership_offer, status: MembershipOffer::ACTIVE, price_id: nil)

    expect(offer).not_to be_valid
    expect(offer.errors[:price_id]).to be_present
  end

  it 'is never on sale to the public when timed, even if on_sale is set' do
    offer = FactoryBot.build(:membership_offer, :timed)
    offer.on_sale = true

    expect(offer.on_sale_to_public?).to be false
  end

  it 'forces on_sale to false when a timed offer is saved' do
    offer = FactoryBot.create(:membership_offer, :timed, status: MembershipOffer::ACTIVE)
    offer.on_sale = true
    offer.save!

    expect(offer.reload.on_sale).to be_falsey
  end

  # The scope is the query form of the predicate; a public page listing an offer
  # the predicate would reject prints a buy button that lands on "not available".
  describe '.on_sale_to_public' do
    it 'lists an active, on-sale production offer' do
      offer = FactoryBot.create(:membership_offer, name: 'Buyable')

      expect(MembershipOffer.on_sale_to_public).to contain_exactly(offer)
    end

    it 'agrees with #on_sale_to_public? for every row it returns' do
      FactoryBot.create(:membership_offer, name: 'Buyable')
      FactoryBot.create(:membership_offer, name: 'Off sale', on_sale: false)
      FactoryBot.create(:membership_offer, :timed, name: 'Library pass')

      expect(MembershipOffer.on_sale_to_public).to all(satisfy(&:on_sale_to_public?))
    end

    it 'excludes an offer left on sale by a callback-skipping write, as the predicate does' do
      offer = FactoryBot.create(:membership_offer, name: 'Retired')
      offer.update_columns(status: MembershipOffer::INACTIVE, on_sale: true)

      expect(MembershipOffer.on_sale_to_public).to be_empty
      expect(offer.reload.on_sale_to_public?).to be false
    end
  end

  describe '#usage_date_range' do
    it 'returns [nil, nil] for an offer with neither payments nor memberships' do
      offer = FactoryBot.create(:membership_offer, :timed)

      expect(offer.usage_date_range).to eq([nil, nil])
    end

    it 'spans from the earliest membership window to today for a payment-less timed offer' do
      offer = FactoryBot.create(:membership_offer, :timed)
      FactoryBot.create(:library_pass, membership_offer: offer, member_since: Date.new(2026, 4, 5))

      expect(offer.usage_date_range).to eq([Date.new(2026, 4, 5), Date.current])
    end

    it 'ignores Pending memberships when widening the range' do
      offer = FactoryBot.create(:membership_offer, :timed)
      FactoryBot.create(:library_pass, membership_offer: offer, member_since: Date.new(2026, 4, 5),
                                       status: Membership::PENDING)

      expect(offer.usage_date_range).to eq([nil, nil])
    end

    it 'widens a payment-derived range with earlier membership windows' do
      offer = FactoryBot.create(:membership_offer)
      order = FactoryBot.create(:membership_order)
      order.membership_line_item.update!(membership_offer: offer)
      order.membership.update!(membership_offer: offer, member_since: Date.new(2026, 2, 1))
      order.payments.each { |payment| payment.update!(processed_on: Time.zone.local(2026, 3, 15, 12, 0, 0)) }

      first, last = offer.usage_date_range
      expect(first).to eq(Date.new(2026, 2, 1))
      expect(last).to eq(Date.current)
    end
  end

  describe 'MyEmma group re-sync' do
    let!(:offer) { FactoryBot.create(:membership_offer, myemma_group: 'OLD') }

    # Offers carry a price_id, so creating one also enqueues a billing-period sync.
    before { allow(Resque).to receive(:enqueue) }

    context 'when MyEmma is enabled' do
      before { allow(MyEmma).to receive(:disabled?).and_return(false) }

      it 'enqueues a re-sync when the group changes' do
        expect(Resque).to receive(:enqueue).with(SyncMembershipOfferMyEmmaGroupJob, offer.id)

        offer.update!(myemma_group: 'NEW')
      end

      it 'does not enqueue when another attribute changes' do
        expect(Resque).not_to receive(:enqueue).with(SyncMembershipOfferMyEmmaGroupJob, anything)

        offer.update!(name: 'Renamed Offer')
      end

      it 'does not enqueue when the group is blanked' do
        expect(Resque).not_to receive(:enqueue).with(SyncMembershipOfferMyEmmaGroupJob, anything)

        offer.update!(myemma_group: '')
      end

      it 'does not enqueue on create' do
        expect(Resque).not_to receive(:enqueue).with(SyncMembershipOfferMyEmmaGroupJob, anything)

        FactoryBot.create(:membership_offer, name: 'Fresh', myemma_group: 'GRP')
      end
    end

    it 'does not enqueue when MyEmma is disabled (test default)' do
      expect(Resque).not_to receive(:enqueue).with(SyncMembershipOfferMyEmmaGroupJob, anything)

      offer.update!(myemma_group: 'NEW')
    end
  end

  describe 'billing period sync' do
    let!(:offer) { FactoryBot.create(:membership_offer, price_id: 'price_old') }

    before do
      offer.update_columns(billing_interval: MembershipOffer::YEAR, billing_interval_count: 1,
                           billing_period_synced_at: Time.current)
    end

    it 'enqueues a sync when an offer is created with a price_id' do
      expect(Resque).to receive(:enqueue).with(SyncMembershipOfferBillingPeriodJob, kind_of(Integer))

      FactoryBot.create(:membership_offer, name: 'Fresh', price_id: 'price_new')
    end

    it 'does not enqueue for an offer created without a price_id' do
      expect(Resque).not_to receive(:enqueue).with(SyncMembershipOfferBillingPeriodJob, anything)

      FactoryBot.create(:membership_offer, :timed, name: 'Library pass')
    end

    it 'enqueues a sync when the price_id changes' do
      expect(Resque).to receive(:enqueue).with(SyncMembershipOfferBillingPeriodJob, offer.id)

      offer.update!(price_id: 'price_new')
    end

    it 'does not enqueue when another attribute changes' do
      expect(Resque).not_to receive(:enqueue).with(SyncMembershipOfferBillingPeriodJob, anything)

      offer.update!(name: 'Renamed Offer')
    end

    it 'clears the cached period when the price_id changes' do
      allow(Resque).to receive(:enqueue)

      offer.update!(price_id: 'price_new')

      expect(offer.reload).to have_attributes(billing_interval: nil, billing_interval_count: nil,
                                              billing_period_synced_at: nil)
    end

    it 'keeps the cached period on unrelated edits' do
      offer.update!(name: 'Renamed Offer')

      expect(offer.reload.billing_interval).to eq(MembershipOffer::YEAR)
    end
  end

  describe '#billing_period_for, #billing_months and #billing_period_label' do
    def offer_with(interval, count = 1)
      FactoryBot.build(:membership_offer, billing_interval: interval, billing_interval_count: count)
    end

    def period(offer, paid_on, anchor_day)
      offer.billing_period_for(Date.parse(paid_on), anchor_day: anchor_day).map(&:iso8601)
    end

    it 'assumes calendar-monthly when the period has not been synced' do
      offer = offer_with(nil, nil)

      expect(period(offer, '2026-03-01', 1)).to eq(%w[2026-03-01 2026-04-01])
      expect(offer.billing_period_label).to eq('Monthly (assumed; not synced from Stripe)')
    end

    it 'runs a monthly period to the same day next month' do
      expect(period(offer_with(MembershipOffer::MONTH), '2026-03-09', 9)).to eq(%w[2026-03-09 2026-04-09])
      expect(period(offer_with(MembershipOffer::MONTH, 3), '2026-03-09', 9)).to eq(%w[2026-03-09 2026-06-09])
    end

    it "clamps a billing day the month doesn't have, then returns to it, as Stripe does" do
      offer = offer_with(MembershipOffer::MONTH)

      expect(period(offer, '2026-01-30', 30)).to eq(%w[2026-01-30 2026-02-28])
      expect(period(offer, '2026-02-28', 30)).to eq(%w[2026-02-28 2026-03-30])
    end

    it 'lets a late payment pay for the period it was due for' do
      offer = offer_with(MembershipOffer::MONTH)

      expect(period(offer, '2026-01-13', 9)).to eq(%w[2026-01-09 2026-02-09])
      expect(period(offer, '2026-02-02', 30)).to eq(%w[2026-01-30 2026-02-28])
    end

    it 'runs a yearly period to the same date the next year' do
      expect(period(offer_with(MembershipOffer::YEAR), '2025-07-01', 1)).to eq(%w[2025-07-01 2026-07-01])
      expect(period(offer_with(MembershipOffer::YEAR, 2), '2025-07-01', 1)).to eq(%w[2025-07-01 2027-07-01])
    end

    it 'counts weeks and days as fixed lengths from the payment' do
      expect(period(offer_with(MembershipOffer::WEEK, 2), '2026-03-09', 1)).to eq(%w[2026-03-09 2026-03-23])
      expect(period(offer_with(MembershipOffer::DAY, 30), '2026-03-09', 1)).to eq(%w[2026-03-09 2026-04-08])
    end

    it 'counts the months one payment pays for' do
      expect(offer_with(nil, nil).billing_months).to eq(1)
      expect(offer_with(MembershipOffer::MONTH, 3).billing_months).to eq(3)
      expect(offer_with(MembershipOffer::YEAR, 2).billing_months).to eq(24)
      expect(offer_with(MembershipOffer::WEEK, 2).billing_months).to eq(BigDecimal(14) / BigDecimal('30.44'))
      expect(offer_with(MembershipOffer::ONE_TIME, nil).billing_months).to be_nil
    end

    it 'leaves a one-time price for the caller to spread' do
      offer = offer_with(MembershipOffer::ONE_TIME, nil)

      expect(offer.billing_period_for(Date.new(2026, 3, 9), anchor_day: 9)).to be_nil
      expect(offer.billing_period_label).to eq('One-time payment (from Stripe)')
    end

    it 'labels a synced recurring period' do
      expect(offer_with(MembershipOffer::MONTH).billing_period_label).to eq('Every 1 month (from Stripe)')
      expect(offer_with(MembershipOffer::YEAR, 2).billing_period_label).to eq('Every 2 years (from Stripe)')
    end
  end

  describe 'member ID card artwork', :membership_cards do
    let(:offer) { FactoryBot.create(:membership_offer) }

    def png_upload(image, filename = 'art.png')
      path = image_file(image)
      Rack::Test::UploadedFile.new(path, 'image/png', original_filename: filename)
    end

    it 'has no card until a background is uploaded' do
      expect(offer).not_to be_card_available
      expect(offer.missing_card_artwork).to eq(['background', 'front overlay', 'name font', 'label font'])
    end

    it 'accepts a background at the card size' do
      offer.card_background = png_upload(synthetic_background)

      expect(offer).to be_valid
      offer.save!
      expect(offer.reload).to be_card_available
      expect(offer.missing_card_artwork).to eq(['front overlay', 'name font', 'label font'])
    end

    it 'rejects a background that is not 1011 x 638' do
      offer.card_background = png_upload(synthetic_background(width: 1000, height: 600))

      expect(offer).not_to be_valid
      expect(offer.errors[:card_background].join).to include('1011x638').and include('1000x600')
    end

    it 'rejects an overlay that is not the card size' do
      offer.card_front_overlay = png_upload(synthetic_front.extract_area(0, 0, 500, 300))

      expect(offer).not_to be_valid
      expect(offer.errors[:card_front_overlay]).to be_present
    end

    it 'rejects a non-image background' do
      Tempfile.create(['not-image', '.png']) do |file|
        file.write('plain text')
        file.flush
        offer.card_background = Rack::Test::UploadedFile.new(file.path, 'text/plain', original_filename: 'x.png')

        expect(offer).not_to be_valid
        expect(offer.errors[:card_background]).to be_present
      end
    end

    it 'rejects a font upload that is not an OpenType or TrueType file' do
      Tempfile.create(['not-font', '.otf']) do |file|
        file.write('%PDF-1.4 not a font')
        file.flush
        offer.card_name_font = Rack::Test::UploadedFile.new(file.path, 'font/otf', original_filename: 'x.otf')

        expect(offer).not_to be_valid
        expect(offer.errors[:card_name_font].join).to include('OpenType')
      end
    end

    it 'accepts a real font file' do
      path = system_bold_font_path || skip('fontconfig has no bold .ttf/.otf font to upload')
      offer.card_label_font = Rack::Test::UploadedFile.new(path, 'font/ttf', original_filename: File.basename(path))

      expect(offer).to be_valid
    end
  end
end
