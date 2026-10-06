require 'rails_helper'

# The gift date hint tells the buyer how long the gift lasts: a one-time offer
# is paid once and does not renew; a recurring offer with a gift length renews
# for that many billing periods and then ends (StripeGateway#gift_cancel_at).
RSpec.describe 'orders/_gift_recipient', type: :view do
  def render_for(offer)
    builder = SimpleForm::FormBuilder.new(:membership_order, MembershipOrder.new, view, {})
    render partial: 'orders/gift_recipient', locals: { f: builder, offer: offer }
  end

  def offer_with(interval, gift_cycles, count = 1)
    FactoryBot.build(:membership_offer, billing_interval: interval, billing_interval_count: count,
                                        max_cycles_if_gift: gift_cycles)
  end

  it 'says a one-time gift lasts its term and does not renew' do
    render_for(offer_with(MembershipOffer::ONE_TIME, 6, nil))

    expect(rendered).to include('This gift membership lasts 6 months and does not renew.')
  end

  it 'says a yearly gift subscription renews for its years and then ends' do
    render_for(offer_with(MembershipOffer::YEAR, 2))

    expect(rendered).to include('This gift membership renews for 2 years and then ends.')
  end

  it 'says a monthly gift subscription renews for its months and then ends' do
    render_for(offer_with(MembershipOffer::MONTH, 12))

    expect(rendered).to include('This gift membership renews for 12 months and then ends.')
  end

  it 'gives no length for a recurring offer without a gift length' do
    render_for(offer_with(MembershipOffer::MONTH, nil))

    expect(rendered).not_to include('This gift membership')
  end
end

# A hidden copy of gift_date used to follow the visible field and, left blank
# by a picker that never started, overrode the buyer's date on submit.
RSpec.describe 'orders/_gift_recipient gift date field', type: :view do
  it 'renders one native date field for gift_date, with no hidden copy to override it' do
    builder = SimpleForm::FormBuilder.new(:membership_order, MembershipOrder.new, view, {})
    render partial: 'orders/gift_recipient', locals: { f: builder, offer: FactoryBot.build(:membership_offer) }

    fields = Capybara.string(rendered).all('input[name="membership_order[gift_date]"]', visible: :all)
    expect(fields.size).to eq(1)
    expect(fields.first[:type]).to eq('date')
  end
end
