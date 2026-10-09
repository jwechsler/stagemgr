require 'rails_helper'

# The donation section of the ticket checkout shows each theater's editable
# appeal above an "Add a donation: $" box. A resident, visiting or guest
# company's order adds the default theater's secondary appeal; a co-production's
# order shows only the co-producer's own appeal.
RSpec.describe 'orders/_additional_donation', type: :view do
  let!(:default_theater) do
    FactoryBot.create(:theater, name: 'Default House', theater_class: Theater::DEFAULT, accepts_donations: true,
                                donation_appeal: 'Give to **{{theater}}**.',
                                secondary_donation_appeal: '{{theater}} supports {{company}}.')
  end

  def render_for(theater)
    order = TicketOrder.new(performance: Performance.new(production: Production.new(theater: theater)))
    builder = SimpleForm::FormBuilder.new(:ticket_order, order, view, {})
    render partial: 'orders/additional_donation', locals: { order_form: builder }
    Capybara.string(rendered)
  end

  def legends(page)
    page.all('legend').map { |legend| legend.text.squish }
  end

  it "shows the default theater's appeal and the amount box on its own order" do
    page = render_for(default_theater)

    expect(legends(page)).to eq(['I wish to offer additional support'])
    expect(page).to have_text('Give to Default House.')
    expect(page).to have_css('label[for="ticket_order_additional_donation"]', text: '$')
    expect(page).to have_field('ticket_order_additional_donation')
  end

  it 'renders the appeal as markdown' do
    page = render_for(default_theater)

    expect(page).to have_css('strong', text: 'Default House')
  end

  context "on a visiting company's order" do
    let(:company) do
      FactoryBot.create(:theater, name: 'Visiting Troupe', theater_class: Theater::VISITING, accepts_donations: true,
                                  donation_appeal: 'Love {{theater}}.')
    end

    it "shows the company's appeal and the default theater's secondary appeal naming the company" do
      page = render_for(company)

      expect(legends(page)).to eq(['Donate to Visiting Troupe', 'Make a donation to Default House'])
      expect(page).to have_text('Love Visiting Troupe.')
      expect(page).to have_text('Default House supports Visiting Troupe.')
      expect(page).to have_field('ticket_order_additional_donation_for_other')
      expect(page).to have_field('ticket_order_additional_donation')
    end
  end

  context "on a co-production's order" do
    let(:copro) do
      FactoryBot.create(:theater, name: 'Partner Company', theater_class: Theater::COPRO, accepts_donations: true)
    end

    it "shows only the co-producer's default appeal, never the secondary appeal" do
      page = render_for(copro)

      expect(legends(page)).to eq(['Make a donation to Partner Company'])
      expect(page).to have_text('Yes! I love Partner Company. Please add a tax-deductible contribution to this order.')
      expect(page).not_to have_text('supports')
      expect(page).not_to have_field('ticket_order_additional_donation_for_other')
    end
  end
end
