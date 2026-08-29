# spec/controllers/current_user/accounts_controller_spec.rb
require 'rails_helper'

RSpec.describe CurrentUser::AccountsController, type: :controller do
  describe '#show house counts' do
    def theater_user_for(production)
      user = FactoryBot.create(:user)
      user.theaters << production.theater
      user
    end

    it 'excludes Inactive performances from the house count listing' do
      production = FactoryBot.create(:production, capacity: 50)
      active = FactoryBot.create(:general_admission, production: production,
                                                     performance_date: Date.current + 1.day)
      inactive = FactoryBot.create(:general_admission, production: production,
                                                       performance_date: Date.current + 2.days,
                                                       status: Performance::INACTIVE)
      allow(controller).to receive(:current_user).and_return(theater_user_for(production))

      get :show

      listed = assigns(:house_counts).map(&:performance)
      expect(listed).to include(active)
      expect(listed).not_to include(inactive)
    end
  end
end
