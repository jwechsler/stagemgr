require 'rails_helper'

RSpec.describe SeatAssignmentsController, type: :controller do
  before(:each) do
    venue = FactoryBot.create(:venue)
    seat_map = FactoryBot.create(:seat_map, venue: venue)

    production = FactoryBot.create(:production, venue: venue, seat_map: seat_map)
    performance = FactoryBot.create(:performance, production: production)
    @ticket_order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, performance: performance)
  end

  describe "GET index" do
    it "returns seating inventory as index" do
      get :index, params: { performance_id: @ticket_order.performance.id }, format: :json
      expect(response).to be_successful
      result = JSON.parse response.body
      expect(result.count).to eq(8) # we get all 16 sample seats back
    end
  end

  describe "POST holds" do
    before(:each) do
      get :index, params: { performance_id: @ticket_order.performance.id }, format: :json
      @inventory = JSON.parse response.body
    end
    it "holds a seat for an order in processing mode" do
      reservation_id = @inventory[0]['id']
      post :reserve,
           params: { performance_id: @ticket_order.performance_id, id: reservation_id, order_uuid: @ticket_order.uuid }, format: :json
      result = JSON.parse response.body
      expect(result['order_uuid']).to eq(@ticket_order.uuid)
      expect(result['status']).to eq('assigned')
      expect(SeatAssignment.find(reservation_id).status).to eq(SeatAssignment::TEMPORARY)
    end

    it "releases a seat for an order in processing mode" do
      reservation_id = @inventory[0]['id']
      post :reserve,
           params: { performance_id: @ticket_order.performance_id, id: reservation_id, :order_uuid => @ticket_order.uuid }, format: :json
      post :release,
           params: { performance_id: @ticket_order.performance_id, id: reservation_id, :order_uuid => @ticket_order.uuid }, format: :json
      result = JSON.parse response.body
      expect(result['status']).to eq('available')
      expect(result['order_uuid']).to be_nil
      expect(SeatAssignment.find(reservation_id).status).to eq(SeatAssignment::AVAILABLE)
    end
  end
end
