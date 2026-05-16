require 'rails_helper'

RSpec.describe MailingList do
  describe ".client_patron_id_for" do
    let(:address) { instance_double(Address) }

    it "returns the external_id stripped of whitespace when one is set" do
      allow(address).to receive(:external_id).with([99]).and_return("TRG-99812")
      expect(described_class.client_patron_id_for(address, [99])).to eq("TRG-99812")
    end

    it "returns empty string when no external_id is registered" do
      allow(address).to receive(:external_id).with([99]).and_return("")
      expect(described_class.client_patron_id_for(address, [99])).to eq("")
    end

    it "trims whitespace-only external_id to empty string" do
      allow(address).to receive(:external_id).with([99]).and_return("   ")
      expect(described_class.client_patron_id_for(address, [99])).to eq("")
    end
  end

  describe ".mailing_hash_from_buyer" do
    let(:address) do
      instance_double(Address,
        id: 12345,
        first_name: 'A', last_name: 'B', full_name: 'A B',
        email: 'a@example.com', line1: '1 St', line2: nil,
        city: 'Chi', state: 'IL', zipcode: '60000', phone: '312'
      )
    end

    before do
      allow(address).to receive(:external_id).with([]).and_return("")
      allow(address).to receive(:external_id).with([7]).and_return("EXT-77")
    end

    it "blanks the email when allow_email_export is false" do
      hash = described_class.mailing_hash_from_buyer(address, false, [])
      expect(hash[:Email]).to eq('')
    end

    it "includes the email when allow_email_export is true" do
      hash = described_class.mailing_hash_from_buyer(address, true, [])
      expect(hash[:Email]).to eq('a@example.com')
    end

    it "always sets StagemgrPatronID to address.id" do
      hash = described_class.mailing_hash_from_buyer(address, true, [7])
      expect(hash[:StagemgrPatronID]).to eq(12345)
    end

    it "populates ClientPatronID from the per-theater external_id when one exists" do
      hash = described_class.mailing_hash_from_buyer(address, true, [7])
      expect(hash[:ClientPatronID]).to eq("EXT-77")
    end

    it "leaves ClientPatronID blank when no external_id is registered" do
      hash = described_class.mailing_hash_from_buyer(address, true, [])
      expect(hash[:ClientPatronID]).to eq("")
    end
  end
end
