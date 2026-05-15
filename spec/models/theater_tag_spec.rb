require 'rails_helper'

RSpec.describe TheaterTag, type: :model do
  let(:theater) { FactoryBot.create(:theater) }

  it "requires a name" do
    tag = TheaterTag.new(theater: theater, name: '')
    expect(tag).not_to be_valid
  end

  it "strips whitespace from name" do
    tag = TheaterTag.create!(theater: theater, name: '  Storefront  ')
    expect(tag.name).to eq('Storefront')
  end

  it "rejects a blank-after-trim name" do
    tag = TheaterTag.new(theater: theater, name: '   ')
    expect(tag).not_to be_valid
  end

  it "is unique per theater, case-insensitive" do
    TheaterTag.create!(theater: theater, name: 'Wicker Park')
    dup = TheaterTag.new(theater: theater, name: 'wicker park')
    expect(dup).not_to be_valid
  end

  it "allows the same tag name on different theaters" do
    other = FactoryBot.create(:theater, name: 'Other House')
    TheaterTag.create!(theater: theater, name: 'Neighborhood')
    expect(TheaterTag.new(theater: other, name: 'Neighborhood')).to be_valid
  end

  it "is destroyed when its theater is destroyed" do
    TheaterTag.create!(theater: theater, name: 'Storefront')
    expect { theater.destroy }.to change(TheaterTag, :count).by(-1)
  end

  describe "Theater#tag_names=" do
    it "accepts a comma-separated string and creates tags, dedup case-insensitively" do
      theater.update!(tag_names: 'Storefront, storefront, Wicker Park')
      names = theater.reload.theater_tags.pluck(:name).map(&:downcase).sort
      expect(names).to eq(['storefront', 'wicker park'])
    end

    it "preserves casing of the first occurrence" do
      theater.update!(tag_names: 'Storefront, storefront')
      expect(theater.reload.theater_tags.pluck(:name)).to eq(['Storefront'])
    end

    it "accepts a Tagify-style array of hashes" do
      theater.update!(tag_names: [{ 'value' => 'A' }, { 'value' => 'B' }])
      expect(theater.reload.theater_tags.pluck(:name).sort).to eq(['A', 'B'])
    end

    it "removes tags no longer present and adds new ones" do
      theater.update!(tag_names: 'A, B')
      a_id = theater.theater_tags.find_by(name: 'A').id
      b_id = theater.theater_tags.find_by(name: 'B').id

      theater.update!(tag_names: 'B, C')
      theater.reload

      expect(theater.theater_tags.pluck(:name).sort).to eq(['B', 'C'])
      expect(theater.theater_tags.find_by(name: 'B').id).to eq(b_id)
      expect(TheaterTag.where(id: a_id)).to be_empty
    end

    it "blanking the value clears all tags" do
      theater.update!(tag_names: 'A, B')
      theater.update!(tag_names: '')
      expect(theater.reload.theater_tags).to be_empty
    end

    it "ignores blank entries and trims whitespace" do
      theater.update!(tag_names: '  Storefront ,  , , Edgewater  ')
      expect(theater.reload.theater_tags.pluck(:name).sort).to eq(['Edgewater', 'Storefront'])
    end
  end

  describe "Theater#tag_names" do
    it "returns sorted case-insensitive list of current tag names" do
      theater.theater_tags.create!(name: 'wicker park')
      theater.theater_tags.create!(name: 'Edgewater')
      expect(theater.tag_names).to eq(['Edgewater', 'wicker park'])
    end
  end
end
