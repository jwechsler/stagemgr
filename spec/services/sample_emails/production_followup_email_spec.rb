require 'rails_helper'
require Rails.root.join('spec/support/shared_examples/sample_email')

# The box office verifies a production's follow-up copy with a sample. The
# sample builds a throwaway production, so anything it fails to carry over is
# silently previewed at its house-wide default -- which is how a working survey
# override once looked broken.
RSpec.describe SampleEmails::ProductionFollowupEmail, type: :service do
  include_context 'a sample email service'

  let(:production) do
    FactoryBot.create(:production, survey_link: 'https://survey.test/custom',
                                   mailing_list_link: 'https://mailing.test/custom',
                                   follow_up_message_2: 'Saved follow-up text')
  end

  def sample_with(production_params, for_production: production)
    described_class.new(user: user, params: params_for(production_id: for_production.id.to_s,
                                                       production: production_params))
  end

  let(:sample) { sample_with({ follow_up_message_2: 'Draft follow-up text' }) }

  it_behaves_like 'a sample email'

  it 'shows the unsaved follow-up message from the form, not the saved one' do
    sample.deliver!

    expect(last_mail_body).to include('Draft follow-up text')
    expect(last_mail_body).not_to include('Saved follow-up text')
  end

  it "uses the production's saved survey and mailing list overrides when the form doesn't post them" do
    sample.deliver!

    expect(last_mail_body).to include('https://survey.test/custom')
    expect(last_mail_body).to include('https://mailing.test/custom')
    expect(last_mail_body).not_to include(Rails.configuration.x.server_config['survey_link'])
  end

  it 'previews unsaved survey and mailing list edits posted from the form' do
    sample_with({ survey_link: 'https://survey.test/unsaved', mailing_list_link: 'https://mailing.test/unsaved' }).deliver!

    expect(last_mail_body).to include('https://survey.test/unsaved')
    expect(last_mail_body).to include('https://mailing.test/unsaved')
  end

  it 'falls back to the house links when the production has no overrides' do
    bare = FactoryBot.create(:production, survey_link: nil, mailing_list_link: nil)
    sample_with({ survey_link: '', mailing_list_link: '' }, for_production: bare).deliver!

    expect(last_mail_body).to include(Rails.configuration.x.server_config['survey_link'])
  end
end
