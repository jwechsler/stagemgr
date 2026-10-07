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

  describe 'usage scopes' do
    let(:offer) { FactoryBot.create(:flex_pass_offer, number_of_tickets: 3) }

    before { allow(Resque).to receive(:enqueue_in) }

    def sell_pass
      FactoryBot.create(:flex_pass_order, flex_pass_offer: offer).flex_pass_line_item.flex_pass
    end

    it 'splits passes at today: expiring today is unexpired' do
      today = sell_pass.tap { |pass| pass.update_columns(expiration_date: Date.current) }
      yesterday = sell_pass.tap { |pass| pass.update_columns(expiration_date: Date.current - 1) }

      expect(FlexPass.unexpired).to contain_exactly(today)
      expect(FlexPass.expired).to contain_exactly(yesterday)
    end

    it 'counts only flex pass payments as tickets redeemed' do
      pass = sell_pass
      FactoryBot.create(:flex_pass_payment, order: pass.order, flex_pass: pass, number_of_tickets: 2)
      FactoryBot.create(:cash_payment, order: pass.order, amount: 10).update_columns(flex_pass_id: pass.id, number_of_tickets: 1)

      expect(FlexPass.with_tickets_redeemed.find(pass.id).tickets_redeemed).to eq(2)
    end

    it 'treats active, unexpired passes with tickets left as outstanding' do
      outstanding = sell_pass
      sell_pass.update_columns(active: false)
      sell_pass.update_columns(expiration_date: Date.current - 1)
      exhausted = sell_pass
      FactoryBot.create(:flex_pass_payment, order: exhausted.order, flex_pass: exhausted, number_of_tickets: 3)

      expect(FlexPass.outstanding).to contain_exactly(outstanding)
      expect(FlexPass.outstanding.with_tickets_redeemed.count(:all)).to eq(1)
    end
  end
end
