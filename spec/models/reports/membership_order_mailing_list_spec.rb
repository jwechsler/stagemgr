require 'rails_helper'

RSpec.describe MembershipOrderMailingList do
  let(:starting_date) { Date.new(2026, 5, 1) }
  let(:ending_date) { Date.new(2026, 5, 31) }
  let(:in_may) { Date.new(2026, 5, 10) }

  let(:gold_offer)   { FactoryBot.create(:membership_offer, name: 'Gold') }
  let(:silver_offer) { FactoryBot.create(:membership_offer, name: 'Silver') }

  def create_membership_order_for(offer)
    order = FactoryBot.create(:membership_order)
    order.membership_line_item.update!(membership_offer: offer)
    order.membership.update!(membership_offer: offer, member_since: in_may)
    order
  end

  def member_titles(report)
    allow(report).to receive(:save_report_to_filestore)
    report.create
    report.data['MEM'].pluck(:Title)
  end

  before do
    create_membership_order_for(gold_offer)
    create_membership_order_for(silver_offer)
  end

  it 'includes every membership order in range when no offers are selected' do
    report = described_class.new(starting_date, ending_date, false)
    expect(member_titles(report)).to contain_exactly('Gold', 'Silver')
  end

  it 'restricts to the selected offers' do
    report = described_class.new(starting_date, ending_date, false, [gold_offer.id])
    expect(member_titles(report)).to contain_exactly('Gold')
  end

  it 'accepts several offer ids' do
    report = described_class.new(starting_date, ending_date, false, [gold_offer.id, silver_offer.id])
    expect(member_titles(report)).to contain_exactly('Gold', 'Silver')
  end
end
