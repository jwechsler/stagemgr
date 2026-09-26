require 'rails_helper'

RSpec.describe 'admin/performances/_special_features', type: :view do
  let(:performance) { FactoryBot.create(:performance) }

  def add_feature(short_name, status, description)
    performance.special_features << SpecialFeature.create!(short_name: short_name, status: status,
                                                           description: description)
  end

  def render_for(performance)
    render partial: 'admin/performances/special_features', locals: { performance: performance.reload }
  end

  it 'lists active features and hides inactive ones' do
    add_feature('Talkback', SpecialFeature::ACTIVE, 'Stay for the post-show talkback.')
    add_feature('Retired', SpecialFeature::INACTIVE, 'This retired feature must not show.')
    render_for(performance)

    expect(rendered).to include('Stay for the post-show talkback.')
    expect(rendered).not_to include('This retired feature must not show.')
  end

  it 'renders nothing when the only feature is inactive and there is no custom text' do
    add_feature('Retired', SpecialFeature::INACTIVE, 'This retired feature must not show.')
    render_for(performance)

    expect(rendered).not_to include('Special Features')
  end

  it 'shows a Custom Email override on its own' do
    performance.update!(special_feature_email_markdown: 'Talkback after the show.')
    render_for(performance)

    expect(rendered).to include('Email override for special features', 'Talkback after the show.')
  end
end
