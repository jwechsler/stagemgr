require 'rails_helper'

RSpec.describe LglDonorImport do
  let(:user) { User.create!(email: 'importer@example.com', password: 'sekritsekrit') }
  let(:header) { 'External constituent ID,First Name,TG Tier Last Fiscal,TG Tier This Fiscal' }

  def filestore_for(csv, filename: 'LGL donors.csv')
    file_store = FileStore.new(user: user, worker: FileStore::IMPORT, format: FileStore::DONATION_LEVELS_IMPORT_FORMAT,
                               notes: 'Donor levels import')
    file_store.datafile.attach(io: StringIO.new(csv), filename: filename, content_type: 'text/csv')
    file_store.save!
    file_store
  end

  def run(*rows, head: header, filename: 'LGL donors.csv')
    file_store = filestore_for(([head] + rows).join("\n") + "\n", filename: filename)
    described_class.perform(file_store.id)
    file_store.reload
  end

  def result_file
    FileStore.where(worker: FileStore::REPORT).order(:id).last
  end

  def result_rows
    CSV.parse(result_file.datafile.download, headers: true)
  end

  def tiers(address)
    address.reload.values_at(:donor_tier_for_last_fiscal_year, :donor_tier_for_current_fiscal_year)
  end

  it 'updates both tiers on the customer named by External constituent ID' do
    address = FactoryBot.create(:address)

    notes = run("#{address.id},Ann,Gold,Silver").notes

    expect(tiers(address)).to eq(%w[Gold Silver])
    expect(notes).to eq('Donor levels: 1 rows; updated 1, unchanged 0, cleared 0, no id 0, errors 0; ' \
                        'cleared 0 absent customers')
  end

  it 'finds headers whatever their case, spacing or byte-order mark' do
    address = FactoryBot.create(:address)

    run("#{address.id},Gold, Silver ", head: "﻿ external CONSTITUENT id ,tg tier last fiscal,TG TIER THIS FISCAL")

    expect(tiers(address)).to eq(%w[Gold Silver])
  end

  it 'fails on a missing column and clears nothing' do
    donor = FactoryBot.create(:address, donor_tier_for_current_fiscal_year: 'Gold')
    file_store = filestore_for("External constituent ID,TG Tier Last Fiscal\n1,Gold\n")

    expect { described_class.perform(file_store.id) }.to raise_error(ArgumentError, /TG Tier This Fiscal/)
    expect(file_store.reload.notes).to eq('Donor levels import failed: missing column TG Tier This Fiscal')
    expect(tiers(donor)).to eq([nil, 'Gold'])
  end

  it 'leaves an unchanged customer untouched' do
    address = FactoryBot.create(:address, donor_tier_for_last_fiscal_year: 'Gold',
                                          donor_tier_for_current_fiscal_year: 'Silver')
    address.update_columns(updated_at: 3.days.ago)
    stamp = address.reload.updated_at

    notes = run("#{address.id},Ann,Gold,Silver").notes

    expect(address.reload.updated_at).to eq(stamp)
    expect(notes).to include('unchanged 1')
  end

  it 'clears both tiers when the row has blank cells' do
    address = FactoryBot.create(:address, donor_tier_for_last_fiscal_year: 'Gold',
                                          donor_tier_for_current_fiscal_year: 'Silver')

    notes = run("#{address.id},Ann,,").notes

    expect(tiers(address)).to eq([nil, nil])
    expect(notes).to include('cleared 1,')
  end

  it 'clears customers missing from the file, tagged or not, and leaves the listed ones alone' do
    listed = FactoryBot.create(:address, donor_tier_for_current_fiscal_year: 'Gold')
    absent = FactoryBot.create(:address, donor_tier_for_last_fiscal_year: 'Bronze')
    tagged = FactoryBot.create(:address, donor_tier_for_current_fiscal_year: 'Silver')
    tagged.address_tags.create!(tag_label: AddressTag::LGL_ID, tag_value: '777', theater_id: tagged_theater.id)

    notes = run("#{listed.id},Ann,,Gold").notes

    expect(tiers(listed)).to eq([nil, 'Gold'])
    expect(tiers(absent)).to eq([nil, nil])
    expect(tiers(tagged)).to eq([nil, nil])
    expect(notes).to end_with('cleared 2 absent customers')
  end

  it 'lists only bad, unmatched and placeholder ids in the result file, headers intact' do
    placeholder = FactoryBot.create(:address, placeholder: true)

    notes = run(',Blank,Gold,', 'abc,Bad,Gold,', '999999999,Gone,Gold,', "#{placeholder.id},Ph,Gold,").notes

    expect(result_rows.headers).to eq(header.split(',') + ['Error'])
    expect(result_rows.map { |r| [r['First Name'], r['Error']] }).to eq(
      [['Bad', 'External constituent ID is not a number'],
       ['Gone', 'No customer with this External constituent ID'],
       ['Ph', 'No customer with this External constituent ID']]
    )
    expect(notes).to include('cleared 0, no id 1, errors 3;')
    expect(tiers(placeholder)).to eq([nil, nil])
  end

  it 'reports a row that fails to save and carries on' do
    broken = FactoryBot.create(:address)
    good = FactoryBot.create(:address)
    allow_any_instance_of(Address).to receive(:update!).and_wrap_original do |original, *args|
      raise ActiveRecord::RecordInvalid, original.receiver if original.receiver.id == broken.id

      original.call(*args)
    end

    notes = run("#{broken.id},Broken,Gold,", "#{good.id},Good,Gold,").notes

    expect(result_rows.first['Error']).to start_with('ActiveRecord::RecordInvalid')
    expect(tiers(good)).to eq(['Gold', nil])
    expect(notes).to include('updated 1', 'errors 1')
  end

  it 'never creates customers' do
    expect { run('999999999,Nobody,Gold,Gold', ',New,Gold,Gold') }.not_to(change(Address, :count))
  end

  it 'creates no result file when no row has an error' do
    address = FactoryBot.create(:address)

    expect { run("#{address.id},Ann,Gold,", ',Org,Gold,') }
      .not_to(change { FileStore.where(worker: FileStore::REPORT).count })
  end

  it 'names the result file after the upload' do
    run('999999999,Gone,Gold,', filename: 'LGL donors (Oct).csv')

    expect(result_file.file_name).to eq('donor_import_results_LGL_donors_Oct.csv')
    expect(result_rows['First Name']).to eq(['Gone'])
  end

  describe 'completion email' do
    def last_mail
      ActionMailer::Base.deliveries.last
    end

    it 'emails the uploader the headline counts and attaches the error rows' do
      address = FactoryBot.create(:address)

      expect { run("#{address.id},Ann,Gold,", '999999999,Gone,Gold,', ',Org,Gold,', filename: 'LGL donors.csv') }
        .to change { ActionMailer::Base.deliveries.size }.by(1)

      body = last_mail.body.encoded
      expect(last_mail.to).to eq([user.email])
      expect(last_mail.subject).to eq('Donor levels import complete')
      expect(body).to include('LGL donors.csv', 'Constituents in file: 3', 'Customer records updated: 1',
                              'Update errors: 1', 'Rows without an External constituent ID: 1')
      expect(last_mail.attachments.map(&:filename)).to eq(['donor_import_results_LGL_donors.csv'])
    end

    it 'still emails, with nothing attached, when no row has an error' do
      address = FactoryBot.create(:address)

      expect { run("#{address.id},Ann,Gold,", ',Org,Gold,') }.to change { ActionMailer::Base.deliveries.size }.by(1)

      expect(last_mail.attachments).to be_empty
      expect(last_mail.body.encoded).to include('No rows had errors', 'Update errors: 0')
    end

    it 'sends nothing and does not raise when the upload has no user' do
      address = FactoryBot.create(:address)
      file_store = filestore_for("#{header}\n#{address.id},Ann,Gold,\n")
      file_store.update_columns(user_id: nil)

      expect { described_class.perform(file_store.id) }.not_to(change { ActionMailer::Base.deliveries.size })
      expect(tiers(address)).to eq(['Gold', nil])
    end
  end

  context 'with LGL sync enabled' do
    before do
      Lgl.configure('secret-key')
      Lgl.read_write!
      allow(Resque).to receive(:enqueue)
      allow(Resque).to receive(:enqueue_in)
    end

    after { Lgl.disable }

    it 'queues no LGL sync for a tagged customer' do
      address = FactoryBot.create(:address, donor_tier_for_last_fiscal_year: 'Gold')
      address.address_tags.create!(tag_label: AddressTag::LGL_ID, tag_value: '555', theater_id: tagged_theater.id)

      run("#{address.id},Ann,,Platinum")

      expect(tiers(address)).to eq([nil, 'Platinum'])
      expect(Resque).not_to have_received(:enqueue).with(LglSyncAddressJob, any_args)
      expect(Resque).not_to have_received(:enqueue_in).with(anything, LglSyncAddressJob, any_args)
    end
  end

  def tagged_theater
    @tagged_theater ||= Theater.default_theater || FactoryBot.create(:theater)
  end
end
