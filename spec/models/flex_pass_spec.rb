require 'rails_helper'

RSpec.describe FlexPass, type: :model do
  describe 'expiration job enqueueing' do
    it 'enqueues expiration once the creating transaction commits' do
      expect(Resque).to receive(:enqueue_in).with(anything, ExpireFlexPass, anything)

      FactoryBot.create(:flex_pass_order)
    end

    it 'does not enqueue expiration when the creating transaction rolls back' do
      expect(Resque).not_to receive(:enqueue_in)

      Order.transaction do
        FactoryBot.create(:flex_pass_order)
        raise ActiveRecord::Rollback
      end
    end
  end
end
