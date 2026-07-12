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

  describe '#order_dump' do
    let!(:production) { FactoryBot.create(:production) }

    it 'enqueues the attendee export with the permitted production ids' do
      expect(Resque).to receive(:enqueue)
        .with(ProductionAttendeeExport, [production.id], anything, admin_user.id)

      post :order_dump, params: { report: { production_ids: [production.id.to_s] } }

      expect(response).to redirect_to(admin_reports_path)
      expect(flash[:notice]).to be_present
    end

    it 'flashes a parameter error when nothing is selected' do
      expect(Resque).not_to receive(:enqueue)

      post :order_dump, params: { report: { production_ids: [] } }

      expect(response).to redirect_to(admin_reports_path)
      expect(flash[:error]).to include('Select at least one production')
    end

    it 'strips ids the current user is not authorized to report on' do
      theater       = FactoryBot.create(:theater)
      other_theater = FactoryBot.create(:theater)
      theater_user  = FactoryBot.create(:user, theaters: [theater])
      allow(controller).to receive(:current_user).and_return(theater_user)

      mine    = FactoryBot.create(:production, theater: theater)
      foreign = FactoryBot.create(:production, theater: other_theater)

      expect(Resque).to receive(:enqueue)
        .with(ProductionAttendeeExport, [mine.id], anything, theater_user.id)

      post :order_dump, params: { report: { production_ids: [mine.id.to_s, foreign.id.to_s] } }
    end
  end

  describe '#production_sales_by_performance' do
    let!(:production) { FactoryBot.create(:production) }

    it 'builds the report for the selected productions' do
      post :production_sales_by_performance, params: { report: { production_ids: [production.id.to_s] } }

      expect(response).to have_http_status(:ok)
      expect(assigns(:productions).to_a).to eq([production])
      expect(assigns(:report_title)).to eq(production.name)
    end

    it 'falls back to the legacy single production_id param' do
      post :production_sales_by_performance, params: { report: { production_id: production.id.to_s } }

      expect(assigns(:productions).to_a).to eq([production])
    end

    it 'titles a shared-festival selection with the festival name' do
      festival = FactoryBot.create(:festival, name: 'Physical Theatre Festival')
      p1 = FactoryBot.create(:production, festival: festival)
      p2 = FactoryBot.create(:production, festival: festival)

      post :production_sales_by_performance,
           params: { report: { production_ids: [p1.id.to_s, p2.id.to_s] } }

      expect(assigns(:report_title)).to eq('Physical Theatre Festival')
    end

    it 'flashes a parameter error when nothing is selected' do
      post :production_sales_by_performance, params: { report: { production_ids: [] } }

      expect(response).to redirect_to(admin_reports_path)
      expect(flash[:error]).to include('Select at least one production')
    end
  end
end
