require 'rails_helper'
require 'csv'

RSpec.describe NotificationMailer, type: :mailer do
  describe '#broadcast_log_generated' do
    let(:theater) { FactoryBot.create(:theater) }
    let(:production) { FactoryBot.create(:production, theater: theater) }
    let(:performance) do
      perf = FactoryBot.create(:performance, production: production)
      # Update performance_code to match the production's code prefix
      perf.update!(performance_code: "#{production.production_code}-TEST-123")
      perf
    end
    let(:user) { FactoryBot.create(:user) }
    let(:broadcast) do
      FactoryBot.create(:performance_broadcast,
        performance: performance,
        user: user,
        subject: 'Important Update',
        from_address: 'test@example.com',
        body: 'Test body')
    end

    let(:file_store) do
      store = FileStore.new
      store.user = user
      store.worker = FileStore::REPORT
      store.notes = "Broadcast log: #{performance.performance_code} - \"#{broadcast.subject}\""

      # Create a temporary CSV file
      csv_content = CSV.generate do |csv|
        csv << ['Last Name', 'First Name', 'Phone', 'Email', 'Performance Code', 'Status']
        csv << ['Smith', 'John', '555-0001', 'john@example.com', 'TEST-123', 'Email Queued']
        csv << ['Doe', 'Jane', '555-0002', 'jane@example.com', 'TEST-123', '']
      end

      temp_file = Tempfile.new(['broadcast-log', '.csv'])
      temp_file.write(csv_content)
      temp_file.rewind

      store.datafile.attach(
        io: temp_file,
        filename: 'broadcast-log-test.csv',
        content_type: 'text/csv'
      )

      store.save!
      temp_file.close
      temp_file.unlink

      store
    end

    let(:recipient_email) { 'boxoffice@example.com' }

    it 'sends email to the recipient' do
      mail = NotificationMailer.broadcast_log_generated(file_store, recipient_email)

      expect(mail.to).to eq([recipient_email])
    end

    it 'uses correct from address' do
      mail = NotificationMailer.broadcast_log_generated(file_store, recipient_email)

      expect(mail.from).to eq([$EMAIL_ADDRESS['software_address']])
    end

    it 'has correct subject' do
      mail = NotificationMailer.broadcast_log_generated(file_store, recipient_email)

      expect(mail.subject).to eq('Broadcast Email Log Ready')
    end

    it 'includes file name in body' do
      mail = NotificationMailer.broadcast_log_generated(file_store, recipient_email)

      expect(mail.body.encoded).to include('broadcast-log-test.csv')
    end

    it 'includes notes in body' do
      mail = NotificationMailer.broadcast_log_generated(file_store, recipient_email)

      expect(mail.body.encoded).to include(performance.performance_code)
      expect(mail.body.encoded).to include('Important Update')
    end

    it 'attaches CSV file' do
      mail = NotificationMailer.broadcast_log_generated(file_store, recipient_email)

      expect(mail.attachments.size).to eq(1)
      expect(mail.attachments.first.filename).to eq('broadcast-log-test.csv')
      expect(mail.attachments.first.content_type).to include('text/csv')
    end

    it 'includes explanation text in body' do
      mail = NotificationMailer.broadcast_log_generated(file_store, recipient_email)

      expect(mail.body.encoded).to include('all orders for the performance')
      expect(mail.body.encoded).to include('which recipients were sent')
    end

    context 'when datafile is not attached' do
      let(:file_store_without_file) do
        store = FileStore.new
        store.user = user
        store.worker = FileStore::REPORT
        store.notes = "Broadcast log without file"
        store.save!
        store
      end

      it 'does not send email when file is not attached' do
        mail = NotificationMailer.broadcast_log_generated(file_store_without_file, recipient_email)

        # The mailer wraps the nil result in a NullMail object
        expect(mail.message).to be_a(ActionMailer::Base::NullMail)
      end
    end
  end
end
