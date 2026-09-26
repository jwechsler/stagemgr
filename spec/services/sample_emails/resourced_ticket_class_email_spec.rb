require 'rails_helper'
require Rails.root.join('spec/support/shared_examples/sample_email')

RSpec.describe SampleEmails::ResourcedTicketClassEmail, type: :service do
  include_context 'a sample email service'

  let!(:default_theater) { FactoryBot.create(:theater, theater_class: Theater::DEFAULT) }
  let(:sample) do
    described_class.new(user: user, params: params_for(
      resourced_ticket_class: { class_name: 'Captioning Tablet', admission: 'other',
                                purchase_email_annotation: 'Draft tablet pickup note' }
    ))
  end

  it_behaves_like 'a sample email'

  it "shows the form's unsaved annotation" do
    sample.deliver!

    expect(last_mail_body).to include('Draft tablet pickup note')
  end

  it 'refuses a missing form' do
    bare = described_class.new(user: user, params: params_for({}))

    expect { bare.deliver! }.to raise_error(ActionController::ParameterMissing)
  end
end
