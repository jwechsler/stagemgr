# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LglDonorLevelsFetch do
  let(:report_url) { 'https://lgl.example/reports/secret-token.csv' }
  let(:csv) { "External constituent ID,TG Tier Last Fiscal,TG Tier This Fiscal\n12,Gold,Silver\n" }
  let(:supervisor_email) { Rails.configuration.x.email_address['supervisor_notifications'] }

  def settings_with(url)
    Lgl::Settings.from({ 'littlegreenlight' => { 'donor_tier_report_url' => url } }, env: {})
  end

  before do
    allow(Lgl).to receive(:settings).and_return(settings_with(report_url))
    allow(Lgl::DonorLevelsDownload).to receive(:fetch).and_return(csv)
    allow(Resque).to receive(:enqueue)
  end

  it 'returns nil without downloading or storing anything when the report link is not set' do
    allow(Lgl).to receive(:settings).and_return(settings_with(nil))

    expect(described_class.perform).to be_nil
    expect(Lgl::DonorLevelsDownload).not_to have_received(:fetch)
    expect(FileStore.count).to eq(0)
    expect(Resque).not_to have_received(:enqueue)
  end

  it 'runs while the API sync is disabled' do
    FactoryBot.create(:user, email: supervisor_email)
    allow(Lgl).to receive(:enabled?).and_return(false)

    expect(described_class.perform).to be_a(Integer)
  end

  it 'raises without downloading when no user has the supervisor notifications email' do
    expect { described_class.perform }.to raise_error(Lgl::Error, /supervisor_notifications/)
    expect(Lgl::DonorLevelsDownload).not_to have_received(:fetch)
    expect(FileStore.count).to eq(0)
  end

  context 'with the supervisor user' do
    let!(:supervisor) { FactoryBot.create(:user, email: supervisor_email) }

    it 'stores the report as a donor levels import owned by the supervisor and queues the import' do
      filestore_id = described_class.perform

      filestore = FileStore.find(filestore_id)
      expect(Lgl::DonorLevelsDownload).to have_received(:fetch).with(report_url)
      expect(filestore.user).to eq(supervisor)
      expect(filestore.worker).to eq(FileStore::IMPORT)
      expect(filestore.format).to eq(FileStore::DONATION_LEVELS_IMPORT_FORMAT)
      expect(filestore.notes).to eq('Donor levels from LGL (scheduled)')
      expect(filestore.file_name).to eq("lgl_donor_levels_#{Date.current.iso8601}.csv")
      expect(filestore.datafile.download).to eq(csv)
      expect(Resque).to have_received(:enqueue).with(LglDonorImport, filestore_id)
    end

    it 'stores nothing and lets the download error propagate' do
      allow(Lgl::DonorLevelsDownload).to receive(:fetch)
        .and_raise(Lgl::Error.new('Donor levels report from lgl.example (HTTP 401): unexpected response', status: 401))

      expect { described_class.perform }.to raise_error(Lgl::Error, /HTTP 401/)
      expect(FileStore.count).to eq(0)
      expect(Resque).not_to have_received(:enqueue)
    end

    it 'never logs the report link' do
      allow(Rails.logger).to receive(:info).and_call_original

      described_class.perform

      expect(Rails.logger).not_to have_received(:info).with(a_string_including('secret-token'))
    end
  end
end
