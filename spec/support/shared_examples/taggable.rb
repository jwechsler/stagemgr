# Shared examples for tag models backing the Taggable concern.
# Callers must provide via let:
#   taggable       - a persisted instance of the taggable model
#   other_taggable - a second, distinct persisted instance
#   tag_class      - the tag model class under test
RSpec.shared_examples 'a taggable model' do
  it 'requires a tag name' do
    tag = taggable.tags.build(name: '')
    expect(tag).not_to be_valid
  end

  it 'strips whitespace from tag names' do
    tag = taggable.tags.create!(name: '  Storefront  ')
    expect(tag.name).to eq('Storefront')
  end

  it 'rejects a blank-after-trim name' do
    tag = taggable.tags.build(name: '   ')
    expect(tag).not_to be_valid
  end

  it 'is unique per record, case-insensitive' do
    taggable.tags.create!(name: 'Wicker Park')
    dup = taggable.tags.build(name: 'wicker park')
    expect(dup).not_to be_valid
  end

  it 'allows the same tag name on different records' do
    other_taggable.tags.create!(name: 'Neighborhood')
    expect(taggable.tags.build(name: 'Neighborhood')).to be_valid
  end

  it 'destroys tags when the record is destroyed' do
    taggable.tags.create!(name: 'Storefront')
    expect { taggable.destroy }.to change(tag_class, :count).by(-1)
  end

  describe '.tagged_with' do
    it 'finds records by tag name, case-insensitively' do
      taggable.tags.create!(name: 'Storefront')
      other_taggable
      expect(taggable.class.tagged_with('storefront')).to contain_exactly(taggable)
    end
  end

  describe '#tag_names=' do
    it 'accepts a comma-separated string and creates tags, dedup case-insensitively' do
      taggable.update!(tag_names: 'Storefront, storefront, Wicker Park')
      names = taggable.reload.tags.pluck(:name).map(&:downcase).sort
      expect(names).to eq(['storefront', 'wicker park'])
    end

    it 'preserves casing of the first occurrence' do
      taggable.update!(tag_names: 'Storefront, storefront')
      expect(taggable.reload.tags.pluck(:name)).to eq(['Storefront'])
    end

    it 'accepts a Tagify-style array of hashes' do
      taggable.update!(tag_names: [{ 'value' => 'A' }, { 'value' => 'B' }])
      expect(taggable.reload.tags.pluck(:name).sort).to eq(%w[A B])
    end

    it 'removes tags no longer present and adds new ones' do
      taggable.update!(tag_names: 'A, B')
      a_id = taggable.tags.find_by(name: 'A').id
      b_id = taggable.tags.find_by(name: 'B').id

      taggable.update!(tag_names: 'B, C')
      taggable.reload

      expect(taggable.tags.pluck(:name).sort).to eq(%w[B C])
      expect(taggable.tags.find_by(name: 'B').id).to eq(b_id)
      expect(tag_class.where(id: a_id)).to be_empty
    end

    it 'blanking the value clears all tags' do
      taggable.update!(tag_names: 'A, B')
      taggable.update!(tag_names: '')
      expect(taggable.reload.tags).to be_empty
    end

    it 'ignores blank entries and trims whitespace' do
      taggable.update!(tag_names: '  Storefront ,  , , Edgewater  ')
      expect(taggable.reload.tags.pluck(:name).sort).to eq(%w[Edgewater Storefront])
    end
  end

  describe '#tag_names' do
    it 'returns sorted case-insensitive list of current tag names' do
      taggable.tags.create!(name: 'wicker park')
      taggable.tags.create!(name: 'Edgewater')
      expect(taggable.tag_names).to eq(['Edgewater', 'wicker park'])
    end
  end
end
