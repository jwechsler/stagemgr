require 'spec_helper.rb'

describe MembershipOrder do

  it 'should automatically notify management when the embedded recurring profile is suspended' do
    recurring_order = FactoryGirl.create(:membership_order)
    pending_tasks = recurring_order.tasks.count
    profile = recurring_order.recurring_profile
    profile.status.should eq(RecurringProfile::ACTIVE)
    profile.status = RecurringProfile::SUSPENDED
    profile.save
    recurring_order.reload
    profile.recurring_order.tasks.count.should == pending_tasks + 1
    profile.recurring_order.tasks.last.should be_kind_of(NotificationTask)
  end

end