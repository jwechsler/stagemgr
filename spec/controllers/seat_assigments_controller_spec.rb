require 'rails_helper'

RSpec.describe SeatAssignmentsController, type: :controller do

  before(:each) do
    venue = FactoryBot.create(:venue)
    seat_map = FactoryBot.create(:seat_map, :with_seats, venue: venue)

    production = FactoryBot.create(:production, venue:venue, seat_map:seat_map)
    performance = FactoryBot.create(:performance, production:production)
    @ticket_order = FactoryBot.create(:ticket_order,:for_a_pair_of_tickets, performance:performance)
  end

  describe "GET index" do
    it "returns seating inventory as index" do
      get :index, performance_id: @ticket_order.performance.id, format: :json
      expect(response).to be_success
      result = JSON.parse response.body
      expect(result.count).to eq(8) # we get all 16 sample seats back

    end
  end

  describe "POST holds" do
    before(:each) do
      get :index, performance_id: @ticket_order.performance.id, format: :json
      @inventory = JSON.parse response.body

    end
    it "holds a seat for an order in processing mode" do
      reservation_id = @inventory[0]['id']
      @ticket_order.transition_to!(Order::PROCESSING)
      post :reserve, performance_id: @ticket_order.performance_id, format: :json, id:reservation_id, order_id: @ticket_order.id
      result = JSON.parse response.body
      expect(result['order_id']).to eq(@ticket_order.id)
      expect(result['status']).to eq('assigned')
      expect(SeatAssignment.find(reservation_id).status).to eq(SeatAssignment::ASSIGNED)
    end

    it "releases a seat for an order in processing mode" do
      reservation_id = @inventory[0]['id']
      @ticket_order.transition_to!(Order::PROCESSING)
      post :reserve, performance_id: @ticket_order.performance_id, id:reservation_id, format: :json,  :order_id=>@ticket_order.id
      post :release, performance_id: @ticket_order.performance_id, id:reservation_id, format: :json,  :order_id=>@ticket_order.id
      result = JSON.parse response.body
      expect(result['status']).to eq('available')
      expect(result['order_id']).to be_nil
      expect(SeatAssignment.find(reservation_id).status).to eq(SeatAssignment::AVAILABLE)
    end

  end


end

