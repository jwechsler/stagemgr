# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LglGiftHistoryWalk do
  let!(:house) { Theater.default_theater || FactoryBot.create(:theater, theater_class: Theater::DEFAULT) }
  let(:client) { instance_double(Lgl::Client) }
  let(:zero) { { set: 0, cleared: 0, unchanged: 0, gone: 0, error: 0 } }

  before do
    allow(Lgl).to receive(:enabled?).and_return(true)
    allow(Lgl).to receive(:client).and_return(client)
    allow(described_class).to receive(:sleep)
    allow(Lgl::GiftHistoryRefresh).to receive(:refresh).and_return(:unchanged)
  end

  def linked(lgl_id, **attrs)
    FactoryBot.create(:address, **attrs).tap { |address| address.set_lgl_id!(lgl_id) }
  end

  it 'does nothing when LGL is disabled' do
    allow(Lgl).to receive(:enabled?).and_return(false)
    linked(900_010)

    expect(described_class.perform).to be_nil

    expect(Lgl).not_to have_received(:client)
    expect(Lgl::GiftHistoryRefresh).not_to have_received(:refresh)
  end

  it 'refreshes every linked live address with the shared client and tallies the outcomes' do
    set = linked(900_010)
    cleared = linked(900_020)
    gone = linked(900_030)
    unchanged = linked(900_040)
    allow(Lgl::GiftHistoryRefresh).to receive(:refresh).with(set, client: client).and_return(:set)
    allow(Lgl::GiftHistoryRefresh).to receive(:refresh).with(cleared, client: client).and_return(:cleared)
    allow(Lgl::GiftHistoryRefresh).to receive(:refresh).with(gone, client: client).and_return(:gone)
    allow(Lgl::GiftHistoryRefresh).to receive(:refresh).with(unchanged, client: client).and_return(:unchanged)

    expect(described_class.perform).to eq(zero.merge(set: 1, cleared: 1, gone: 1, unchanged: 1))

    expect(described_class).to have_received(:sleep).with(described_class::STAGGER).exactly(3).times
  end

  it 'skips unlinked and placeholder addresses and tags of another theater' do
    FactoryBot.create(:address)
    linked(900_050, placeholder: true)
    other = FactoryBot.create(:address)
    other.address_tags.create!(tag_label: AddressTag::LGL_ID, tag_value: '900060',
                               theater: FactoryBot.create(:theater))

    expect(described_class.perform).to eq(zero)

    expect(Lgl::GiftHistoryRefresh).not_to have_received(:refresh)
  end

  it 'counts an LGL error on one address and carries on with the next' do
    failing = linked(900_010)
    linked(900_020)
    allow(Lgl::GiftHistoryRefresh).to receive(:refresh).with(failing, client: client)
                                                       .and_raise(Lgl::Error, 'LGL 500')

    expect(described_class.perform).to eq(zero.merge(error: 1, unchanged: 1))
  end

  it 'aborts after MAX_ERRORS consecutive LGL errors' do
    stub_const("#{described_class}::MAX_ERRORS", 2)
    3.times { |i| linked(900_010 + i) }
    allow(Lgl::GiftHistoryRefresh).to receive(:refresh).and_raise(Lgl::Error, 'LGL is down')

    expect(described_class.perform).to eq(zero.merge(error: 2))

    expect(Lgl::GiftHistoryRefresh).to have_received(:refresh).twice
  end

  it 'resets the consecutive error count after a success' do
    stub_const("#{described_class}::MAX_ERRORS", 2)
    addresses = Array.new(4) { |i| linked(900_010 + i) }
    outcomes = { addresses[0] => :error, addresses[1] => :unchanged, addresses[2] => :error, addresses[3] => :set }
    allow(Lgl::GiftHistoryRefresh).to receive(:refresh) do |address, **|
      raise Lgl::Error, 'LGL 500' if outcomes.fetch(address) == :error

      outcomes.fetch(address)
    end

    expect(described_class.perform).to eq(zero.merge(error: 2, unchanged: 1, set: 1))
  end
end
