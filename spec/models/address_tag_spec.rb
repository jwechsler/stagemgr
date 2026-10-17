# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AddressTag do
  let!(:house) { Theater.default_theater || FactoryBot.create(:theater, theater_class: Theater::DEFAULT) }
  let(:other_theater) { FactoryBot.create(:theater, theater_class: Theater::RESIDENT) }
  let(:address) { FactoryBot.create(:address) }

  def tag(label, theater)
    address.address_tags.create!(tag_label: label, tag_value: '42', theater: theater)
  end

  describe '.lgl' do
    it "includes only the default theater's tags with that label" do
      wanted = tag(described_class::LGL_ID, house)
      tag(described_class::LGL_ID, other_theater)
      tag(described_class::LGL_REVIEW, house)

      expect(described_class.lgl(described_class::LGL_ID)).to contain_exactly(wanted)
    end

    it 'is empty when there is no default theater' do
      tag(described_class::LGL_ID, house)
      allow(Theater).to receive(:default_theater).and_return(nil)

      expect(described_class.lgl(described_class::LGL_ID)).to be_empty
    end
  end

  describe '.lgl_theater_id!' do
    it 'answers the default theater id' do
      expect(described_class.lgl_theater_id!).to eq(house.id)
    end

    it 'raises RecordNotFound when there is no default theater' do
      allow(Theater).to receive(:default_theater).and_return(nil)

      expect { described_class.lgl_theater_id! }
        .to raise_error(ActiveRecord::RecordNotFound, 'LGL tags need a default theater')
    end
  end
end
