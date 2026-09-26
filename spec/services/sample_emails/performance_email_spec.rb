require 'rails_helper'
require Rails.root.join('spec/support/shared_examples/sample_email')

RSpec.describe SampleEmails::PerformanceEmail, type: :service do
  include_context 'a sample email service'

  let(:production) { FactoryBot.create(:production) }
  let!(:feature) { SpecialFeature.create!(short_name: 'ASL', description: 'ASL interpreted performance') }
  let(:sample) do
    described_class.new(user: user, params: params_for(
      production_id: production.id.to_s,
      performance: { special_feature_email_markdown: 'Draft **custom email**',
                     special_feature_ids: ['', feature.id.to_s] }
    ))
  end

  it_behaves_like 'a sample email'

  it 'is offered to box office staff for a real production only' do
    box_office = FactoryBot.create(:user, is_box_office_user: true)

    expect(described_class.authorized?(box_office.ability, { production_id: production.id })).to be(true)
    expect(described_class.authorized?(box_office.ability, {})).to be(false)
    expect(described_class.authorized?(box_office.ability, { production_id: 0 })).to be(false)
  end

  it "shows the form's unsaved custom email text and chosen features" do
    sample.deliver!

    expect(last_mail_body).to include('Draft <strong>custom email</strong>')
    expect(last_mail_body).to include('ASL interpreted performance')
  end
end
