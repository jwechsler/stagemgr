require 'rails_helper'

# The import used to hardcode suppress_receipt = true, so imported flex passes
# could never send a purchase confirmation. The fourth perform argument makes
# that a per-import choice while keeping silence as the default.
RSpec.describe BulkFlexOrderImport do
  let(:user) { User.create!(email: 'importer@example.com', password: 'sekritsekrit') }
  let(:theater) { FactoryBot.create(:theater) }
  let!(:offer) { FactoryBot.create(:flex_pass_offer, theater: theater, name: 'Season Six Pack') }

  def filestore_for(csv)
    file_store = FileStore.new(user: user, worker: FileStore::IMPORT, notes: 'Flex Pass order import')
    file_store.datafile.attach(io: StringIO.new(csv), filename: 'flex_passes.csv', content_type: 'text/csv')
    file_store.save!
    file_store
  end

  def one_row_csv(email: 'patron@example.com')
    <<~CSV
      FlexPassOffer,FullName,EmailAddress
      #{offer.name},Casey Patron,#{email}
    CSV
  end

  def confirmation_task_count
    OrderTask.where(method_symbol: 'flexpass_confirmation').count
  end

  def run(*extra_args)
    payment_type = FactoryBot.create(:cash_payment_type)
    described_class.perform(filestore_for(one_row_csv).id, theater.id, payment_type.id.to_s, *extra_args)
  end

  it 'folds the imported patron into an existing matching address' do
    existing = FactoryBot.create(:address, full_name: 'Casey Patron', email: 'patron@example.com')

    expect { run }.not_to change(Address, :count)
    expect(FlexPassOrder.last.address_id).to eq(existing.id)
  end

  it 'creates the flex pass order' do
    expect { run }.to change(FlexPassOrder, :count).by(1)
    expect(FlexPassOrder.last).to be_processed
  end

  context 'when the send-confirmations argument is omitted' do
    it 'suppresses the confirmation, matching the historical behaviour' do
      expect { run }.not_to(change { confirmation_task_count })
      expect(FlexPassOrder.last.suppress_receipt).to be(true)
    end

    it 'accepts the three-argument call so jobs already queued in Redis still run' do
      expect { run }.not_to raise_error
    end
  end

  context 'when the checkbox is unchecked' do
    # check_box_tag has no hidden companion field, so an unchecked box sends
    # nothing at all and the param arrives as nil.
    it 'suppresses the confirmation for a nil param' do
      expect { run(nil) }.not_to(change { confirmation_task_count })
    end

    it 'suppresses the confirmation for a "0" param' do
      expect { run('0') }.not_to(change { confirmation_task_count })
      expect(FlexPassOrder.last.suppress_receipt).to be(true)
    end
  end

  context 'when the checkbox is checked' do
    it 'queues one confirmation per imported order' do
      expect { run('1') }.to change { confirmation_task_count }.by(1)
      expect(FlexPassOrder.last.suppress_receipt).to be(false)
    end

    it 'also accepts a real boolean' do
      expect { run(true) }.to change { confirmation_task_count }.by(1)
    end
  end
end
