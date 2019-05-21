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

end