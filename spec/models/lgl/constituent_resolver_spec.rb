# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lgl::ConstituentResolver do
  let(:subject_address) { Struct.new(:id, :last_name, :search_name).new(100, 'Smith', 'smithjane') }
  let(:live) { {} }
  let(:lookup) { ->(id) { live[id] } }

  def other_address(id, search_name)
    live[id] = Struct.new(:id, :search_name).new(id, search_name)
  end

  def constituent(id, external_id, last_name = 'Smith')
    { 'id' => id, 'external_constituent_id' => external_id, 'last_name' => last_name }
  end

  def decide(*constituents)
    described_class.decide(subject_address, constituents, address_lookup: lookup)
  end

  it 'creates when LGL has no constituent with the email' do
    expect(decide.action).to eq(:create)
  end

  describe 'junk external ids are adoptable' do
    it 'adopts a blank external id' do
      c = constituent(7, '')
      expect(decide(c)).to have_attributes(action: :adopt, constituent: c)
    end

    it 'adopts a nil external id' do
      expect(decide(constituent(7, nil)).action).to eq(:adopt)
    end

    it 'adopts a non-numeric external id' do
      expect(decide(constituent(7, 'ABC-12')).action).to eq(:adopt)
    end

    it "adopts an external id equal to the constituent's own LGL id" do
      expect(decide(constituent(7, '7')).action).to eq(:adopt)
    end

    it 'adopts an external id naming an address that no longer exists' do
      expect(decide(constituent(7, '555')).action).to eq(:adopt)
    end
  end

  it 'matches the last name case-insensitively' do
    expect(decide(constituent(7, '', ' sMITH ')).action).to eq(:adopt)
  end

  it 'does not adopt a junk-id constituent with a different last name' do
    expect(decide(constituent(7, '', 'Jones')).action).to eq(:create)
  end

  it 'flags several adoptable constituents for review' do
    decision = decide(constituent(7, ''), constituent(8, 'x'))
    expect(decision).to have_attributes(action: :review, reason: '2 LGL constituents share this email')
  end

  it 'ignores a constituent linked to a live address when another is adoptable' do
    other_address(200, 'smithjane')
    c = constituent(8, '')
    expect(decide(constituent(7, '200'), c)).to have_attributes(action: :adopt, constituent: c)
  end

  it 'merges with a live address of the same search name that carries the constituent' do
    twin = other_address(200, 'smithjane')
    c = constituent(7, '200')
    decision = decide(c)
    expect(decision).to have_attributes(action: :merge, constituent: c, other_address: twin,
                                        reason: 'same person as address #200 per LGL constituent 7')
  end

  it 'creates for a household member: live address with a different search name' do
    other_address(200, 'smithjohn')
    expect(decide(constituent(7, '200')).action).to eq(:create)
  end
end
