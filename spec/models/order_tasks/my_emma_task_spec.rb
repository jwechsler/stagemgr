require 'rails_helper'

# The task that adds an opted-in patron to the house's MyEmma groups. The group
# NAMES are configuration (my_emma: newsletter_group: / coupon_group: in
# server.yml, resolved by MyEmmaGroups); the ids behind them are looked up by
# name at run time.
RSpec.describe MyEmmaTask, type: :model do
  let(:order) { FactoryBot.create(:donation_order) }
  let(:member) { double('MyEmma::Member').as_null_object }

  before do
    allow(MyEmma::Member).to receive(:new).and_return(member)
    allow(MyEmma::Group).to receive(:find_by_group_name) do |name|
      { 'Newsletter' => double(id: 11), 'Flash Offers' => double(id: 22) }[name]
    end
  end

  def run_task(**attrs)
    MyEmmaTask.new(order: order, execute_at: 1.minute.ago, **attrs).send(:execute!)
  end

  def stub_my_emma_section(section)
    allow(Rails.configuration.x.server_config).to receive(:[]).and_call_original
    allow(Rails.configuration.x.server_config).to receive(:[]).with('my_emma').and_return(section)
  end

  it 'subscribes the patron to both configured groups' do
    expect(member).to receive(:save).with([11, 22])

    run_task
  end

  # Regression: the ids used to be memoized in a class variable behind
  # `return if defined? @@newsletter_id`, which answered nil for every call
  # after the first -- so a worker process stopped subscribing anyone at all
  # after its first order.
  it 'still finds the groups on a second run in the same process' do
    expect(member).to receive(:save).with([11, 22]).twice

    run_task
    run_task
  end

  # An install whose server.yml predates the my_emma: keys must keep behaving
  # exactly as it did.
  it 'falls back to the historical group names when the keys are absent' do
    stub_my_emma_section({})

    expect(member).to receive(:save).with([11, 22])

    run_task
  end

  it 'skips a group whose name is explicitly blank in config' do
    stub_my_emma_section('newsletter_group' => '', 'coupon_group' => 'Flash Offers')

    expect(member).to receive(:save).with([22])

    run_task
  end

  it 'skips a configured group that does not exist in MyEmma yet' do
    stub_my_emma_section('newsletter_group' => 'Newsletter', 'coupon_group' => 'Not Created Yet')

    expect(member).to receive(:save).with([11])

    run_task
  end

  it 'adds the groups the caller asked for as well' do
    expect(member).to receive(:save).with([11, 22, 'GRP9'])

    run_task(additional_groups: ['GRP9'])
  end

  it 'does nothing for an order with no email address' do
    order.address.update!(email: '')

    expect(member).not_to receive(:save)

    run_task
  end
end
