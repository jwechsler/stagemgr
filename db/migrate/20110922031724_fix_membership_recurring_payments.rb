class FixMembershipRecurringPayments < ActiveRecord::Migration
  def self.up
    memberships = Membership.all

    memberships.each do |m|
      m.update_from_profile!
      o = m.membership_line_item.order
      o.tasks << CheckMembershipTask.new(:execute_at=>m.next_billing_date + 2.hours)
      o.save!
      c_start_date = m.member_since
      o_id = m.membership_line_item.order_id
      m.number_cycles_completed.times do
        execute "insert into payments (order_id, transaction_id, amount, type, created_at, updated_at) values (#{o_id}, '#{m.profile_id}', #{m.membership_offer.recurring_cost}, 'RecurringPayment',  '#{c_start_date.strftime('%Y-%m-%d')}', '#{c_start_date.strftime('%Y-%m-%d')}')"
        c_start_date += 1.month
      end
    end
    execute "commit"


  end

  def self.down
  end
end
