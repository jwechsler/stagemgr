require 'rails_helper'
require Rails.root.join('spec/support/shared_examples/sample_email')

RSpec.describe SampleEmails::TicketClassEmail, type: :service do
  include_context 'a sample email service'

  let(:production) { FactoryBot.create(:production) }
  let(:sample) do
    described_class.new(user: user, params: params_for(
      production_id: production.id.to_s,
      ticket_class: { class_name: 'Captioned Seat', admission: 'in_person',
                      purchase_email_annotation: 'Draft **annotation**' }
    ))
  end

  it_behaves_like 'a sample email'

  it "shows the form's unsaved purchase email annotation" do
    sample.deliver!

    expect(last_mail_body).to include('Draft <strong>annotation</strong>')
  end

  it 'is offered to staff who may edit ticket classes, not to theater users' do
    theater_user = FactoryBot.create(:user, theaters: [production.theater])
    context = { production_id: production.id }

    expect(described_class.authorized?(user.ability, context)).to be(true)
    expect(described_class.authorized?(theater_user.ability, context)).to be(false)
  end

  it 'is denied for a missing or unknown production' do
    expect(described_class.authorized?(user.ability, {})).to be(false)
    expect(described_class.authorized?(user.ability, { production_id: 0 })).to be(false)
  end
end
