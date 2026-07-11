require 'rails_helper'

RSpec.describe MembershipOrder do
  it 'should automatically notify management when the embedded recurring profile is suspended' do
    recurring_order = FactoryBot.create(:membership_order)
    pending_tasks = recurring_order.tasks.count
    profile = recurring_order.recurring_profile
    expect(profile.status).to eq(RecurringProfile::ACTIVE)
    profile.status = RecurringProfile::SUSPENDED
    profile.save
    recurring_order.reload
    expect(profile.recurring_order.tasks.count).to eq(pending_tasks + 1)
    expect(profile.recurring_order.tasks.last).to be_kind_of(NotificationTask)
  end

  it 'refuses to purchase a timed (library pass) offer and never touches Stripe' do
    address = FactoryBot.create(:address)
    offer = FactoryBot.create(:membership_offer, :timed)
    order = MembershipOrder.new(address: address,
                                payment_type: FactoryBot.create(:credit_card_payment_type))
    order.membership_line_item = FactoryBot.build(:membership_line_item, membership_offer: offer,
                                                                         address: address, order: order)

    expect(PaymentProcessing).not_to receive(:create_subscription)
    expect { order.transition_processing_to_processed! }
      .to raise_error(/issued by the box office/)
  end
end
