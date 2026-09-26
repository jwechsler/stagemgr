# Shared by the SampleEmails::* service specs. A spec provides `sample` (the
# service, built with params_for(...)); `user` is the staff member it mails.
RSpec.shared_context 'a sample email service' do
  let(:user) { FactoryBot.create(:admin_user) }

  before do
    FactoryBot.create(:cash_payment_type)
    ActionMailer::Base.deliveries.clear
  end

  def params_for(hash)
    ActionController::Parameters.new(hash)
  end

  def last_mail_body
    mail = ActionMailer::Base.deliveries.last
    (mail.html_part || mail).body.decoded
  end
end

RSpec.shared_examples 'a sample email' do
  let(:sample_record_counts) do
    -> { [Order, Production, Performance, TicketClass, SpecialFeature, PerformanceBroadcast, Membership, Address].map(&:count) }
  end

  it 'sends one email, to the staff member' do
    sample # build the context records first

    expect { sample.deliver! }.to change { ActionMailer::Base.deliveries.count }.by(1)
    expect(ActionMailer::Base.deliveries.last.to).to eq([user.email])
  end

  it 'leaves no orders, productions, performances, features, broadcasts or memberships behind' do
    sample

    expect { sample.deliver! }.not_to(change { sample_record_counts.call })
  end
end
