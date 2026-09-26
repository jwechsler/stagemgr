require 'rails_helper'
require Rails.root.join('spec/support/shared_examples/sample_email')

RSpec.describe SampleEmails::ProductionConfirmationEmail, type: :service do
  include_context 'a sample email service'

  let(:production) { FactoryBot.create(:production, confirmation_message: 'Saved confirmation text') }
  let(:sample) do
    described_class.new(user: user, params: params_for(production_id: production.id.to_s,
                                                       production: { confirmation_message: 'Draft **confirmation** text' }))
  end

  it_behaves_like 'a sample email'

  it 'shows the unsaved confirmation message from the form, not the saved one' do
    sample.deliver!

    expect(last_mail_body).to include('Draft <strong>confirmation</strong> text')
    expect(last_mail_body).not_to include('Saved confirmation text')
  end

  it "is offered to box office staff but not to the production's theater users" do
    box_office = FactoryBot.create(:user, is_box_office_user: true)
    theater_user = FactoryBot.create(:user, theaters: [production.theater])
    context = { production_id: production.id }

    expect(described_class.authorized?(box_office.ability, context)).to be(true)
    expect(described_class.authorized?(theater_user.ability, context)).to be(false)
  end

  it 'is not offered for a production that does not exist' do
    expect(described_class.authorized?(user.ability, { production_id: 0 })).to be(false)
  end
end
