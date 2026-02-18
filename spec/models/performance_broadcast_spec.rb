require 'rails_helper'

RSpec.describe PerformanceBroadcast, type: :model do
  let(:theater) { FactoryBot.create(:theater) }
  let(:production) { FactoryBot.create(:production, theater: theater) }
  let(:performance) { FactoryBot.create(:performance, production: production) }
  let(:user) { FactoryBot.create(:user) }

  describe 'associations' do
    it 'belongs to performance' do
      broadcast = FactoryBot.build(:performance_broadcast)
      expect(broadcast.performance).to be_a(Performance)
    end

    it 'belongs to user' do
      broadcast = FactoryBot.build(:performance_broadcast)
      expect(broadcast.user).to be_a(User)
    end
  end

  describe 'validations' do
    it 'requires subject' do
      broadcast = FactoryBot.build(:performance_broadcast, subject: nil)
      expect(broadcast).not_to be_valid
      expect(broadcast.errors[:subject]).to include("can't be blank")
    end

    it 'requires from_address' do
      broadcast = FactoryBot.build(:performance_broadcast, from_address: nil)
      expect(broadcast).not_to be_valid
      expect(broadcast.errors[:from_address]).to include("can't be blank")
    end

    it 'requires body' do
      broadcast = FactoryBot.build(:performance_broadcast, body: nil)
      expect(broadcast).not_to be_valid
      expect(broadcast.errors[:body]).to include("can't be blank")
    end

    it 'is valid with all required attributes' do
      broadcast = FactoryBot.build(:performance_broadcast)
      expect(broadcast).to be_valid
    end
  end

  describe '#recipient_orders' do
    let(:broadcast) do
      FactoryBot.create(:performance_broadcast,
             performance: performance,
             user: user,
             subject: 'Test Subject',
             from_address: 'test@example.com',
             body: 'Test body')
    end

    let!(:valid_address) do
      FactoryBot.create(:address, email: 'customer@example.com', placeholder: false)
    end

    let!(:placeholder_address) do
      FactoryBot.create(:address, email: 'placeholder@example.com', placeholder: true)
    end

    let!(:no_email_address) do
      FactoryBot.create(:address, email: nil)
    end

    context 'with eligible orders' do
      let!(:processed_order) do
        FactoryBot.create(:ticket_order, :for_a_pair_of_tickets,
               performance: performance,
               address: valid_address,
               status: 'Processed')
      end

      let!(:hold_order) do
        FactoryBot.create(:ticket_order, :for_a_pair_of_tickets,
               performance: performance,
               address: FactoryBot.create(:address, email: 'hold@example.com', placeholder: false),
               status: 'Hold')
      end

      let!(:processing_order) do
        FactoryBot.create(:ticket_order, :for_a_pair_of_tickets,
               performance: performance,
               address: FactoryBot.create(:address, email: 'processing@example.com', placeholder: false),
               status: 'Processing')
      end

      let!(:fulfilled_order) do
        FactoryBot.create(:ticket_order, :for_a_pair_of_tickets,
               performance: performance,
               address: FactoryBot.create(:address, email: 'fulfilled@example.com', placeholder: false),
               status: 'Fulfilled')
      end

      it 'includes orders with eligible statuses' do
        recipients = broadcast.recipient_orders
        expect(recipients).to include(processed_order, hold_order, processing_order, fulfilled_order)
        expect(recipients.count).to eq(4)
      end
    end

    context 'with ineligible orders' do
      let!(:canceled_order) do
        FactoryBot.create(:ticket_order, :for_a_pair_of_tickets,
               performance: performance,
               address: valid_address,
               status: 'Canceled')
      end

      let!(:placeholder_order) do
        FactoryBot.create(:ticket_order, :for_a_pair_of_tickets,
               performance: performance,
               address: placeholder_address,
               status: 'Processed')
      end

      let!(:no_email_order) do
        FactoryBot.create(:ticket_order, :for_a_pair_of_tickets,
               performance: performance,
               address: no_email_address,
               status: 'Processed')
      end

      let!(:different_performance_order) do
        other_performance = FactoryBot.create(:performance,
                                              production: production,
                                              performance_date: Date.tomorrow,
                                              performance_time: Time.parse('20:00'))
        FactoryBot.create(:ticket_order, :for_a_pair_of_tickets,
               performance: other_performance,
               address: valid_address,
               status: 'Processed')
      end

      it 'excludes canceled orders' do
        expect(broadcast.recipient_orders).not_to include(canceled_order)
      end

      it 'excludes placeholder addresses' do
        expect(broadcast.recipient_orders).not_to include(placeholder_order)
      end

      it 'excludes orders without email addresses' do
        expect(broadcast.recipient_orders).not_to include(no_email_order)
      end

      it 'excludes orders from different performances' do
        expect(broadcast.recipient_orders).not_to include(different_performance_order)
      end
    end

    context 'with duplicate addresses' do
      let!(:order1) do
        FactoryBot.create(:ticket_order, :for_a_pair_of_tickets,
               performance: performance,
               address: valid_address,
               status: 'Processed')
      end

      let!(:order2) do
        FactoryBot.create(:ticket_order, :for_a_pair_of_tickets,
               performance: performance,
               address: valid_address,
               status: 'Processed')
      end

      it 'returns distinct orders' do
        recipients = broadcast.recipient_orders
        expect(recipients.count).to eq(2)
      end
    end
  end

  describe '#queue_broadcast!' do
    let(:broadcast) do
      FactoryBot.create(:performance_broadcast,
             performance: performance,
             user: user,
             subject: 'Test Subject',
             from_address: 'test@example.com',
             body: 'Test body')
    end

    let!(:order1) do
      FactoryBot.create(:ticket_order, :for_a_pair_of_tickets,
             performance: performance,
             address: FactoryBot.create(:address, email: 'customer1@example.com', placeholder: false),
             status: 'Processed')
    end

    let!(:order2) do
      FactoryBot.create(:ticket_order, :for_a_pair_of_tickets,
             performance: performance,
             address: FactoryBot.create(:address, email: 'customer2@example.com', placeholder: false),
             status: 'Fulfilled')
    end

    before do
      allow(Time).to receive(:current).and_return(Time.parse('2026-02-16 10:00:00'))
      allow(Time).to receive(:now).and_return(Time.parse('2026-02-16 10:00:00'))
    end

    it 'updates recipient_count' do
      expect {
        broadcast.queue_broadcast!
      }.to change { broadcast.reload.recipient_count }.from(nil).to(2)
    end

    it 'updates sent_at timestamp' do
      expect {
        broadcast.queue_broadcast!
      }.to change { broadcast.reload.sent_at }.from(nil).to(Time.parse('2026-02-16 10:00:00'))
    end

    it 'creates OutreachTask for each recipient order' do
      expect {
        broadcast.queue_broadcast!
      }.to change { OutreachTask.count }.by(2)
    end

    it 'creates OutreachTasks with correct attributes' do
      broadcast.queue_broadcast!

      tasks = OutreachTask.where(method_symbol: 'custom_performance_broadcast')
                         .where(order_id: [order1.id, order2.id])

      expect(tasks.count).to eq(2)

      tasks.each do |task|
        expect(task.method_symbol).to eq('custom_performance_broadcast')
        expect(task.execute_at).to be_present
        expect(task.status).to eq('Untried')
      end
    end

    it 'sets execute_at to current time' do
      broadcast.queue_broadcast!

      task = OutreachTask.where(method_symbol: 'custom_performance_broadcast').first
      expect(task.execute_at).to eq(Time.parse('2026-02-16 10:00:00'))
    end

    context 'with no eligible recipients' do
      before do
        order1.update!(status: 'Canceled')
        order2.update!(status: 'Canceled')
      end

      it 'sets recipient_count to zero' do
        broadcast.queue_broadcast!
        expect(broadcast.reload.recipient_count).to eq(0)
      end

      it 'does not create any OutreachTasks' do
        expect {
          broadcast.queue_broadcast!
        }.not_to change { OutreachTask.count }
      end
    end

    context 'log generation' do
      it 'generates and sends log to the broadcast requester' do
        expect(NotificationMailer).to receive(:broadcast_log_generated).once.and_call_original

        broadcast.queue_broadcast!
      end

      it 'creates a FileStore record for the log' do
        expect {
          broadcast.queue_broadcast!
        }.to change { FileStore.count }.by(1)
      end

      it 'sends email to the requester' do
        mailer_double = double('mailer')
        allow(mailer_double).to receive(:deliver_now)

        expect(NotificationMailer).to receive(:broadcast_log_generated).with(anything, user.email).and_return(mailer_double)

        broadcast.queue_broadcast!
      end

      it 'logs the email sent' do
        allow(Rails.logger).to receive(:info).and_call_original
        expect(Rails.logger).to receive(:info).with(/Broadcast log sent to #{user.email}/).and_call_original

        broadcast.queue_broadcast!
      end

      it 'handles email delivery errors gracefully' do
        allow(NotificationMailer).to receive(:broadcast_log_generated).and_raise(StandardError.new('SMTP error'))

        expect {
          broadcast.queue_broadcast!
        }.not_to raise_error
      end

      it 'logs email delivery errors' do
        allow(NotificationMailer).to receive(:broadcast_log_generated).and_raise(StandardError.new('SMTP error'))

        expect(Rails.logger).to receive(:error).with(/Failed to send broadcast log/)

        broadcast.queue_broadcast!
      end

      it 'skips sending if user has no email' do
        broadcast.user.update_columns(email: '')

        expect(NotificationMailer).not_to receive(:broadcast_log_generated)

        broadcast.queue_broadcast!
      end
    end
  end

  describe '#generate_and_send_log' do
    let(:broadcast) do
      FactoryBot.create(:performance_broadcast,
        performance: performance,
        user: user,
        subject: 'Test Subject',
        from_address: 'test@example.com',
        body: 'Test body')
    end

    it 'creates a PerformanceBroadcastReport' do
      expect(PerformanceBroadcastReport).to receive(:new).with(broadcast).and_call_original

      broadcast.generate_and_send_log
    end

    it 'creates a FileStore record' do
      expect {
        broadcast.generate_and_send_log
      }.to change { FileStore.count }.by(1)
    end

    it 'sends email to the broadcast requester' do
      mailer_double = double('mailer')
      allow(mailer_double).to receive(:deliver_now)

      expect(NotificationMailer).to receive(:broadcast_log_generated).once.with(anything, user.email).and_return(mailer_double)

      broadcast.generate_and_send_log
    end

    it 'skips sending if user has no email address' do
      broadcast.user.update_columns(email: '')

      expect(NotificationMailer).not_to receive(:broadcast_log_generated)

      broadcast.generate_and_send_log
    end

    it 'handles email delivery errors gracefully' do
      allow(NotificationMailer).to receive(:broadcast_log_generated).and_raise(StandardError.new('SMTP error'))

      expect {
        broadcast.generate_and_send_log
      }.not_to raise_error
    end
  end
end
