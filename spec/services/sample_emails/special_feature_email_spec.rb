require 'rails_helper'
require Rails.root.join('spec/support/shared_examples/sample_email')

RSpec.describe SampleEmails::SpecialFeatureEmail, type: :service do
  include_context 'a sample email service'

  let!(:default_theater) { FactoryBot.create(:theater, theater_class: Theater::DEFAULT) }
  # The form being edited is the saved feature's own, so the draft shares its short name.
  let!(:feature) { SpecialFeature.create!(short_name: 'Relaxed', description: 'Saved description') }
  let(:sample) do
    described_class.new(user: user, params: params_for(
      special_feature: { short_name: 'Relaxed', description: 'Draft description',
                         email_description: 'Draft **email** description' }
    ))
  end

  it_behaves_like 'a sample email'

  it "shows the form's unsaved email description, not the saved description" do
    sample.deliver!

    expect(last_mail_body).to include('Draft <strong>email</strong> description')
    expect(last_mail_body).not_to include('Saved description')
  end
end
