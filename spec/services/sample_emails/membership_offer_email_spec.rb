require 'rails_helper'
require Rails.root.join('spec/support/shared_examples/sample_email')

RSpec.describe SampleEmails::MembershipOfferEmail, type: :service do
  include_context 'a sample email service'

  let(:sample) do
    described_class.new(user: user, params: params_for(
      membership_offer: { name: 'Draft Membership', email_html: 'Draft **welcome** text' }
    ))
  end

  it_behaves_like 'a sample email'

  it "shows the form's unsaved offer name and confirmation email text" do
    sample.deliver!

    mail = ActionMailer::Base.deliveries.last
    expect(mail.subject).to eq('Your Draft Membership')
    expect(last_mail_body).to include('Draft <strong>welcome</strong> text')
  end

  it 'never saves a membership, so no MyEmma list sync is enqueued' do
    allow(MyEmma).to receive(:disabled?).and_return(false)
    allow(Resque).to receive(:enqueue)

    sample.deliver!

    expect(Resque).not_to have_received(:enqueue).with(SyncMembershipMyEmmaJob, anything)
  end
end
