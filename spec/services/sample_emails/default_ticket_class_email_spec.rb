require 'rails_helper'
require Rails.root.join('spec/support/shared_examples/sample_email')

RSpec.describe SampleEmails::DefaultTicketClassEmail, type: :service do
  include_context 'a sample email service'

  let!(:default_theater) { FactoryBot.create(:theater, theater_class: Theater::DEFAULT) }
  let(:sample) do
    described_class.new(user: user, params: params_for(
      default_ticket_class: { class_name: 'Student', purchase_email_annotation: 'Draft default annotation' }
    ))
  end

  it_behaves_like 'a sample email'

  it "shows the form's unsaved annotation on a sample production at the default theater" do
    sample.deliver!

    expect(last_mail_body).to include('Draft default annotation')
  end

  it 'needs no production to be offered' do
    expect(described_class.authorized?(user.ability, {})).to be(true)
  end

  it 'explains when there is no default theater to build the sample at' do
    allow(Theater).to receive(:default_theater).and_return(nil)

    expect { sample.deliver! }.to raise_error(SampleEmails::Error, /No default theater/)
  end
end
