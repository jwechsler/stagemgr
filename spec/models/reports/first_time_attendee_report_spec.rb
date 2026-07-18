require 'rails_helper'

RSpec.describe FirstTimeAttendeeReport, type: :model do
  let(:start_date) { Date.current - 30 }
  let(:theater)    { FactoryBot.create(:theater, name: 'FTA Main Stage') }
  let(:production) { FactoryBot.create(:production, theater: theater) }

  # The ticket_class factory find_or_creates by class_code (and ignores the
  # production it's handed), so the comp and non-comp classes get distinct
  # explicit codes. Both are let! so they exist before the first performance
  # is created (the performance factory snapshots production.ticket_classes
  # into allocations, and the association caches).
  let!(:regular_class) do
    FactoryBot.create(:ticket_class, class_code: 'FTAREG', class_name: 'FTA Regular',
                                     complimentary: false, production: production)
  end
  let!(:comp_class) do
    FactoryBot.create(:ticket_class, class_code: 'FTACMP', class_name: 'FTA Comp',
                                     ticket_price: 0.0, complimentary: true, production: production)
  end

  def create_performance(date, prod = production)
    FactoryBot.create(:performance, production: prod, performance_date: date)
  end

  def create_attended_order(address:, on:, ticket_class: regular_class,
                            status: Order::FULFILLED, performance: nil)
    performance ||= create_performance(on)
    order = FactoryBot.create(:ticket_order, address: address, performance: performance)
    order.ticket_line_items << FactoryBot.build(:ticket_line_item, order: order,
                                                                   ticket_class: ticket_class, ticket_count: 1)
    order.update!(status: status)
    order
  end

  def add_flex_pass_payment(order)
    flex_pass = FactoryBot.create(:flex_pass_order).flex_pass
    FactoryBot.create(:flex_pass_payment, order: order, flex_pass: flex_pass,
                                          number_of_tickets: 1, amount: 0)
  end

  def add_membership_payment(order, membership_type:)
    offer = if membership_type == MembershipOffer::TIMED
              FactoryBot.create(:membership_offer, :timed)
            else
              FactoryBot.create(:membership_offer) # membership_type defaults to 'production'
            end
    membership = FactoryBot.create(:membership, address: order.address,
                                                membership_offer: offer,
                                                member_code: "FTA-#{order.id}")
    FactoryBot.create(:membership_payment, order: order, membership: membership,
                                           number_of_tickets: 1, amount: 0)
  end

  def run_report(as_of = start_date)
    report = described_class.new(as_of)
    allow(report).to receive(:save_report_to_filestore) # bypass IO
    report.create
    report
  end

  def rows(report)
    report.data[FirstTimeAttendeeReport::TRG_SEGMENT_CODE]
  end

  def reported_address_ids(report)
    rows(report).map { |row| row[:StagemgrPatronID] }
  end

  def row_for(report, address)
    rows(report).find { |row| row[:StagemgrPatronID] == address.id }
  end

  describe 'start date boundary' do
    it 'includes a patron whose first attendance is exactly on the start date' do
      address = FactoryBot.create(:address)
      create_attended_order(address: address, on: start_date)

      expect(reported_address_ids(run_report)).to include(address.id)
    end

    it 'excludes a patron who first attended the day before, even with later visits in the window' do
      address = FactoryBot.create(:address)
      create_attended_order(address: address, on: start_date - 1)
      create_attended_order(address: address, on: start_date + 5)

      expect(reported_address_ids(run_report)).not_to include(address.id)
    end

    it 'never counts future performances as attendance' do
      address = FactoryBot.create(:address)
      create_attended_order(address: address, on: Date.current + 7)

      expect(reported_address_ids(run_report)).not_to include(address.id)
    end
  end

  describe 'comp attendance' do
    it 'includes a patron whose first visit was a comp, dating them from that comp visit' do
      address = FactoryBot.create(:address)
      create_attended_order(address: address, on: start_date + 1, ticket_class: comp_class)
      create_attended_order(address: address, on: start_date + 10)

      row = row_for(run_report, address)
      expect(row).to be_present
      expect(row[:FirstAttendedDate]).to eq(start_date + 1)
    end

    it 'excludes a patron whose history is comps only' do
      address = FactoryBot.create(:address)
      create_attended_order(address: address, on: start_date + 1, ticket_class: comp_class)
      create_attended_order(address: address, on: start_date + 10, ticket_class: comp_class)

      expect(reported_address_ids(run_report)).not_to include(address.id)
    end
  end

  describe 'membership-paid orders' do
    it 'excludes a patron whose only order was paid with a standard (production) membership' do
      address = FactoryBot.create(:address)
      order = create_attended_order(address: address, on: start_date + 1)
      add_membership_payment(order, membership_type: MembershipOffer::PRODUCTION)

      expect(reported_address_ids(run_report)).not_to include(address.id)
    end

    it 'includes a patron whose only order was paid with a timed membership' do
      address = FactoryBot.create(:address)
      order = create_attended_order(address: address, on: start_date + 1)
      add_membership_payment(order, membership_type: MembershipOffer::TIMED)

      expect(reported_address_ids(run_report)).to include(address.id)
    end
  end

  describe 'flex-pass-paid orders' do
    it 'excludes a patron whose only order was paid with a flex pass' do
      address = FactoryBot.create(:address)
      order = create_attended_order(address: address, on: start_date + 1)
      add_flex_pass_payment(order)

      expect(reported_address_ids(run_report)).not_to include(address.id)
    end

    it 'includes a flex-pass attendee who also has a separately paid visit' do
      address = FactoryBot.create(:address)
      flex_order = create_attended_order(address: address, on: start_date + 1)
      add_flex_pass_payment(flex_order)
      create_attended_order(address: address, on: start_date + 8)

      row = row_for(run_report, address)
      expect(row).to be_present
      # First attendance still counts the flex visit; only *qualifying* is gated.
      expect(row[:FirstAttendedDate]).to eq(start_date + 1)
    end
  end

  describe 'fulfillment requirement' do
    it 'excludes a patron whose only orders are PROCESSED but never FULFILLED' do
      address = FactoryBot.create(:address)
      create_attended_order(address: address, on: start_date + 1, status: Order::PROCESSED)
      create_attended_order(address: address, on: start_date + 6, status: Order::PROCESSED)

      expect(reported_address_ids(run_report)).not_to include(address.id)
    end

    it 'dates a patron from a PROCESSED first visit once a later order is FULFILLED' do
      address = FactoryBot.create(:address)
      create_attended_order(address: address, on: start_date + 1, status: Order::PROCESSED)
      create_attended_order(address: address, on: start_date + 6)

      row = row_for(run_report, address)
      expect(row).to be_present
      expect(row[:FirstAttendedDate]).to eq(start_date + 1)
    end

    it 'still disqualifies on a PROCESSED attendance before the start date' do
      address = FactoryBot.create(:address)
      create_attended_order(address: address, on: start_date - 2, status: Order::PROCESSED)
      create_attended_order(address: address, on: start_date + 6)

      expect(reported_address_ids(run_report)).not_to include(address.id)
    end
  end

  describe 'address filters' do
    it 'excludes placeholder addresses' do
      address = FactoryBot.create(:address, placeholder: true)
      create_attended_order(address: address, on: start_date + 1)

      expect(reported_address_ids(run_report)).not_to include(address.id)
    end

    it 'excludes addresses with neither a street address nor an email' do
      address = FactoryBot.create(:address, line1: nil, email: nil)
      create_attended_order(address: address, on: start_date + 1)

      expect(reported_address_ids(run_report)).not_to include(address.id)
    end

    it 'includes an email-only address' do
      address = FactoryBot.create(:address, line1: nil)
      create_attended_order(address: address, on: start_date + 1)

      expect(reported_address_ids(run_report)).to include(address.id)
    end
  end

  describe 'row shape' do
    it 'emits one STB row per address with the TRG columns plus the two extras' do
      address = FactoryBot.create(:address)
      create_attended_order(address: address, on: start_date + 2)
      create_attended_order(address: address, on: start_date + 9)

      report = run_report
      expect(report.headers).to eq(MailingList::TRG_IMPORT_HEADERS + %i[FirstAttendedDate FirstAttendedTheatre])
      expect(report.data.keys).to eq([FirstTimeAttendeeReport::TRG_SEGMENT_CODE])

      matching = rows(report).select { |row| row[:StagemgrPatronID] == address.id }
      expect(matching.size).to eq(1)

      row = matching.first
      expect(row[:Season]).to eq(start_date.year)
      expect(row[:Title]).to eq("First Time Attendee as of #{start_date.strftime('%m/%d')}")
      expect(row[:Email]).to eq(address.email)
      expect(row[:FirstAttendedDate]).to eq(start_date + 2)
      expect(row[:FirstAttendedTheatre]).to eq('FTA Main Stage')
      # :Segment auto-emits the data-hash key at CSV time; rows never carry it.
      expect(row).not_to have_key(:Segment)
    end

    it 'formats the segment title from the start date without a year' do
      expect(described_class.new(Date.new(2026, 7, 1)).segment_title)
        .to eq('First Time Attendee as of 07/01')
    end
  end

  describe 'same-date theater tie' do
    it 'breaks a same-date tie deterministically by the lower order id' do
      address = FactoryBot.create(:address)
      other_theater = FactoryBot.create(:theater, name: 'FTA Second Stage')
      other_production = FactoryBot.create(:production, theater: other_theater)
      other_class = FactoryBot.create(:ticket_class, class_code: 'FTAREG2', class_name: 'FTA Regular 2',
                                                     complimentary: false, production: other_production)
      tie_date = start_date + 3

      create_attended_order(address: address, on: tie_date) # lower id, FTA Main Stage
      create_attended_order(address: address, on: tie_date, ticket_class: other_class,
                            performance: create_performance(tie_date, other_production))

      expect(row_for(run_report, address)[:FirstAttendedTheatre]).to eq('FTA Main Stage')
    end
  end

  describe 'refunded orders' do
    it 'ignores a refunded order when establishing first attendance' do
      address = FactoryBot.create(:address)
      create_attended_order(address: address, on: start_date - 5, status: Order::REFUNDED)
      create_attended_order(address: address, on: start_date + 4)

      row = row_for(run_report, address)
      expect(row).to be_present
      expect(row[:FirstAttendedDate]).to eq(start_date + 4)
    end

    it 'excludes a patron whose only order was refunded' do
      address = FactoryBot.create(:address)
      create_attended_order(address: address, on: start_date + 4, status: Order::REFUNDED)

      expect(reported_address_ids(run_report)).not_to include(address.id)
    end
  end
end
