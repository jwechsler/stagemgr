require 'rails_helper'
require Rails.root.join('lib/tasks/addresses/name_reparser')

RSpec.describe Addresses::NameReparser do
  # Creates a row through the model, then forces the legacy shape with
  # update_columns so no callback re-derives it.
  def legacy_address(full_name, **legacy_columns)
    address = FactoryBot.create(:address, full_name: full_name)
    address.update_columns(legacy_columns.merge(updated_at: 2.weeks.ago))
    address.reload
  end

  it 'splits a trailing initial out of first_name into middle_name' do
    address = legacy_address('Alicia M Senior-Saywell',
                             first_name: 'Alicia M', middle_name: nil,
                             last_first_name: 'SENIOR-SAYWELLALICIAM')

    summary = described_class.new.call

    address.reload
    expect(address.first_name).to eq('Alicia')
    expect(address.middle_name).to eq('M')
    expect(address.last_name).to eq('Senior-Saywell')
    expect(address.last_first_name).to eq('SENIOR-SAYWELLALICIAM')
    expect(summary.changed).to eq(1)
  end

  it 'recomputes last_first_name from the re-derived names' do
    address = legacy_address('Alicia M Senior-Saywell',
                             first_name: 'Alicia M', middle_name: nil, last_first_name: 'STALE')

    described_class.new.call

    expect(address.reload.last_first_name).to eq('SENIOR-SAYWELLALICIAM')
  end

  it 'blanks a legacy middle_name that full_name does not contain' do
    address = legacy_address('Jane Doe', first_name: 'Jane', middle_name: 'Quincy',
                                         last_first_name: 'DOEJANEQUINCY')

    described_class.new.call

    address.reload
    expect(address.middle_name).to be_blank
    expect(address.first_name).to eq('Jane')
    expect(address.last_first_name).to eq('DOEJANE')
  end

  it 'leaves an already-correct row untouched' do
    address = FactoryBot.create(:address, full_name: 'Alicia M Senior-Saywell')
    address.update_columns(updated_at: 2.weeks.ago)
    before = address.reload.attributes

    summary = described_class.new.call

    expect(address.reload.attributes).to eq(before)
    expect(summary).to have_attributes(scanned: 1, changed: 0, unchanged: 1)
  end

  it 'writes nothing in dry-run but reports the change' do
    address = legacy_address('Alicia M Senior-Saywell', first_name: 'Alicia M', middle_name: nil)
    before = address.attributes

    summary = described_class.new(dry_run: true).call

    expect(address.reload.attributes).to eq(before)
    expect(summary.changed).to eq(1)
    expect(summary.samples).to eq([%(##{address.id}: "Alicia M"/"" -> "Alicia"/"M")])
  end

  it 'does not touch updated_at or enqueue an LGL sync' do
    Theater.default_theater || FactoryBot.create(:theater, theater_class: Theater::DEFAULT)
    allow(Lgl).to receive(:enabled?).and_return(true)
    address = legacy_address('Alicia M Senior-Saywell', first_name: 'Alicia M', middle_name: nil)
    address.set_lgl_id!(42)
    stamped = address.reload.updated_at
    expect(Resque).not_to receive(:enqueue)
    expect(Resque).not_to receive(:enqueue_in)

    described_class.new.call

    expect(address.reload.updated_at).to eq(stamped)
  end
end
