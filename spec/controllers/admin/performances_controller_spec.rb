require 'rails_helper'

RSpec.describe Admin::PerformancesController, type: :controller do
  let(:theater) { FactoryBot.create(:theater) }
  let(:production) { FactoryBot.create(:production_with_reserved_seating, theater: theater) }
  let(:performance) { FactoryBot.create(:reserved_seating, production: production) }

  before do
    # Mock authentication and authorization
    user_double = double('User', id: 1, email: 'test@example.com', role: User::BOXOFFICE)
    allow(controller).to receive(:current_user).and_return(user_double)
    allow(controller).to receive(:authorize!).and_return(true)
  end

  describe 'POST #release_held_seats' do
    context 'when there are held seats to release' do
      before do
        # Create some TEMPORARY seat assignments without orders
        performance.seat_assignments.take(3).each do |sa|
          sa.update!(status: SeatAssignment::TEMPORARY, order_uuid: nil)
        end
      end

      it 'releases the held seats' do
        expect(SeatAssignment).to receive(:release_temporary_holds_for_performance)
          .with(performance.id)
          .and_return(3)

        post :release_held_seats, params: {
          theater_id: theater.id,
          production_id: production.id,
          id: performance.id
        }
      end

      it 'sets a flash notice with the count' do
        post :release_held_seats, params: {
          theater_id: theater.id,
          production_id: production.id,
          id: performance.id
        }

        expect(flash[:notice]).to match(/Released \d+ held seat/)
      end

      it 'redirects to the performance show page' do
        post :release_held_seats, params: {
          theater_id: theater.id,
          production_id: production.id,
          id: performance.id
        }

        expect(response).to redirect_to(
          admin_theater_production_performance_path(theater, production, performance)
        )
      end
    end

    context 'when there are no held seats to release' do
      it 'sets a flash notice with zero count' do
        post :release_held_seats, params: {
          theater_id: theater.id,
          production_id: production.id,
          id: performance.id
        }

        expect(flash[:notice]).to match(/Released 0 held seats/)
      end
    end
  end
end
