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

  describe '#build_fulfill_labels' do
    let!(:order) { FactoryBot.create(:ticket_order, :for_a_single_ticket) }
    let(:through_date) { order.performance.performance_date }

    before do
      order.update!(status: Order::PROCESSED, hold_under: 'Kathleen (Kate) Early')
      allow(PrintingService).to receive(:print_orders).and_return('BATCH-X')
    end

    it 'includes the hold-under last name in reserved_under' do
      # Regression: the old 4-element destructure of Address.parse_name left
      # l_name nil, so hold-under rows printed as "K" instead of "Early, K".
      _headers, report = controller.send(:build_fulfill_labels, through_date)

      row = report.find { |r| r[:order_id] == order.id }
      expect(row).to be_present
      expect(row[:reserved_under]).to eq('Early, K')
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

  describe '#resource_pull' do
    let!(:resource) { FactoryBot.create(:resourced_ticket_class, quantity: 2, changeover_minutes: 30) }
    let(:venue) { resource.venues.first }
    let(:production) { FactoryBot.create(:production, venue: venue, running_time: 90) }
    let(:show_date) { Date.current + 30.days }
    let(:performance) do
      FactoryBot.create(:performance, production: production, performance_date: show_date,
                                      performance_time: Time.parse("#{show_date} 19:00"))
    end
    let(:shadow) do
      tc = TicketClass.find_or_initialize_by(production_id: production.id,
                                             resourced_ticket_class_id: resource.id)
      tc.synced_from_resource = true
      tc.attributes = resource.shadow_attributes
      tc.save!
      tc
    end

    before do
      tca = TicketClassAllocation.find_or_create_by!(performance: performance, ticket_class: shadow)
      tca.update!(available: true)
    end

    it 'builds the pull sheet for the requested date' do
      order = TicketOrder.new(status: Order::PROCESSED, performance: performance,
                              address: FactoryBot.create(:address),
                              payment_type: FactoryBot.create(:cash_payment_type))
      order.ticket_line_items << TicketLineItem.new(ticket_class: shadow, ticket_count: 1)
      order.save!

      post :resource_pull, params: { performance_day: show_date.to_s }

      expect(response).to have_http_status(:ok)
      expect(assigns(:date)).to eq(show_date)
      expect(assigns(:report_data).first[:resource_code]).to eq(resource.class_code)
      expect(assigns(:report_data).first[:total]).to eq(1)
    end

    it 'flashes an error and redirects when no date is given' do
      post :resource_pull, params: {}

      expect(response).to redirect_to(admin_reports_path)
      expect(flash[:alert]).to be_present
    end

    it 'flashes an error and redirects for an unparseable date' do
      post :resource_pull, params: { performance_day: 'not-a-date' }

      expect(response).to redirect_to(admin_reports_path)
      expect(flash[:alert]).to be_present
    end
  end
end
