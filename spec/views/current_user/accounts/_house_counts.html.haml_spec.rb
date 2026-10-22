require 'rails_helper'

# The Upcoming House Counts table on the account page carries an Expected column
# read from each house count's nightly pace snapshot.
RSpec.describe 'current_user/accounts/_house_counts', type: :view do
  let(:as_of) { Date.new(2026, 10, 6) }

  def house_count(code, external: false, **attrs)
    production = FactoryBot.build_stubbed(:production, sales_recorded_externally: external)
    performance = FactoryBot.build_stubbed(:performance, production: production, performance_code: code,
                                                         performance_date: as_of + 7)
    HouseCount.new(performance: performance, total_seats: 100, sold_seats: 20, available_seats: 78,
                   pace_share: 0.5, pace_sold: 20, pace_source: 'theater', pace_as_of: as_of, **attrs)
  end

  def row_for(code)
    Capybara.string(rendered).find('tbody tr', text: code)
  end

  before do
    render partial: 'current_user/accounts/house_counts', locals: {
      house_counts: [
        house_count('PROJ01', projected_seats: 84),
        house_count('COMP01', projected_seats: 80, comp_seats: 4),
        house_count('EARLY01', projected_seats: nil, pace_share: 0.05),
        house_count('EXT01', external: true, projected_seats: 84)
      ]
    }
  end

  it 'adds an Expected header after % booked' do
    headers = Capybara.string(rendered).all('thead th').map(&:text)

    expect(headers.last(2)).to eq(['% booked', 'Expected'])
  end

  it 'shows the expected share of the house with its basis and seats on hover' do
    expect(row_for('PROJ01')).to have_css(
      'td span[title="Sold 20 as of Oct 6; this house typically has 50% in hand 7 days out; ' \
      'expected ~ 84 of 100 seats"]',
      exact_text: "~\u00A084%"
    )
  end

  it 'adds the comps already issued to Expected, split out on hover' do
    expect(row_for('COMP01')).to have_css(
      'td span[title="Sold 20 as of Oct 6; this house typically has 50% in hand 7 days out; ' \
      'expected ~ 84 of 100 seats (80 paid + 4 comps)"]',
      exact_text: "~\u00A084%"
    )
  end

  it 'says too early, with its basis on hover, when the share in hand is too small to project' do
    expect(row_for('EARLY01')).to have_css(
      'td span[title="Sold 20 as of Oct 6; this house typically has 5% in hand 7 days out"]',
      exact_text: 'Too early'
    )
  end

  it 'shows a titled dash for a production whose sales are recorded externally' do
    expect(row_for('EXT01')).to have_css('td span[title="Sales recorded externally"]', exact_text: '—')
  end
end
