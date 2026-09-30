require 'rails_helper'

RSpec.describe TicketOrder, '#resend_confirmation!' do
  let(:order) { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_credit_card) }

  def confirmation_tasks
    OutreachTask.where(order_id: order.id, method_symbol: 'ticket_confirmation')
  end

  before { allow_any_instance_of(OutreachTask).to receive(:run!) }

  it 'reuses the existing confirmation task instead of adding another' do
    existing = confirmation_tasks.first || OutreachTask.create!(execute_at: Time.current,
                                                                method_symbol: :ticket_confirmation, order: order)
    order.tasks.reload

    expect { order.resend_confirmation! }.not_to(change { confirmation_tasks.count })
    expect(confirmation_tasks.pluck(:id)).to eq([existing.id])
  end

  it 'creates a confirmation task when the order has none' do
    confirmation_tasks.delete_all
    order.tasks.reload

    expect { order.resend_confirmation! }.to change { confirmation_tasks.count }.from(0).to(1)
  end
end
