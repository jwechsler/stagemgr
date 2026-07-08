require 'rails_helper'

RSpec.describe Admin::ReportsController, type: :controller do
  let(:admin_user) { FactoryBot.create(:admin_user) }

  before do
    allow(controller).to receive(:current_user).and_return(admin_user)
  end

  # These errors are raised by parse_date_params BEFORE process_report runs,
  # so they must be caught by the controller-level rescue_from, not the
  # rescue block inside process_report.
  describe 'report parameter errors raised outside process_report' do
    it 'flashes an error for a date range beyond the configured maximum' do
      get :membership_usage, params: { starting_date: '2020-01-01', ending_date: '2025-12-31' }

      expect(response).to redirect_to(admin_reports_path)
      expect(flash[:error]).to include('Date range too large')
    end

    it 'flashes an error for an unparseable date' do
      get :membership_usage, params: { starting_date: 'not-a-date', ending_date: '2025-12-31' }

      expect(response).to redirect_to(admin_reports_path)
      expect(flash[:error]).to include('Invalid starting date format')
    end

    it 'covers the flex pass patron report the same way' do
      get :flex_pass_patron_report, params: { starting_date: '2020-01-01', ending_date: '2025-12-31' }

      expect(response).to redirect_to(admin_reports_path)
      expect(flash[:error]).to include('Date range too large')
    end
  end
end
