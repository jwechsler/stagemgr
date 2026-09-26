require 'rails_helper'

RSpec.describe 'ticket_orders/_special_features', type: :view do
  let(:performance) { FactoryBot.create(:performance) }

  before do
    performance.special_features << SpecialFeature.create!(short_name: 'Talkback', status: SpecialFeature::ACTIVE,
                                                           description: 'Stay for the post-show talkback.')
    performance.special_features << SpecialFeature.create!(short_name: 'Retired', status: SpecialFeature::INACTIVE,
                                                           description: 'This retired feature must not show.')
    performance.update!(special_feature_display_markdown: 'Opening night party.')
  end

  it 'shows active features and the custom text, but not inactive features' do
    render partial: 'ticket_orders/special_features', locals: { performance: performance.reload }

    expect(rendered).to include('Stay for the post-show talkback.', 'Opening night party.')
    expect(rendered).not_to include('This retired feature must not show.')
  end
end
