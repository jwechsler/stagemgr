# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NameMatch do
  describe '.first_name_key' do
    it 'keeps the first word, downcased, without trailing punctuation' do
      expect(described_class.first_name_key('Alden L.')).to eq('alden')
      expect(described_class.first_name_key('B.')).to eq('b')
      expect(described_class.first_name_key('  ROBERT  ')).to eq('robert')
      expect(described_class.first_name_key('Glen,')).to eq('glen')
    end

    it 'is nil for a blank name' do
      expect(described_class.first_name_key(nil)).to be_nil
      expect(described_class.first_name_key('  ')).to be_nil
      expect(described_class.first_name_key('.')).to be_nil
    end
  end

  describe '.same_first_name?' do
    it 'compares the first words ignoring case and punctuation' do
      expect(described_class.same_first_name?('Robert', 'robert L.')).to be(true)
      expect(described_class.same_first_name?('Charles', 'Gayle')).to be(false)
    end

    it 'is false when either name is blank' do
      expect(described_class.same_first_name?('', '')).to be(false)
      expect(described_class.same_first_name?('Pat', nil)).to be(false)
    end
  end

  describe '.narrow' do
    let(:names) { ['Charles', 'Gayle', 'charles A.'] }

    it 'keeps the items sharing the first name' do
      expect(described_class.narrow('Charles', names, &:itself)).to eq(['Charles', 'charles A.'])
      expect(described_class.narrow('Chuck', names, &:itself)).to eq([])
    end

    it 'does not narrow when the subject first name is blank' do
      expect(described_class.narrow(' ', names, &:itself)).to be_nil
      expect(described_class.narrow(nil, names, &:itself)).to be_nil
    end

    it 'excludes items with a blank first name' do
      expect(described_class.narrow('Charles', ['Charles', nil, ' '], &:itself)).to eq(['Charles'])
    end
  end
end
