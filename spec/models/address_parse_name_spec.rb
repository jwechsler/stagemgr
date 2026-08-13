require 'rails_helper'

RSpec.describe Address, type: :model do
  describe '.parse_name' do
    it 'parses a plain name' do
      expect(described_class.parse_name('Jane Smith')).to eq(['Jane Smith', 'Jane', 'Smith'])
    end

    it 'parses an accented name' do
      expect(described_class.parse_name('José García')).to eq(['José García', 'José', 'García'])
    end

    context 'with emoji in the name (previously a total Namae parse failure)' do
      it 'parses despite a trailing emoji' do
        expect(described_class.parse_name('Zoë Dvořák 🎟️')).to eq(['Zoë Dvořák 🎟️', 'Zoë', 'Dvořák'])
      end

      it 'parses despite a leading emoji' do
        expect(described_class.parse_name('🎭 Jane Smith')).to eq(['🎭 Jane Smith', 'Jane', 'Smith'])
      end

      it 'parses despite an emoji between tokens' do
        expect(described_class.parse_name('Jane 🎉 Smith')).to eq(['Jane 🎉 Smith', 'Jane', 'Smith'])
      end

      it 'parses despite an emoji glued to a name token' do
        expect(described_class.parse_name('Jane Smith🎉')).to eq(['Jane Smith🎉', 'Jane', 'Smith'])
      end

      it 'returns blanks for an emoji-only name' do
        expect(described_class.parse_name('🎭🎉')).to eq(['', '', ''])
      end
    end

    context 'when Namae fails to parse (naive-split fallback)' do
      it 'splits a name with a parenthesized nickname' do
        expect(described_class.parse_name('Kathleen (Kate) Early'))
          .to eq(['Kathleen (Kate) Early', 'Kathleen (Kate)', 'Early'])
      end

      it 'splits surnames that collide with Namae title vocabulary' do
        expect(described_class.parse_name('Paula Cantor')).to eq(['Paula Cantor', 'Paula', 'Cantor'])
        expect(described_class.parse_name('Brian Pastor')).to eq(['Brian Pastor', 'Brian', 'Pastor'])
        expect(described_class.parse_name('Bruce Elder')).to eq(['Bruce Elder', 'Bruce', 'Elder'])
      end

      it 'splits an organization name on its last token' do
        expect(described_class.parse_name('Presbyterian Home - Westminster Place'))
          .to eq(['Presbyterian Home - Westminster Place', 'Presbyterian Home - Westminster', 'Place'])
      end
    end

    it 'returns blanks for blank input' do
      expect(described_class.parse_name(nil)).to eq(['', '', ''])
      expect(described_class.parse_name('')).to eq(['', '', ''])
    end
  end

  describe '#regularize! via save' do
    it 'derives first and last name from an emoji-laden full_name' do
      address = described_class.create!(full_name: 'Zoë Dvořák 🎟️')

      expect(address.first_name).to eq('Zoë')
      expect(address.last_name).to eq('Dvořák')
      expect(address.full_name).to eq('Zoë Dvořák 🎟️') # stored name untouched
    end

    it 'derives names for a parenthesized nickname instead of leaving them blank' do
      address = described_class.create!(full_name: 'Rachelle (Rocky) Koleke')

      expect(address.first_name).to eq('Rachelle (Rocky)')
      expect(address.last_name).to eq('Koleke')
    end
  end
end
