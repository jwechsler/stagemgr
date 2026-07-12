require 'rails_helper'

RSpec.describe SeatAssignmentsController, type: :controller do
  before(:each) do
    venue = FactoryBot.create(:venue)
    seat_map = FactoryBot.create(:seat_map, venue: venue)

    production = FactoryBot.create(:production, venue: venue, seat_map: seat_map)
    performance = FactoryBot.create(:performance, production: production)
    @ticket_order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, performance: performance)
  end

  describe 'GET index' do
    it 'returns seating inventory as index' do
      get :index, params: { performance_id: @ticket_order.performance.id }, format: :json
      expect(response).to be_successful
      result = JSON.parse response.body
      expect(result.count).to eq(8) # we get all 16 sample seats back
    end
  end

  describe 'POST holds' do
    before(:each) do
      get :index, params: { performance_id: @ticket_order.performance.id }, format: :json
      @inventory = JSON.parse response.body
    end
    it 'holds a seat for an order in processing mode' do
      reservation_id = @inventory[0]['id']
      post :reserve,
           params: { performance_id: @ticket_order.performance_id, id: reservation_id, order_uuid: @ticket_order.uuid }, format: :json
      result = JSON.parse response.body
      expect(result['order_uuid']).to eq(@ticket_order.uuid)
      expect(result['status']).to eq('assigned')
      expect(SeatAssignment.find(reservation_id).status).to eq(SeatAssignment::TEMPORARY)
    end

    it 'releases a seat for an order in processing mode' do
      reservation_id = @inventory[0]['id']
      post :reserve,
           params: { performance_id: @ticket_order.performance_id, id: reservation_id, order_uuid: @ticket_order.uuid }, format: :json
      post :release,
           params: { performance_id: @ticket_order.performance_id, id: reservation_id, order_uuid: @ticket_order.uuid }, format: :json
      result = JSON.parse response.body
      expect(result['status']).to eq('available')
      expect(result['order_uuid']).to be_nil
      expect(SeatAssignment.find(reservation_id).status).to eq(SeatAssignment::AVAILABLE)
    end
  end

  describe 'non-seat ticket class guard' do
    before(:each) do
      @performance = @ticket_order.performance
      @reservation_id = SeatAssignment.where(performance_id: @performance.id,
                                             status: SeatAssignment::AVAILABLE).first.id
    end

    def allocated_class(holds_seats:)
      tc = FactoryBot.create(:ticket_class, production: @performance.production, holds_seats: holds_seats)
      tca = @performance.ticket_class_allocations.find_or_initialize_by(ticket_class: tc)
      tca.available = true
      tca.save!
      tc
    end

    it 'rejects a class that does not hold a seat (no state left behind)' do
      tc = allocated_class(holds_seats: false)
      post :reserve,
           params: { performance_id: @performance.id, id: @reservation_id,
                     order_uuid: @ticket_order.uuid, ticket_class_id: tc.id }, format: :json
      expect(response).to have_http_status(:unprocessable_entity)
      result = JSON.parse response.body
      expect(result['status']).to eq('error')
      expect(result['message']).to include(tc.class_name)
      expect(result['message']).to include('does not reserve a seat')

      sa = SeatAssignment.find(@reservation_id)
      expect(sa.status).to eq(SeatAssignment::AVAILABLE)
      expect(sa.order_uuid).to be_blank
      expect(sa.ticket_line_item).to be_nil
    end

    it 'accepts a seat-holding class' do
      tc = allocated_class(holds_seats: true)
      post :reserve,
           params: { performance_id: @performance.id, id: @reservation_id,
                     order_uuid: @ticket_order.uuid, ticket_class_id: tc.id }, format: :json
      expect(response).to be_successful
      expect(SeatAssignment.find(@reservation_id).status).to eq(SeatAssignment::TEMPORARY)
    end
  end

  describe 'zoned pricing enforcement' do
    before(:each) do
      @performance = @ticket_order.performance
      @reservation_id = SeatAssignment.where(performance_id: @performance.id,
                                             status: SeatAssignment::AVAILABLE).first.id
    end

    def allocated_class(zone_id)
      tc = FactoryBot.create(:ticket_class, production: @performance.production, zone_id: zone_id)
      tca = @performance.ticket_class_allocations.find_or_initialize_by(ticket_class: tc)
      tca.available = true
      tca.save!
      tc
    end

    it 'rejects a class whose zone does not match the seat (no state left behind)' do
      tc = allocated_class('B') # seats default to zone "A"
      post :reserve,
           params: { performance_id: @performance.id, id: @reservation_id,
                     order_uuid: @ticket_order.uuid, ticket_class_id: tc.id }, format: :json
      expect(response).to have_http_status(:unprocessable_entity)
      result = JSON.parse response.body
      expect(result['status']).to eq('error')
      expect(result['message']).to include('zone A')

      sa = SeatAssignment.find(@reservation_id)
      expect(sa.status).to eq(SeatAssignment::AVAILABLE)
      expect(sa.order_uuid).to be_blank
      expect(sa.ticket_line_item).to be_nil
    end

    it 'accepts a class whose zone matches the seat' do
      tc = allocated_class('A')
      post :reserve,
           params: { performance_id: @performance.id, id: @reservation_id,
                     order_uuid: @ticket_order.uuid, ticket_class_id: tc.id }, format: :json
      expect(response).to be_successful
      expect(SeatAssignment.find(@reservation_id).status).to eq(SeatAssignment::TEMPORARY)
    end

    it 'accepts a wildcard class for any seat zone' do
      seat = SeatAssignment.find(@reservation_id).seat
      seat.update!(zone: 'Q9')
      tc = allocated_class('*')
      post :reserve,
           params: { performance_id: @performance.id, id: @reservation_id,
                     order_uuid: @ticket_order.uuid, ticket_class_id: tc.id }, format: :json
      expect(response).to be_successful
      expect(SeatAssignment.find(@reservation_id).status).to eq(SeatAssignment::TEMPORARY)
    end

    describe 'reseating (classless reserve with releasing seats)' do
      before(:each) do
        # Simulate a reseat in progress: one of the order's seats is being
        # released and carries a zone-A-only ticket class.
        @releasing_class = allocated_class('A')
        releasing_sa = SeatAssignment.where(performance_id: @performance.id,
                                            status: SeatAssignment::AVAILABLE).first
        releasing_sa.update!(order_uuid: @ticket_order.uuid, ticket_class_id: @releasing_class.id,
                             status: SeatAssignment::RELEASING)
        @target = SeatAssignment.where(performance_id: @performance.id,
                                       status: SeatAssignment::AVAILABLE).first
      end

      it 'rejects a replacement seat in a zone the releasing classes do not serve' do
        @target.seat.update!(zone: 'B')
        post :reserve,
             params: { performance_id: @performance.id, id: @target.id,
                       order_uuid: @ticket_order.uuid }, format: :json
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['message']).to include('zone B')
        expect(@target.reload.status).to eq(SeatAssignment::AVAILABLE)
      end

      it 'accepts a replacement seat in the zone the releasing class serves' do
        expect(@target.seat.zone).to eq('A')
        post :reserve,
             params: { performance_id: @performance.id, id: @target.id,
                       order_uuid: @ticket_order.uuid }, format: :json
        expect(response).to be_successful
        expect(@target.reload.status).to eq(SeatAssignment::TEMPORARY)
      end
    end
  end
end
