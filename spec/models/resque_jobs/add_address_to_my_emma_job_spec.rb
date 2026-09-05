require 'rails_helper'

# Adds one address to the house's MyEmma newsletter. The group NAME is
# configuration (my_emma: newsletter_group: in server.yml, resolved by
# MyEmmaGroups); the id behind it is looked up by name at run time.
RSpec.describe AddAddressToMyEmmaJob do
  let(:address) { FactoryBot.create(:address, email: 'patron@example.com') }
  let(:member) { double('MyEmma::Member').as_null_object }

  before do
    allow(MyEmma::Member).to receive(:find_by_email).and_return(nil)
    allow(MyEmma::Member).to receive(:new).and_return(member)
    allow(MyEmma::Group).to receive(:find_by_group_name) do |name|
      { 'Newsletter' => double(id: 11) }[name]
    end
  end

  def stub_my_emma_section(section)
    allow(Rails.configuration.x.server_config).to receive(:[]).and_call_original
    allow(Rails.configuration.x.server_config).to receive(:[]).with('my_emma').and_return(section)
  end

  it 'subscribes the address to the configured newsletter group' do
    expect(member).to receive(:save).with([11])

    described_class.perform(address.id)
  end

  # Regression: the id used to be memoized in a class variable behind
  # `return if defined? @@newsletter_id`, which answered nil for every call
  # after the first -- so a worker process stopped subscribing anyone at all
  # after its first address.
  it 'still finds the group on a second run in the same process' do
    expect(member).to receive(:save).with([11]).twice

    described_class.perform(address.id)
    described_class.perform(address.id)
  end

  it 'falls back to the historical group name when the key is absent' do
    stub_my_emma_section({})

    expect(member).to receive(:save).with([11])

    described_class.perform(address.id)
  end

  it 'skips the group when its name is explicitly blank in config' do
    stub_my_emma_section('newsletter_group' => '')

    expect(member).to receive(:save).with([])

    described_class.perform(address.id)
  end

  it 'skips a configured group that does not exist in MyEmma yet' do
    stub_my_emma_section('newsletter_group' => 'Not Created Yet')

    expect(member).to receive(:save).with([])

    described_class.perform(address.id)
  end

  it "adds the production's attendee group alongside the newsletter" do
    production = FactoryBot.create(:production, myemma_attendee_group: 'GRP9')

    expect(member).to receive(:save).with([11, 'GRP9'])

    described_class.perform(address.id, production.id)
  end

  it 'does nothing for an address with no email' do
    address.update!(email: '')

    expect(member).not_to receive(:save)

    described_class.perform(address.id)
  end
end
