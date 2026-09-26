require 'rails_helper'

RSpec.describe Admin::SampleEmailsController, type: :controller do
  let(:admin_user) { FactoryBot.create(:admin_user) }
  let(:production) { FactoryBot.create(:production, confirmation_message: 'Saved text') }
  let(:theater_user) { FactoryBot.create(:user, theaters: [production.theater]) }

  before do
    FactoryBot.create(:cash_payment_type)
    ActionMailer::Base.deliveries.clear
  end

  def send_sample(kind: 'production_confirmation', **body)
    post :create, params: { kind: kind, production_id: production.id,
                            production: { confirmation_message: 'Draft text' } }.merge(body)
  end

  describe 'as an administrator' do
    before { allow(controller).to receive(:current_user).and_return(admin_user) }

    it 'sends the sample to the signed-in user and says so' do
      expect { send_sample }.to change { ActionMailer::Base.deliveries.count }.by(1)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('success' => true,
                                         'message' => "Sample confirmation email sent to #{admin_user.email}")
      expect(ActionMailer::Base.deliveries.last.to).to eq([admin_user.email])
    end

    it 'accepts the edit form as posted, _method=patch included' do
      send_sample(_method: 'patch', authenticity_token: 'x')

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['success']).to be(true)
    end

    it 'denies a send whose production does not exist' do
      post :create, params: { kind: 'ticket_class', production_id: 0, ticket_class: { class_name: 'x' } }

      expect(response).to redirect_to(root_path)
    end

    def send_attendee_sample(performance_id)
      post :create, params: { kind: 'performance_broadcast', production_id: production.id,
                              performance_id: performance_id,
                              subject: 'S', from_address: 'boxoffice@example.com', body: 'B' }
    end

    it "sends an attendee sample for one of the production's performances" do
      performance = FactoryBot.create(:performance, production: production)

      expect { send_attendee_sample(performance.id) }.to change { ActionMailer::Base.deliveries.count }.by(1)
      expect(response.parsed_body['message']).to eq("Sample attendee email sent to #{admin_user.email}")
    end

    it 'denies an attendee sample for an unknown performance' do
      expect { send_attendee_sample(0) }.not_to(change { ActionMailer::Base.deliveries.count })

      expect(response).to redirect_to(root_path)
    end

    it "denies an attendee sample for another production's performance" do
      stranger = FactoryBot.create(:performance, production: FactoryBot.create(:production))

      expect { send_attendee_sample(stranger.id) }.not_to(change { ActionMailer::Base.deliveries.count })
      expect(response).to redirect_to(root_path)
    end

    it 'refuses a kind it does not know' do
      expect { send_sample(kind: 'destroy_everything') }.not_to(change { ActionMailer::Base.deliveries.count })

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq('success' => false, 'message' => 'Unknown kind of sample email.')
    end

    it 'says what is missing when the form was not posted' do
      post :create, params: { kind: 'membership_offer' }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['message']).to include('membership_offer')
    end

    it 'logs an unexpected failure and shows a friendly message instead' do
      allow(OrderMailer).to receive(:ticket_confirmation).and_raise(RuntimeError, 'SMTP secret detail')
      allow(Rails.logger).to receive(:error)

      send_sample

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['message']).to eq('Could not send the sample email. The error has been logged.')
      expect(Rails.logger).to have_received(:error).with(/SMTP secret detail/)
    end
  end

  describe 'as a theater user' do
    before { allow(controller).to receive(:current_user).and_return(theater_user) }

    it 'is not allowed, and sends nothing' do
      expect { send_sample }.not_to(change { ActionMailer::Base.deliveries.count })

      expect(response).to redirect_to(root_path)
    end
  end

  describe 'routing' do
    it 'routes a POST to create' do
      expect(post: '/admin/sample_emails').to route_to(controller: 'admin/sample_emails', action: 'create')
    end

    # Why admin/markdown_editor.js drops the edit form's _method before posting.
    it 'does not route the PATCH an edit form would otherwise turn it into' do
      expect(patch: '/admin/sample_emails').not_to be_routable
    end
  end
end
