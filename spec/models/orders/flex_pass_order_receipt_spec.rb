require 'rails_helper'

# Covers the orders.suppress_receipt column, which FlexPassOrder#create_receipt_task
# is the only order subclass to honour. Until the box office form exposed it, the
# column's only writer was BulkFlexOrderImport.
RSpec.describe FlexPassOrder, type: :model do
  def flexpass_confirmation_tasks(order)
    order.tasks.select { |t| t.method_symbol.to_s == 'flexpass_confirmation' }
  end

  describe 'the purchase confirmation task' do
    it 'is queued when suppress_receipt is false' do
      order = FactoryBot.create(:flex_pass_order)

      order.transition_to!(Order::PROCESSED)

      expect(flexpass_confirmation_tasks(order.reload).size).to eq(1)
    end

    it 'is not queued when suppress_receipt is set' do
      order = FactoryBot.create(:flex_pass_order)
      order.suppress_receipt = true

      order.transition_to!(Order::PROCESSED)

      expect(order.reload).to be_processed
      expect(flexpass_confirmation_tasks(order)).to be_empty
    end

    it 'persists the flag so the reason the email was skipped is auditable' do
      order = FactoryBot.create(:flex_pass_order)
      order.suppress_receipt = true

      order.transition_to!(Order::PROCESSED)

      expect(order.reload.suppress_receipt).to be(true)
    end

    it 'defaults to sending, so an order that never sets the flag still confirms' do
      order = FactoryBot.create(:flex_pass_order)

      expect(order.suppress_receipt).to be(false)

      order.transition_to!(Order::PROCESSED)

      expect(flexpass_confirmation_tasks(order.reload).size).to eq(1)
    end
  end
end
