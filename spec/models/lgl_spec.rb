# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lgl do
  after do
    described_class.read_write!
    described_class.disable
  end

  describe '.disable' do
    it 'is not enabled and writes nothing' do
      described_class.configure('key').disable

      expect(described_class).not_to be_enabled
      expect(described_class.writable?(5)).to be(false)
    end

    it 'refuses to hand out a client' do
      described_class.disable

      expect { described_class.client }.to raise_error(Lgl::Error, /not configured/)
    end
  end

  describe '.configure' do
    it 'treats a blank key as not configured' do
      described_class.configure('  ')

      expect(described_class).not_to be_enabled
    end

    it 'memoises the client' do
      described_class.configure('key')

      expect(described_class.client).to be_a(Lgl::Client).and equal(described_class.client)
    end
  end

  describe '.read_only!' do
    before { described_class.configure('key') }

    it 'blocks writes for every address when no allowlist is given' do
      described_class.read_only!

      expect(described_class).to be_read_only
      expect(described_class.writable?(5)).to be(false)
    end

    it 'allows addresses listed in a comma-separated string' do
      described_class.read_only!(except_address_ids: ' 5, 12 ,,')

      expect(described_class.writable?(5)).to be(true)
      expect(described_class.writable?('12')).to be(true)
      expect(described_class.writable?(6)).to be(false)
    end

    it 'accepts an array of ids' do
      described_class.read_only!(except_address_ids: [7, '8'])

      expect(described_class.writable_address_ids).to eq(Set[7, 8])
    end

    it 'never allows writes while disabled, even for an allowlisted address' do
      described_class.read_only!(except_address_ids: '5')
      described_class.disable

      expect(described_class.writable?(5)).to be(false)
    end
  end

  describe '.read_write!' do
    it 'allows writes for any address once configured' do
      described_class.configure('key').read_only!
      described_class.read_write!

      expect(described_class).not_to be_read_only
      expect(described_class.writable?(99)).to be(true)
    end
  end
end
