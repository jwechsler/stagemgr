require 'rails_helper'

RSpec.describe Admin::OrdersController, type: :controller do
  let(:admin_user) { FactoryBot.create(:admin_user) }

  before do
    allow(controller).to receive(:current_user).and_return(admin_user)
    allow(Resque).to receive(:enqueue)
  end

  describe '#lgl_replicate' do
    let(:donation) { FactoryBot.create(:donation_order) }

    context 'when LGL is enabled' do
      before { allow(Lgl).to receive(:enabled?).and_return(true) }

      it 'queues the gift and returns to the donation page' do
        post :lgl_replicate, params: { id: donation.id }

        expect(Resque).to have_received(:enqueue).with(LglReplicateDonationJob, donation.id)
        expect(response).to redirect_to(admin_donation_order_path(donation))
        expect(flash[:notice]).to eq("Queued the LGL gift for order ##{donation.id}")
      end

      it 'refuses a ticket order without queuing' do
        ticket_order = FactoryBot.create(:ticket_order)

        post :lgl_replicate, params: { id: ticket_order.id }

        expect(Resque).not_to have_received(:enqueue).with(LglReplicateDonationJob, anything)
        expect(response).to redirect_to(admin_order_path(ticket_order))
        expect(flash[:alert]).to eq('Only donations are sent to LGL as gifts')
      end

      it 'refuses a box office user without queuing' do
        allow(controller).to receive(:current_user).and_return(FactoryBot.create(:user, is_box_office_user: true))

        post :lgl_replicate, params: { id: donation.id }

        expect(Resque).not_to have_received(:enqueue).with(LglReplicateDonationJob, anything)
        expect(response).to redirect_to(root_path)
      end

      it 'refuses a theater user without queuing' do
        theater_user = FactoryBot.create(:user, theaters: [FactoryBot.create(:theater)])
        allow(controller).to receive(:current_user).and_return(theater_user)

        post :lgl_replicate, params: { id: donation.id }

        expect(Resque).not_to have_received(:enqueue).with(LglReplicateDonationJob, anything)
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when LGL is disabled' do
      it 'redirects with the not-configured alert and queues nothing' do
        post :lgl_replicate, params: { id: donation.id }

        expect(Resque).not_to have_received(:enqueue).with(LglReplicateDonationJob, anything)
        expect(response).to redirect_to(admin_donation_order_path(donation))
        expect(flash[:alert]).to eq(Admin::LglSyncController::NOT_CONFIGURED)
      end
    end
  end
end
