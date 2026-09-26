require 'rails_helper'
require Rails.root.join('spec/support/shared_examples/sample_email')

RSpec.describe SampleEmails::BroadcastEmail, type: :service do
  include_context 'a sample email service'

  let(:production) { FactoryBot.create(:production) }
  # The email attendees modal posts its ids and fields at the top level.
  let(:sample) do
    described_class.new(user: user, params: params_for(
      production_id: production.id.to_s, performance_id: '', theater_id: production.theater_id.to_s,
      subject: 'Draft subject', from_address: 'boxoffice@example.com', body: 'Draft **broadcast** body'
    ))
  end

  it_behaves_like 'a sample email'

  it "sends the modal's unsaved subject and body" do
    sample.deliver!

    mail = ActionMailer::Base.deliveries.last
    expect(mail.subject).to eq('Draft subject')
    expect(last_mail_body).to include('Draft <strong>broadcast</strong> body')
  end

  describe 'authorization' do
    let(:box_office) { FactoryBot.create(:user, is_box_office_user: true) }
    let(:theater_user) { FactoryBot.create(:user, theaters: [production.theater]) }
    let(:performance) { FactoryBot.create(:performance, production: production) }
    let(:send_context) { { production_id: production.id, performance_id: performance.id } }

    it "offers the button for the page's production, before the modal picks a performance" do
      expect(described_class.visible?(box_office.ability, { production_id: production.id })).to be(true)
      expect(described_class.visible?(box_office.ability, { production_id: 0 })).to be(false)
      expect(described_class.visible?(theater_user.ability, { production_id: production.id })).to be(false)
    end

    it "allows a send for one of the production's performances" do
      expect(described_class.authorized?(box_office.ability, send_context)).to be(true)
    end

    it 'denies a send whose performance is missing or unknown' do
      expect(described_class.authorized?(box_office.ability, { production_id: production.id })).to be(false)
      expect(described_class.authorized?(box_office.ability, send_context.merge(performance_id: 0))).to be(false)
    end

    it "denies a performance from another production" do
      stranger = FactoryBot.create(:performance, production: FactoryBot.create(:production))

      expect(described_class.authorized?(box_office.ability, send_context.merge(performance_id: stranger.id)))
        .to be(false)
    end

    it 'denies theater users' do
      expect(described_class.authorized?(theater_user.ability, send_context)).to be(false)
    end
  end

  it 'queues nothing for real attendees' do
    sample

    expect { sample.deliver! }.not_to(change { OutreachTask.count })
  end

  it 'refuses a draft without a subject, saying why' do
    blank = described_class.new(user: user, params: params_for(production_id: production.id.to_s, body: 'x',
                                                               from_address: 'boxoffice@example.com'))

    expect { blank.deliver! }.to raise_error(ActiveRecord::RecordInvalid, /Subject can't be blank/)
  end
end
