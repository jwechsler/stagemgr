require 'rails_helper'

# NotificationTask sends an internal alert about an order to each address in
# its comma-separated notifications list, calling
# NotificationMailer.<method_symbol>(order, address).
RSpec.describe NotificationTask, type: :model do
  describe 'the refunded fulfilled order alert' do
    let(:email_addresses) { Rails.configuration.x.email_address }
    let(:box_office) { email_addresses['box_office'] }
    let(:supervisor) { email_addresses['supervisor_notifications'] }
    let(:refunder) { FactoryBot.create(:user, email: 'refunder@example.com') }
    let(:order) do
      FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash).tap do |o|
        o.update_column(:status, Order::FULFILLED)
      end
    end

    def refund_alert_tasks
      NotificationTask.where(order: order, method_symbol: 'refunded_fulfilled_item_alert')
    end

    before { ActionMailer::Base.deliveries.clear }

    # Regression: refund! checked fulfilled? only after setting the status to
    # REFUNDED, so the alert task was never created.
    it 'is queued when a fulfilled order is refunded' do
      Audited.audit_class.as_user(refunder) { order.refund! }

      expect(refund_alert_tasks.count).to eq(1)
      expect(refund_alert_tasks.first.notifications.split(',')).to eq([box_office, supervisor])
    end

    it 'is not queued when an order that was never fulfilled is refunded' do
      order.update_column(:status, Order::PROCESSED)

      order.refund!

      expect(refund_alert_tasks).to be_empty
    end

    # Regression: the alert lived on OrderMailer, so NotificationTask's
    # NotificationMailer.send raised NoMethodError on every attempt.
    it 'delivers the alert to the box office and supervisor when run' do
      Audited.audit_class.as_user(refunder) { order.refund! }
      task = refund_alert_tasks.first

      task.run!

      expect(task.reload.status).to eq(OrderTask::COMPLETED)
      expect(task.result).to be_nil
      expect(ActionMailer::Base.deliveries.map(&:to)).to eq([[box_office], [supervisor]])

      mail = ActionMailer::Base.deliveries.first
      expect(mail.subject).to eq("Warning: Fulfilled order #{order.id} refunded")
      expect(mail.from).to eq([box_office])
      expect(mail.body.to_s).to include("Order ##{order.id}, which had already been fulfilled, " \
                                        'has been refunded by refunder@example.com')
    end
  end
end
