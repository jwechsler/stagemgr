require 'rails_helper'

RSpec.describe 'admin/analysis/index', type: :view do
  let(:theater)    { FactoryBot.create(:theater) }
  let(:production) { FactoryBot.create(:production, theater: theater) }

  it 'renders the pickers with no selections' do
    render
    expect(rendered).to include('data-production-picker')
    expect(rendered).to include('target_production_id')
    expect(rendered).to include('comparison_production_id')
    expect(rendered).to include('comparison-production-search')
  end

  it 'renders preselected target and comparison productions' do
    assign(:target_production, production)
    assign(:comparison_production, production)
    assign(:comparison_productions, [production])
    render
    expect(rendered).to include(production.picker_label)
    expect(rendered).to have_css("input[name='target_production_id'][value='#{production.id}']",
                                 visible: false)
    expect(rendered).to have_css("input[name='comparison_production_id'][value='#{production.id}']",
                                 visible: false)
  end
end
