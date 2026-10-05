require 'rails_helper'

RSpec.describe 'admin/analysis/index', type: :view do
  let(:theater)    { FactoryBot.create(:theater) }
  let(:production) { FactoryBot.create(:production, theater: theater) }

  before { allow(view).to receive(:can?).and_return(true) }

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

  it 'shows Production Sales as the active tab and links to Pass Sales' do
    render
    expect(rendered).to have_css('#analysis-tabs li.tabs-title.is-active', text: 'Production Sales')
    expect(rendered).to have_link('Pass Sales', href: memberships_admin_analysis_index_path)
  end

  it 'hides the Pass Sales tab from users who may not analyze passes' do
    allow(view).to receive(:can?).with(:analyze_passes, Analysis).and_return(false)
    render
    expect(rendered).to have_css('#analysis-tabs li.tabs-title', text: 'Production Sales')
    expect(rendered).not_to have_link('Pass Sales')
  end
end
