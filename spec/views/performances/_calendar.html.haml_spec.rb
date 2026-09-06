require 'rails_helper'

# The membership call-to-action above the month grid. It used to be a hardcoded
# link to a page on the marketing site; it now points at the public membership
# index, and it only appears when there is something there to buy.
RSpec.describe 'performances/_calendar.html.haml', type: :view do
  let(:production) { FactoryBot.create(:production) }

  # The month-grid branch of the partial needs more than one visible performance.
  def render_calendar
    2.times { |n| FactoryBot.create(:performance, production: production, performance_date: Date.current + n.days) }
    assign(:production, production.reload)
    assign(:performances, production.performances)
    assign(:start_date, Date.current.beginning_of_month)
    assign(:end_date, Date.current.end_of_month)
    assign(:footnotes, [])
    render partial: 'performances/calendar'
    rendered
  end

  it 'invites patrons to join when a membership is on sale to the public' do
    FactoryBot.create(:membership_offer)

    output = render_calendar

    expect(output).to include("Become a member and see everything at #{Theater.default_theater.name}")
    expect(output).to include(membership_offers_path)
  end

  it 'says nothing about membership when none is on sale' do
    FactoryBot.create(:membership_offer, on_sale: false)
    FactoryBot.create(:membership_offer, :timed, name: 'Library Pass')

    output = render_calendar

    expect(output).not_to include('Become a member')
    expect(output).not_to include(membership_offers_path)
  end

  it 'prints the box office phone from the theater facts' do
    output = render_calendar

    expect(output).to include("Call the box office at #{TheaterInfo.new.phone}")
  end

  it 'drops the box office row entirely for a house with no phone configured' do
    allow(view).to receive(:theater_info).and_return(TheaterInfo.new(server_config: {}, email_addresses: {}))

    output = render_calendar

    expect(output).not_to include('Call the box office')
    expect(output).not_to include('boxoffice-message')
  end
end
