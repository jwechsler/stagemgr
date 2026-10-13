require 'rails_helper'

RSpec.describe Admin::AnalysisController, type: :controller do
  let(:theater)    { FactoryBot.create(:theater) }
  let(:production) { FactoryBot.create(:production, theater: theater) }

  let(:admin_user) do
    double('AdminUser',
           id: 1,
           email: 'admin@example.com',
           is_administrator?: true,
           theater_ids: [theater.id])
  end

  let(:theater_user) do
    double('TheaterUser',
           id: 2,
           email: 'theater@example.com',
           is_administrator?: false,
           theater_ids: [theater.id])
  end

  before do
    allow(controller).to receive(:authorize!).and_return(true)
    allow(controller).to receive(:current_ability).and_return(double('Ability'))
    accessible_scope = double('AccessibleProductions')
    allow(Production).to receive(:accessible_by).and_return(accessible_scope)
    allow(accessible_scope).to receive(:find).with(production.id.to_s).and_return(production)
    allow(controller).to receive(:can?).and_return(true)
  end

  describe 'POST #audience_export' do
    let(:base_params) do
      {
        target_production_id: production.id,
        comparison_theater_ids: [theater.id.to_s],
        segment_key: 'first_time_vs_comparison',
        window_label: '3 months'
      }
    end

    context 'as an admin user' do
      before { allow(controller).to receive(:current_user).and_return(admin_user) }

      it 'enqueues AudienceCohortExport with the right args and flashes a notice' do
        expect(Resque).to receive(:enqueue).with(
          AudienceCohortExport,
          production.id,
          [theater.id],
          'first_time_vs_comparison',
          '3 months',
          true, # can?(:view_email, Address) stubbed to true
          [theater.id],
          admin_user.id
        )

        post :audience_export, params: base_params
        expect(flash[:notice]).to match(/cohort export is queued/i)
        expect(response).to redirect_to(admin_analysis_index_path(target_production_id: production.id,
                                                                  analysis_type: 'audience', comparison_theater_ids: [theater.id]))
      end

      it 'allows facility-scope exports for admin users' do
        expect(Resque).to receive(:enqueue).with(AudienceCohortExport, anything, anything, 'three_plus_in_building',
                                                 anything, anything, anything, anything)
        post :audience_export, params: base_params.merge(segment_key: 'three_plus_in_building')
      end
    end

    context 'as a theater (non-admin) user' do
      before { allow(controller).to receive(:current_user).and_return(theater_user) }

      it 'allows comparison-scope exports' do
        expect(Resque).to receive(:enqueue).with(AudienceCohortExport, anything, anything, 'first_time_vs_comparison',
                                                 anything, anything, [theater.id], theater_user.id)
        post :audience_export, params: base_params
      end

      it 'blocks facility-scope exports with a flash error' do
        expect(Resque).not_to receive(:enqueue)
        post :audience_export, params: base_params.merge(segment_key: 'three_plus_in_building')
        expect(flash[:error]).to match(/administrators/i)
        expect(response).to redirect_to(admin_analysis_index_path(target_production_id: production.id,
                                                                  analysis_type: 'audience', comparison_theater_ids: [theater.id]))
      end

      %w[first_time_vs_building returning_vs_building three_plus_in_building].each do |key|
        it "blocks facility-scope segment #{key}" do
          expect(Resque).not_to receive(:enqueue)
          post :audience_export, params: base_params.merge(segment_key: key)
        end
      end
    end
  end

  describe 'GET #memberships' do
    render_views

    let(:admin) { FactoryBot.create(:admin_user) }
    let(:gold_offer) { FactoryBot.create(:membership_offer, name: 'Gold Membership') }
    let(:retired_offer) do
      FactoryBot.create(:membership_offer, name: 'Retired Membership', status: MembershipOffer::INACTIVE)
    end
    let(:valid_params) do
      { membership_offer_ids: ['', gold_offer.id.to_s, retired_offer.id.to_s],
        starting_date: '2026-01-01', ending_date: '2026-06-30' }
    end

    before do
      # Use the real ability for these examples, not the file-wide stubs.
      allow(controller).to receive(:authorize!).and_call_original
      allow(controller).to receive(:current_ability).and_call_original
      allow(controller).to receive(:can?).and_call_original
      allow(controller).to receive(:current_user).and_return(admin)
      FactoryBot.create(:membership, membership_offer: gold_offer, member_code: 'GOLD-1',
                                     member_since: Date.new(2026, 2, 1))
    end

    it 'renders the offer typeahead with no results when nothing has been submitted' do
      get :memberships

      expect(response).to have_http_status(:ok)
      page = Capybara.string(response.body)
      expect(page).to have_css("[data-offer-picker][data-scope='analysis'][data-field='membership_offer_ids']")
      expect(page).not_to have_css('.offer-picker-table input', visible: false)
      expect(Capybara.string(response.body)).to have_css('#analysis-tabs li.tabs-title.is-active', text: 'Pass Sales')
      expect(assigns(:results)).to be_nil
    end

    it 'renders results for valid params' do
      get :memberships, params: valid_params

      expect(response).to have_http_status(:ok)
      expect(assigns(:results).total.memberships_in_range).to eq(1)
      expect(assigns(:results).by_offer.map { |stats| stats.offer.name }).to eq(['Gold Membership'])
      expect(response.body).to include('Per-membership economics, per month', 'Avg revenue / month', 'GOLD-1')
      expect(response.body).to include('No activity in this range, so not shown:', 'Retired Membership')
    end

    it 'renders a Passes table for a timed offer, apart from the membership tables' do
      library_offer = FactoryBot.create(:membership_offer, :timed, name: 'Library Pass')
      FactoryBot.create(:library_pass, membership_offer: library_offer, member_code: 'LIB-1',
                                       member_since: Date.new(2026, 2, 1))

      get :memberships, params: valid_params.merge(membership_offer_ids: ['', gold_offer.id.to_s, library_offer.id.to_s])

      page = Capybara.string(response.body)
      expect(page).to have_css('h5', text: 'Library passes')
      expect(page).to have_css('tr.membership-analysis__total td', text: 'Passes')
      expect(page).to have_css('tr td', text: 'Library Pass')
      expect(assigns(:results).total.memberships_in_range).to eq(1)
    end

    it 'shows only the Passes table when every selected offer is timed' do
      library_offer = FactoryBot.create(:membership_offer, :timed, name: 'Library Pass')
      FactoryBot.create(:library_pass, membership_offer: library_offer, member_since: Date.new(2026, 2, 1))

      get :memberships, params: valid_params.merge(membership_offer_ids: ['', library_offer.id.to_s])

      expect(response.body).to include('Library passes')
      expect(response.body).not_to include('Per-membership economics')
    end

    it 'says so when none of the selected offers had activity in the range' do
      get :memberships, params: valid_params.merge(membership_offer_ids: ['', retired_offer.id.to_s])

      expect(response.body).to include('None of the selected offers had any memberships or payments between',
                                       'January 01, 2026 and June 30, 2026')
      expect(response.body).not_to include('Per-membership economics')
    end

    it 'shows submitted offers as chosen in the picker, marking inactive ones' do
      get :memberships, params: valid_params

      picker = Capybara.string(response.body).find('.offer-picker-table')
      expect(picker).to have_css("input[name='membership_offer_ids[]'][value='#{gold_offer.id}']", visible: false)
      expect(picker).to have_css("input[name='membership_offer_ids[]'][value='#{retired_offer.id}']", visible: false)
      expect(picker.find('tr', text: 'Retired Membership')).to have_css('.label', text: 'Inactive')
    end

    it 'lists inactive offers below active ones in the picker' do
      ancient = FactoryBot.create(:membership_offer, name: 'Ancient Membership', status: MembershipOffer::INACTIVE)
      get :memberships, params: valid_params.merge(membership_offer_ids: [ancient.id, retired_offer.id, gold_offer.id])

      rows = Capybara.string(response.body).all('.offer-picker-table tr').map { |row| row.text.squish }
      expect(rows.map { |text| text.sub(/ ?(Inactive )?remove\z/, '') })
        .to eq(['Gold Membership', 'Ancient Membership', 'Retired Membership'])
    end

    it 'rejects a submission with no offers selected' do
      get :memberships, params: valid_params.merge(membership_offer_ids: [''])

      expect(response).to have_http_status(:ok)
      expect(flash[:error]).to match(/at least one membership offer/i)
      expect(assigns(:results)).to be_nil
    end

    describe 'the with-active-memberships group' do
      let(:group_params) do
        { membership_offer_ids: [''], membership_offer_groups: [MembershipAnalysis::WITH_ACTIVE_MEMBERSHIPS],
          starting_date: '2026-01-01', ending_date: '2026-06-30' }
      end

      it 'expands to offers with memberships active in the submitted dates' do
        retired_offer

        get :memberships, params: group_params

        expect(assigns(:results).by_offer.map { |stats| stats.offer.name }).to eq(['Gold Membership'])
      end

      it 'stays a single row in the picker after the run' do
        get :memberships, params: group_params

        picker = Capybara.string(response.body).find('.offer-picker-table')
        expect(picker).to have_css('tr.offer-picker-dynamic', text: 'Offers with active memberships in the selected dates')
        expect(picker).to have_css("input.offer-picker-group[value='#{MembershipAnalysis::WITH_ACTIVE_MEMBERSHIPS}']",
                                   visible: false)
      end

      it 'combines with offers picked individually' do
        get :memberships, params: group_params.merge(membership_offer_ids: ['', retired_offer.id.to_s])

        expect(assigns(:results).by_offer.map { |stats| stats.offer.name }).to eq(['Gold Membership'])
        expect(assigns(:results).idle_offers.map(&:name)).to eq(['Retired Membership'])
      end

      it 'reports when no offer had active memberships in the dates' do
        get :memberships, params: group_params.merge(starting_date: '2020-01-01', ending_date: '2020-12-31')

        expect(flash[:error]).to match(/No membership offers had active memberships between/)
        expect(assigns(:results)).to be_nil
      end

      it 'ignores unknown group keys' do
        get :memberships, params: group_params.merge(membership_offer_groups: ['everything'])

        expect(flash[:error]).to match(/at least one membership offer/i)
      end
    end

    it 'rejects a start date after the end date' do
      get :memberships, params: valid_params.merge(starting_date: '2026-07-01')

      expect(flash[:error]).to match(/start date must be on or before/i)
      expect(assigns(:results)).to be_nil
    end

    it 'rejects an unparseable date' do
      get :memberships, params: valid_params.merge(ending_date: 'not a date')

      expect(flash[:error]).to match(/valid start and end date/i)
      expect(assigns(:results)).to be_nil
    end

    it 'forbids box office users' do
      allow(controller).to receive(:current_user)
        .and_return(FactoryBot.create(:user, is_box_office_user: true))

      get :memberships, params: valid_params

      expect(response).to redirect_to(root_path)
      expect(assigns(:results)).to be_nil
    end

    it 'forbids theater users, who may run the production analyses' do
      theater_user = FactoryBot.create(:user, theaters: [FactoryBot.create(:theater)])
      allow(controller).to receive(:current_user).and_return(theater_user)

      get :memberships, params: valid_params

      expect(response).to redirect_to(root_path)
      expect(assigns(:results)).to be_nil
    end
  end

  describe 'GET #advance_sales' do
    render_views

    let(:admin) { FactoryBot.create(:admin_user) }
    let(:venue) { FactoryBot.create(:venue) }
    let(:show_date) { Date.current - 30.days } # played, so series are finished unless an example says otherwise

    def next_seq
      @seq = (@seq || 0) + 1
    end

    # A production with one seat-holding class and one performance on +on+.
    def make_performance(theater, season:, on: show_date)
      n = next_seq
      production = Production.create!(
        name: "Advance Ctl #{n}", production_code: "AK#{n.to_s.rjust(4, '0')}", capacity: 100,
        opening_at: on, first_preview_at: on, press_opening_at: on,
        closing_at: on + 30.days, season: season, status: Production::ACTIVE, theater: theater, venue: venue
      )
      TicketClass.create!(production: production, class_code: "AK#{n.to_s.rjust(4, '0')}", class_name: "Class #{n}",
                          ticket_type: 'Fixed', ticket_price: 25.0, ticketing_fee: 0.0, complimentary: false,
                          holds_seats: true, web_visible: true, auto_attach: false, software_managed: false)
      Performance.create!(performance_code: "#{production.production_code}01", production: production,
                          performance_date: on, status: Performance::PERFORMANCE_STATUSES.first,
                          performance_time: Time.zone.local(on.year, on.month, on.day, 19, 30))
    end

    def sell(performance, tickets:, days_before:)
      order = TicketOrder.create!(status: Order::NEW, performance: performance, address: FactoryBot.create(:address),
                                  payment_type: FactoryBot.create(:cash_payment_type))
      TicketLineItem.create!(order: order, ticket_class: performance.production.ticket_classes.first,
                             ticket_count: tickets)
      day = performance.performance_date - days_before
      order.update_columns(status: Order::PROCESSED, created_at: Time.zone.local(day.year, day.month, day.day, 12))
      order
    end

    before do
      # Use the real ability and production scope for these examples, not the file-wide stubs.
      allow(controller).to receive(:authorize!).and_call_original
      allow(controller).to receive(:current_ability).and_call_original
      allow(controller).to receive(:can?).and_call_original
      allow(Production).to receive(:accessible_by).and_call_original
      allow(controller).to receive(:current_user).and_return(admin)
    end

    it 'renders the filter form with no results when nothing has been submitted' do
      make_performance(theater, season: 2025)

      get :advance_sales

      expect(response).to have_http_status(:ok)
      expect(assigns(:filters).submitted?).to be(false)
      expect(assigns(:filters).seasons).to include(2025)
      expect(assigns(:results)).to be_nil
      page = Capybara.string(response.body)
      expect(page).to have_css('form#advance-sales-form')
      expect(page).to have_css("input[type='checkbox'][name='seasons[]'][value='2025'][checked]")
    end

    it 'marks the Advance Sales tab active' do
      get :advance_sales

      expect(Capybara.string(response.body)).to have_css('#analysis-tabs li.tabs-title.is-active', text: 'Advance Sales')
    end

    it 'renders results for valid params' do
      performance = make_performance(theater, season: 2025)
      sell(performance, tickets: 3, days_before: 10)

      get :advance_sales, params: { seasons: ['', '2025'], theater_ids: [''] }

      expect(response).to have_http_status(:ok)
      expect(assigns(:results).tickets).to eq(3)
      expect(assigns(:results).series.map(&:label)).to eq(['2025 – single tickets'])
      page = Capybara.string(response.body)
      expect(page).to have_css('#advance-sales-results table td', text: '2025 – single tickets')
      expect(page).to have_css('#advance-sales-results .accordion-title', text: performance.production.picker_label)
      headers = page.first('#advance-sales-results table').all('thead th').map(&:text)
      expect(headers).to eq(['Series', 'Tickets', 'Upcoming', 'Same day', '1–2d', '3–6d', '7–13d', '14–29d', '30+d'])
      cells = page.first('#advance-sales-results table').all('tbody td').map(&:text)
      expect(cells.last(6)).to eq(['0%', '0%', '0%', '100%', '0%', '0%'])
      expect(page).to have_css('#advance-sales-results p.help-text', text: 'the columns sum to 100%')
    end

    it 'warns when a series is in progress' do
      performance = make_performance(theater, season: 2025, on: Date.current + 7.days)
      sell(performance, tickets: 3, days_before: 10)

      get :advance_sales, params: { seasons: ['2025'] }

      expect(assigns(:results).in_progress?).to be(true)
      expect(response.body).to include('in progress', 'Upcoming')
      page = Capybara.string(response.body)
      expect(page).to have_css('#advance-sales-results .callout.warning',
                               text: "include performances that haven't played yet")
      expect(page).to have_css('#advance-sales-results tr.in-progress td', text: '2025 – single tickets (in progress)')
      expect(page).to have_css('#advance-sales-results tr.in-progress td', exact_text: '1 of 1')
      expect(page).to have_css('#advance-sales-results .accordion-title .label', text: 'in progress')
      expect(page).to have_css('#advance-sales-results td .label', exact_text: '1 upcoming')
    end

    it 'does not warn when every performance has played' do
      sell(make_performance(theater, season: 2025), tickets: 3, days_before: 10)

      get :advance_sales, params: { seasons: ['2025'] }

      expect(assigns(:results).in_progress?).to be(false)
      page = Capybara.string(response.body)
      expect(page).to have_css('#advance-sales-results th', text: 'Upcoming')
      expect(page).not_to have_text("include performances that haven't played yet")
      expect(page).not_to have_css('#advance-sales-results tr.in-progress')
      expect(page).not_to have_css('#advance-sales-results .accordion-title .label', text: 'in progress')
    end

    it 'rejects a submission with no seasons' do
      make_performance(theater, season: 2025)

      get :advance_sales, params: { seasons: [''] }

      expect(response).to have_http_status(:ok)
      expect(flash.now[:error]).to eq('Select at least one season.')
      expect(assigns(:results)).to be_nil
    end

    it 'says so when the selection sold nothing' do
      make_performance(theater, season: 2025)

      get :advance_sales, params: { seasons: ['2025'] }

      expect(assigns(:results).activity?).to be(false)
      expect(response.body).to include('Nothing sold for that selection.')
    end

    it 'limits a theater user to the productions of their own theaters' do
      own = FactoryBot.create(:theater, name: 'AS Own Theater')
      other = FactoryBot.create(:theater, name: 'AS Other Theater')
      sell(make_performance(own, season: 2025), tickets: 2, days_before: 5)
      sell(make_performance(other, season: 2025), tickets: 7, days_before: 5)
      allow(controller).to receive(:current_user).and_return(FactoryBot.create(:user, theaters: [own]))

      get :advance_sales, params: { theater_ids: [other.id.to_s], seasons: ['2025'], compare_by: 'theater' }

      expect(response).to have_http_status(:ok)
      expect(assigns(:theaters)).to eq([own])
      expect(assigns(:filters).theater_ids).to eq([own.id])
      expect(assigns(:results).tickets).to eq(2)
      expect(assigns(:results).series.map(&:label)).to eq(['AS Own Theater – single tickets'])
      expect(response.body).not_to include('AS Other Theater')
    end

    it 'renders the theater picker pre-filled with the picked theaters' do
      picked = FactoryBot.create(:theater, name: 'AS Picked Theater')
      unpicked = FactoryBot.create(:theater, name: 'AS Unpicked Theater')
      make_performance(picked, season: 2025)
      make_performance(unpicked, season: 2025)

      get :advance_sales, params: { theater_ids: [picked.id.to_s], seasons: ['2025'] }

      expect(assigns(:filters).picked_theater_ids).to eq([picked.id])
      expect(response.body).to include('data-theater-multi-picker')
      expect(response.body).not_to include('<select name="theater_ids[]"')
      page = Capybara.string(response.body)
      picker = page.find('#advance-sales-form [data-theater-multi-picker]', visible: :all)
      expect(picker['data-search-url']).to eq(search_admin_theaters_path)
      expect(picker).to have_css('input.theater-multi-picker-input[type="text"]')
      expect(picker).to have_css("input[type='hidden'][name='theater_ids[]'][value='#{picked.id}']", visible: :all)
      expect(picker).to have_css('input[type="hidden"][name="theater_ids[]"]', count: 1, visible: :all)
      expect(picker).to have_css('table.theater-multi-picker-table td', text: 'AS Picked Theater', visible: :all)
      expect(picker).not_to have_text('AS Unpicked Theater')
    end

    it 'renders the theater picker empty when no theater was picked' do
      make_performance(theater, season: 2025)

      get :advance_sales, params: { seasons: ['2025'] }

      expect(assigns(:filters).picked_theater_ids).to eq([])
      expect(assigns(:filters).theater_ids).to eq([theater.id])
      expect(response.body).not_to include('<select name="theater_ids[]"')
      page = Capybara.string(response.body)
      expect(page).to have_css('#advance-sales-form [data-theater-multi-picker] input.theater-multi-picker-input',
                               visible: :all)
      expect(page).not_to have_css('input[name="theater_ids[]"]', visible: :all)
    end

    it 'forbids box office users' do
      allow(controller).to receive(:current_user)
        .and_return(FactoryBot.create(:user, is_box_office_user: true))

      get :advance_sales, params: { seasons: ['2025'] }

      expect(response).to redirect_to(root_path)
      expect(assigns(:results)).to be_nil
    end
  end
end
