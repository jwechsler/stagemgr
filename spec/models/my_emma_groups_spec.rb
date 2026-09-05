require 'rails_helper'

# The three states a group key can be in are the whole point of this object, and
# the difference between them is patron-visible: an absent key must keep the
# behaviour an install had before the key existed, while a blank one must switch
# the group off.
RSpec.describe MyEmmaGroups do
  let(:newsletter) { double(id: 11) }

  before do
    allow(MyEmma::Group).to receive(:find_by_group_name).and_return(nil)
    allow(MyEmma::Group).to receive(:find_by_group_name).with('Newsletter').and_return(newsletter)
  end

  def stub_my_emma_section(section)
    allow(Rails.configuration.x.server_config).to receive(:[]).and_call_original
    allow(Rails.configuration.x.server_config).to receive(:[]).with('my_emma').and_return(section)
  end

  describe '.name_for' do
    it 'uses the configured name' do
      stub_my_emma_section('newsletter_group' => 'House News')

      expect(described_class.name_for(described_class::NEWSLETTER)).to eq('House News')
    end

    it 'falls back to the historical name when the key is absent' do
      stub_my_emma_section('coupon_group' => 'Deals')

      expect(described_class.name_for(described_class::NEWSLETTER)).to eq('Newsletter')
    end

    it 'falls back for both keys when the whole section is absent' do
      stub_my_emma_section(nil)

      expect(described_class.name_for(described_class::NEWSLETTER)).to eq('Newsletter')
      expect(described_class.name_for(described_class::COUPON)).to eq('Flash Offers')
    end

    it 'treats an explicitly blank name as "switch this group off"' do
      stub_my_emma_section('newsletter_group' => '')

      expect(described_class.name_for(described_class::NEWSLETTER)).to be_nil
    end
  end

  describe '.id_for' do
    it 'resolves the configured name to its MyEmma id' do
      stub_my_emma_section('newsletter_group' => 'Newsletter')

      expect(described_class.id_for(described_class::NEWSLETTER)).to eq(11)
    end

    it 'is nil, and looks nothing up, for a group switched off' do
      stub_my_emma_section('newsletter_group' => '')

      expect(MyEmma::Group).not_to receive(:find_by_group_name)
      expect(described_class.id_for(described_class::NEWSLETTER)).to be_nil
    end

    it 'warns and returns nil for a name that does not exist in the account' do
      stub_my_emma_section('newsletter_group' => 'No Such Group')
      expect(Rails.logger).to receive(:warn).with(/No Such Group/)

      expect(described_class.id_for(described_class::NEWSLETTER)).to be_nil
    end
  end
end
