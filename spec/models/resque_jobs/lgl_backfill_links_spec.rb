# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LglBackfillLinks do
  let!(:house) { Theater.default_theater || FactoryBot.create(:theater, theater_class: Theater::DEFAULT) }
  let(:client) { instance_double(Lgl::Client) }
  let(:untagged) { FactoryBot.create(:address) }
  let(:tagged) { FactoryBot.create(:address) }
  let(:conflicting) { FactoryBot.create(:address) }
  let(:repointable) { FactoryBot.create(:address) }

  before do
    allow(Lgl).to receive(:enabled?).and_return(true)
    allow(Lgl).to receive(:client).and_return(client)
    allow(Resque).to receive(:enqueue)
    tagged.set_lgl_id!(2)
    conflicting.set_lgl_id!(99)
    repointable.set_lgl_id!(6)
    constituents = [
      { 'id' => 1, 'external_constituent_id' => untagged.id.to_s },
      { 'id' => 2, 'external_constituent_id' => tagged.id.to_s },
      { 'id' => 3, 'external_constituent_id' => '3' },
      { 'id' => 4, 'external_constituent_id' => '999999999' },
      { 'id' => 5, 'external_constituent_id' => '' },
      { 'id' => 6, 'external_constituent_id' => '999999998' },
      { 'id' => 7, 'external_constituent_id' => conflicting.id.to_s }
    ]
    allow(client).to receive(:each_constituent) { |&block| constituents.each(&block) }
  end

  it 'writes local tags and reviews only, and counts each outcome' do
    counts = described_class.perform

    expect(counts).to eq(tagged: 1, already_tagged: 1, self_referencing: 1, dead_external_id: 2,
                         blank_external_id: 1, review: 1)
    expect(untagged.lgl_id).to eq('1')
    expect(conflicting.lgl_review_reason).to eq('Also LGL constituent 7')
  end

  it 'makes no LGL writes and enqueues nothing' do
    expect(client).not_to receive(:create)
    expect(client).not_to receive(:update)

    described_class.perform

    expect(Resque).not_to have_received(:enqueue)
    expect(repointable.lgl_id).to eq('6')
  end

  it 'does nothing when LGL is disabled: no LGL call, no tags' do
    allow(Lgl).to receive(:enabled?).and_return(false)

    expect { expect(described_class.perform).to eq({}) }.not_to change(AddressTag, :count)

    expect(Lgl).not_to have_received(:client)
  end
end
