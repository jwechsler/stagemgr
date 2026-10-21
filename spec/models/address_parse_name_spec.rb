require 'rails_helper'

RSpec.describe Address, type: :model do
  describe '.parse_name' do
    it 'parses a plain name' do
      expect(described_class.parse_name('Jane Smith')).to eq(['Jane Smith', 'Jane', '', 'Smith'])
    end

    it 'parses an accented name' do
      expect(described_class.parse_name('José García')).to eq(['José García', 'José', '', 'García'])
    end

    context 'with emoji in the name (previously a total Namae parse failure)' do
      it 'parses despite a trailing emoji' do
        expect(described_class.parse_name('Zoë Dvořák 🎟️')).to eq(['Zoë Dvořák 🎟️', 'Zoë', '', 'Dvořák'])
      end

      it 'parses despite a leading emoji' do
        expect(described_class.parse_name('🎭 Jane Smith')).to eq(['🎭 Jane Smith', 'Jane', '', 'Smith'])
      end

      it 'parses despite an emoji between tokens' do
        expect(described_class.parse_name('Jane 🎉 Smith')).to eq(['Jane 🎉 Smith', 'Jane', '', 'Smith'])
      end

      it 'parses despite an emoji glued to a name token' do
        expect(described_class.parse_name('Jane Smith🎉')).to eq(['Jane Smith🎉', 'Jane', '', 'Smith'])
      end

      it 'returns blanks for an emoji-only name' do
        expect(described_class.parse_name('🎭🎉')).to eq(['', '', '', ''])
      end
    end

    context 'when Namae fails to parse (naive-split fallback)' do
      it 'splits a name with a parenthesized nickname' do
        expect(described_class.parse_name('Kathleen (Kate) Early'))
          .to eq(['Kathleen (Kate) Early', 'Kathleen (Kate)', '', 'Early'])
      end

      it 'splits surnames that collide with Namae title vocabulary' do
        expect(described_class.parse_name('Paula Cantor')).to eq(['Paula Cantor', 'Paula', '', 'Cantor'])
        expect(described_class.parse_name('Brian Pastor')).to eq(['Brian Pastor', 'Brian', '', 'Pastor'])
        expect(described_class.parse_name('Bruce Elder')).to eq(['Bruce Elder', 'Bruce', '', 'Elder'])
      end

      it 'splits an organization name on its last token' do
        expect(described_class.parse_name('Presbyterian Home - Westminster Place'))
          .to eq(['Presbyterian Home - Westminster Place', 'Presbyterian Home - Westminster', '', 'Place'])
      end
    end

    context 'with a trailing middle initial' do
      {
        'Alicia M Senior-Saywell' => %w[Alicia M Senior-Saywell],
        'Alicia M. Senior-Saywell' => ['Alicia', 'M.', 'Senior-Saywell'],
        'DIANA M SENIOR' => %w[DIANA M SENIOR],
        'Dr. Robert E. Lee Jr.' => ['Robert', 'E.', 'Lee'],
        'Mary Ann Jones' => ['Mary Ann', '', 'Jones'],
        'John and Joyce Penniston' => ['John and Joyce', '', 'Penniston'],
        'John & Joyce Penniston' => ['John and Joyce', '', 'Penniston'],
        'J. R. R. Tolkien' => ['J. R. R.', '', 'Tolkien'],
        'Kathleen (Kate) Early' => ['Kathleen (Kate)', '', 'Early'],
        'Kathleen (Kate) Q Early' => ['Kathleen (Kate)', 'Q', 'Early']
      }.each do |full_name, (first, middle, last)|
        it "parses #{full_name.inspect} as first #{first.inspect}, middle #{middle.inspect}, last #{last.inspect}" do
          expect(described_class.parse_name(full_name)).to eq([full_name, first, middle, last])
        end
      end
    end

    it 'returns blanks for blank input' do
      expect(described_class.parse_name(nil)).to eq(['', '', '', ''])
      expect(described_class.parse_name('')).to eq(['', '', '', ''])
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

    it 'derives middle_name from a trailing initial' do
      address = described_class.create!(full_name: 'Alicia M Senior-Saywell')

      expect([address.first_name, address.middle_name, address.last_name]).to eq(%w[Alicia M Senior-Saywell])
    end

    # Forces a stored middle_name past the callbacks, as an import or LGL would.
    def with_stored_middle(full_name, middle_name)
      address = described_class.create!(full_name: full_name)
      address.update_columns(middle_name: middle_name)
      address.reload
    end

    it 'splits a stored middle name out of first_name' do
      address = with_stored_middle('Peter Smith', 'Marston')

      address.update!(full_name: 'Peter Marston Smith')

      expect([address.first_name, address.middle_name, address.last_name]).to eq(%w[Peter Marston Smith])
    end

    it 'keeps a stored middle name the full_name no longer contains' do
      address = with_stored_middle('Jeremy M Smith', 'M')

      address.update!(full_name: 'Jeremy Smith')

      expect([address.first_name, address.middle_name, address.last_name]).to eq(%w[Jeremy M Smith])
    end

    it 'replaces a stored middle name with a newly parsed initial' do
      address = with_stored_middle('Alicia M Senior-Saywell', 'M')

      address.update!(full_name: 'Alicia Q Senior-Saywell')

      expect([address.first_name, address.middle_name, address.last_name]).to eq(%w[Alicia Q Senior-Saywell])
    end

    it 'leaves a multi-word first name whole when no middle name is stored' do
      address = described_class.create!(full_name: 'Mary Ann Jones')

      expect([address.first_name, address.middle_name, address.last_name]).to eq(['Mary Ann', '', 'Jones'])
    end
  end

  describe '#parse_full_name' do
    it 'keeps a middle initial on the first name for billing' do
      expect(described_class.new(full_name: 'Alicia M Senior-Saywell').parse_full_name)
        .to eq(['Alicia M', 'Senior-Saywell'])
    end
  end
end
