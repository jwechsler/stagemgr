require 'rails_helper'

RSpec.describe Admin::FlexPassOffersController, type: :controller do
  let(:admin_user) { FactoryBot.create(:admin_user) }
  let(:theater) { FactoryBot.create(:theater) }
  
  before do
    allow(controller).to receive(:current_user).and_return(admin_user)
    allow(controller).to receive(:authorize!).and_return(true)
  end

  describe 'POST #create' do
    context 'with decimal values for currency fields' do
      let(:valid_params) do
        {
          flex_pass_offer: {
            name: 'Test Flex Pass',
            theater_id: theater.id,
            price: '99.99',
            facility_fee: '2.50',
            spiff: '1.75',
            flat_payout: '5.25',
            number_of_tickets: '10',
            active: 'true',
            months_till_expiration: '12',
            use_ticket_class_code: 'PASS'
          }
        }
      end

      it 'creates a flex pass offer with decimal values' do
        expect {
          post :create, params: valid_params
        }.to change(FlexPassOffer, :count).by(1)
        
        offer = FlexPassOffer.last
        expect(offer.price).to eq(99.99)
        expect(offer.facility_fee).to eq(2.50)
        expect(offer.spiff).to eq(1.75)
        expect(offer.flat_payout).to eq(5.25)
      end

      it 'redirects to the flex pass offers index' do
        post :create, params: valid_params
        expect(response).to redirect_to(admin_flex_pass_offers_path)
      end
    end

    context 'with invalid values for currency fields' do
      let(:invalid_params) do
        {
          flex_pass_offer: {
            name: 'Test Flex Pass',
            theater_id: theater.id,
            price: 'not a number',
            facility_fee: 'invalid',
            spiff: 'abc',
            flat_payout: 'xyz',
            number_of_tickets: '10',
            active: 'true',
            months_till_expiration: '12',
            use_ticket_class_code: 'PASS'
          }
        }
      end

      it 'does not create a flex pass offer' do
        expect {
          post :create, params: invalid_params
        }.not_to change(FlexPassOffer, :count)
      end

      it 'renders the new template' do
        post :create, params: invalid_params
        expect(response).to render_template(:new)
      end
    end

    context 'with negative values for currency fields' do
      let(:negative_params) do
        {
          flex_pass_offer: {
            name: 'Test Flex Pass',
            theater_id: theater.id,
            price: '-10',
            facility_fee: '-2.50',
            spiff: '-1.75',
            flat_payout: '-5.25',
            number_of_tickets: '10',
            active: 'true',
            months_till_expiration: '12',
            use_ticket_class_code: 'PASS'
          }
        }
      end

      it 'does not create a flex pass offer' do
        expect {
          post :create, params: negative_params
        }.not_to change(FlexPassOffer, :count)
      end

      it 'renders the new template' do
        post :create, params: negative_params
        expect(response).to render_template(:new)
      end
    end
  end

  describe 'PATCH #update' do
    let(:flex_pass_offer) { FactoryBot.create(:flex_pass_offer, theater: theater) }

    context 'with valid decimal values' do
      let(:update_params) do
        {
          id: flex_pass_offer.id,
          flex_pass_offer: {
            price: '149.99',
            facility_fee: '3.50',
            spiff: '2.25',
            flat_payout: '7.75'
          }
        }
      end

      it 'updates the flex pass offer with decimal values' do
        patch :update, params: update_params
        
        flex_pass_offer.reload
        expect(flex_pass_offer.price).to eq(149.99)
        expect(flex_pass_offer.facility_fee).to eq(3.50)
        expect(flex_pass_offer.spiff).to eq(2.25)
        expect(flex_pass_offer.flat_payout).to eq(7.75)
      end

      it 'redirects to the flex pass offer' do
        patch :update, params: update_params
        expect(response).to redirect_to(admin_flex_pass_offer_path(flex_pass_offer))
      end
    end

    context 'with invalid values' do
      let(:invalid_update_params) do
        {
          id: flex_pass_offer.id,
          flex_pass_offer: {
            price: 'invalid'
          }
        }
      end

      it 'does not update the flex pass offer' do
        original_price = flex_pass_offer.price
        patch :update, params: invalid_update_params
        
        flex_pass_offer.reload
        expect(flex_pass_offer.price).to eq(original_price)
      end

      it 'renders the edit template' do
        patch :update, params: invalid_update_params
        expect(response).to render_template(:edit)
      end
    end
  end

  describe 'strong parameters' do
    it 'permits the currency fields' do
      params = ActionController::Parameters.new({
        flex_pass_offer: {
          price: '99.99',
          facility_fee: '2.50',
          spiff: '1.75',
          flat_payout: '5.25',
          other_param: 'should be filtered'
        }
      })

      # We need to test that the controller permits these params
      # This is a bit tricky to test directly, so we'll create the offer
      # and verify the values were set
      post :create, params: {
        flex_pass_offer: {
          name: 'Test Pass',
          theater_id: theater.id,
          price: '99.99',
          facility_fee: '2.50',
          spiff: '1.75',
          flat_payout: '5.25',
          number_of_tickets: '10',
          active: 'true',
          months_till_expiration: '12',
          use_ticket_class_code: 'PASS'
        }
      }

      offer = FlexPassOffer.last
      expect(offer.price).to eq(99.99)
      expect(offer.facility_fee).to eq(2.50)
      expect(offer.spiff).to eq(1.75)
      expect(offer.flat_payout).to eq(5.25)
    end
  end
end