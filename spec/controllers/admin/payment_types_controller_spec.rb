require 'rails_helper'

RSpec.describe Admin::PaymentTypesController, type: :controller do
  before do
    user_double = double('User', id: 1, email: 'admin@example.com', role: User::ADMIN,
                                 theater_ids: [], is_box_office_user?: false,
                                 is_theater_user?: false, is_resident?: false, can?: true)
    allow(user_double).to receive(:ability).and_return(Ability.new(user_double))
    allow(controller).to receive(:current_user).and_return(user_double)
    allow(controller).to receive(:authorize!).and_return(true)
  end

  describe 'DELETE #destroy' do
    it 'redirects with an error when the payment type cannot be deleted' do
      payment_type = ExternalPaymentType.create!(display_name: 'Used Tender')
      allow_any_instance_of(ExternalPaymentType).to receive(:destroy) do |record|
        record.errors.add(:base, 'in use')
        false
      end

      delete :destroy, params: { id: payment_type.id }

      expect(response).to redirect_to(admin_payment_types_path)
      expect(flash[:error]).to be_present
      expect(PaymentType.exists?(payment_type.id)).to be true
    end
  end
end
