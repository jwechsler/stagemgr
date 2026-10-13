require 'rails_helper'

RSpec.describe Admin::AnalysisController, type: :controller do
  let(:theater)    { FactoryBot.create(:theater) }
  let(:production) { FactoryBot.create(:production, theater: theater) }

  let(:admin_user) do
    double('AdminUser',
           id: 1,
           email: 'admin@example.com',
           is_administrator?: true,
           is_theater_user?: false,
           theater_ids: [theater.id])
  end

  let(:theater_user) do
    double('TheaterUser',
           id: 2,
           email: 'theater@example.com',
           is_administrator?: false,
           is_theater_user?: true,
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

  # Use the real ability and production scope, not the file-wide stubs.
  def use_real_ability(user)
    allow(controller).to receive(:authorize!).and_call_original
    allow(controller).to receive(:current_ability).and_call_original
    allow(controller).to receive(:can?).and_call_original
    allow(Production).to receive(:accessible_by).and_call_original
    allow(Theater).to receive(:accessible_by).and_call_original
    allow(controller).to receive(:current_user).and_return(user)
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

    before { allow(Theater).to receive(:accessible_by).and_return(Theater.all) }

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
        expect(response).to redirect_to(audience_admin_analysis_index_path(target_production_id: production.id,
                                                                           comparison_theater_ids: [theater.id]))
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
        expect(response).to redirect_to(audience_admin_analysis_index_path(target_production_id: production.id,
                                                                           comparison_theater_ids: [theater.id]))
      end

      %w[first_time_vs_building returning_vs_building three_plus_in_building].each do |key|
        it "blocks facility-scope segment #{key}" do
          expect(Resque).not_to receive(:enqueue)
          post :audience_export, params: base_params.merge(segment_key: key)
        end
      end
    end

    describe 'comparison theaters outside the user’s own' do
      let(:other_theater) { FactoryBot.create(:theater, name: 'AE Other Theater') }
      let(:params_with_other) { base_params.merge(comparison_theater_ids: [theater.id.to_s, other_theater.id.to_s]) }

      it 'enqueues and redirects with only the theaters a multi-theater user can read' do
        use_real_ability(FactoryBot.create(:user, theaters: [theater, FactoryBot.create(:theater)]))
        expect(Resque).to receive(:enqueue).with(AudienceCohortExport, production.id, [theater.id],
                                                 'first_time_vs_comparison', anything, anything, anything, anything)

        post :audience_export, params: params_with_other

        expect(response).to redirect_to(audience_admin_analysis_index_path(target_production_id: production.id,
                                                                           comparison_theater_ids: [theater.id]))
      end

      it 'enqueues the only theater a single-theater user can read when none was submitted' do
        use_real_ability(FactoryBot.create(:user, theaters: [theater]))
        expect(Resque).to receive(:enqueue).with(AudienceCohortExport, production.id, [theater.id],
                                                 'first_time_vs_comparison', anything, anything, anything, anything)

        post :audience_export, params: base_params.merge(comparison_theater_ids: [''])

        expect(response).to redirect_to(audience_admin_analysis_index_path(target_production_id: production.id,
                                                                           comparison_theater_ids: [theater.id]))
      end

      it 'enqueues only the single-theater user’s theater whatever was submitted' do
        use_real_ability(FactoryBot.create(:user, theaters: [theater]))
        expect(Resque).to receive(:enqueue).with(AudienceCohortExport, production.id, [theater.id],
                                                 'first_time_vs_comparison', anything, anything, anything, anything)

        post :audience_export, params: base_params.merge(comparison_theater_ids: [other_theater.id.to_s])

        expect(response).to redirect_to(audience_admin_analysis_index_path(target_production_id: production.id,
                                                                           comparison_theater_ids: [theater.id]))
      end

      it 'enqueues every submitted theater for an administrator' do
        use_real_ability(FactoryBot.create(:admin_user))
        expect(Resque).to receive(:enqueue) do |*args|
          expect(args[2]).to contain_exactly(theater.id, other_theater.id)
        end

        post :audience_export, params: params_with_other
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

    before { use_real_ability(admin) }

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

    describe 'a bookmark naming theaters outside the user’s own' do
      let(:own) { FactoryBot.create(:theater, name: 'AS Own Theater') }
      let(:other) { FactoryBot.create(:theater, name: 'AS Other Theater') }
      let(:theater_user) { FactoryBot.create(:user, theaters: [own]) }

      before do
        sell(make_performance(own, season: 2025), tickets: 2, days_before: 5)
        sell(make_performance(other, season: 2025), tickets: 7, days_before: 5)
      end

      it 'warns a theater user and runs on their own theaters' do
        allow(controller).to receive(:current_user).and_return(theater_user)

        get :advance_sales, params: { theater_ids: [own.id.to_s, other.id.to_s], seasons: ['2025'] }

        expect(response).to have_http_status(:ok)
        expect(flash.now[:warning]).to eq(described_class::NARROWED_NOTICE)
        expect(flash.now[:error]).to be_nil
        expect(assigns(:filters).theater_ids).to eq([own.id])
        expect(assigns(:results).tickets).to eq(2)
        expect(Capybara.string(response.body))
          .to have_css('.flash_warning', exact_text: described_class::NARROWED_NOTICE, normalize_ws: true)
      end

      it 'does not warn a theater user whose theaters are all readable' do
        allow(controller).to receive(:current_user).and_return(theater_user)

        get :advance_sales, params: { theater_ids: [own.id.to_s], seasons: ['2025'] }

        expect(flash.now[:warning]).to be_nil
        expect(assigns(:results).tickets).to eq(2)
        expect(response.body).not_to include(described_class::NARROWED_NOTICE)
      end

      it 'shows only the no-season error when the narrowed bookmark has no seasons' do
        allow(controller).to receive(:current_user).and_return(theater_user)

        get :advance_sales, params: { theater_ids: [other.id.to_s], seasons: [''] }

        expect(flash.now[:error]).to eq('Select at least one season.')
        expect(flash.now[:warning]).to be_nil
        expect(assigns(:results)).to be_nil
        page = Capybara.string(response.body)
        expect(page).to have_css('.flash_error', exact_text: 'Select at least one season.', normalize_ws: true)
        expect(page).not_to have_css('.flash_warning')
      end

      it 'does not warn an administrator, who can read every theater' do
        get :advance_sales, params: { theater_ids: [own.id.to_s, other.id.to_s], seasons: ['2025'] }

        expect(flash.now[:warning]).to be_nil
        expect(assigns(:filters).theater_ids).to contain_exactly(own.id, other.id)
        expect(assigns(:results).tickets).to eq(9)
        expect(response.body).not_to include(described_class::NARROWED_NOTICE)
      end
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

    describe 'the theater picker for a user who can read one theater' do
      let(:own) { FactoryBot.create(:theater, name: 'AS Only Theater') }

      before do
        sell(make_performance(own, season: 2025), tickets: 2, days_before: 5)
        use_real_ability(FactoryBot.create(:user, theaters: [own]))
      end

      it 'is not rendered' do
        get :advance_sales

        page = Capybara.string(response.body)
        expect(page).to have_css('form#advance-sales-form')
        expect(page).not_to have_css('.theater-multi-picker', visible: :all)
        expect(page).not_to have_css('input[name="theater_ids[]"]', visible: :all)
      end

      it 'runs a seasons-only submission against that theater without a warning' do
        get :advance_sales, params: { seasons: ['', '2025'] }

        expect(flash.now[:error]).to be_nil
        expect(flash.now[:warning]).to be_nil
        expect(assigns(:filters).theater_ids).to eq([own.id])
        expect(assigns(:results).tickets).to eq(2)
        expect(response.body).not_to include(described_class::NARROWED_NOTICE)
      end

      it 'still offers the external-sales checkbox when a production there records sales externally' do
        own.productions.update_all(sales_recorded_externally: true)

        get :advance_sales, params: { seasons: ['2025'], include_external: '1' }

        page = Capybara.string(response.body)
        expect(page).to have_css('#advance-sales-form input#include_external[checked]')
        expect(page).not_to have_css('.theater-multi-picker', visible: :all)
        expect(page).to have_css('.accordion-title', text: 'external sales')
        expect(assigns(:results).tickets).to eq(2)
      end

      it 'does not offer the external-sales checkbox when no readable production records sales externally' do
        FactoryBot.create(:production, sales_recorded_externally: true)

        get :advance_sales, params: { seasons: ['2025'] }

        expect(Capybara.string(response.body)).not_to have_css('#advance-sales-form input#include_external')
      end
    end

    it 'renders the theater picker for a theater user with two theaters' do
      second = FactoryBot.create(:theater, name: 'AS Second Theater')
      make_performance(theater, season: 2025)
      make_performance(second, season: 2025)
      use_real_ability(FactoryBot.create(:user, theaters: [theater, second]))

      get :advance_sales

      expect(Capybara.string(response.body)).to have_css('#advance-sales-form .theater-multi-picker', visible: :all)
    end

    it 'renders the theater picker for an administrator' do
      make_performance(theater, season: 2025)

      get :advance_sales

      expect(Capybara.string(response.body)).to have_css('#advance-sales-form .theater-multi-picker', visible: :all)
    end

    it 'forbids box office users' do
      allow(controller).to receive(:current_user)
        .and_return(FactoryBot.create(:user, is_box_office_user: true))

      get :advance_sales, params: { seasons: ['2025'] }

      expect(response).to redirect_to(root_path)
      expect(assigns(:results)).to be_nil
    end
  end

  describe 'GET #index' do
    it 'redirects to the Rate of Sales tab' do
      get :index

      expect(response).to redirect_to(rate_of_sales_admin_analysis_index_path)
    end

    it 'sends a legacy audience bookmark to the Audience tab with its picks' do
      get :index, params: { analysis_type: 'audience', target_production_id: production.id.to_s,
                            comparison_theater_ids: [theater.id.to_s] }

      expect(response).to redirect_to(audience_admin_analysis_index_path(target_production_id: production.id,
                                                                         comparison_theater_ids: [theater.id]))
    end

    it 'sends a legacy rate of sales bookmark to the Rate of Sales tab with its comparisons' do
      get :index, params: { analysis_type: 'rate_of_sales', target_production_id: production.id.to_s,
                            comparison_production_ids: ['7', '8'] }

      expect(response).to redirect_to(rate_of_sales_admin_analysis_index_path(target_production_id: production.id,
                                                                              comparison_production_ids: %w[7 8]))
    end

    it 'sends a legacy ticket revenue bookmark to the Ticket Revenue tab' do
      get :index, params: { analysis_type: 'ticket_revenue', target_production_id: production.id.to_s,
                            comparison_production_id: '9' }

      expect(response).to redirect_to(ticket_revenue_admin_analysis_index_path(target_production_id: production.id,
                                                                               comparison_production_id: '9'))
    end

    it 'sends an unknown analysis_type to the Rate of Sales tab' do
      get :index, params: { analysis_type: 'bogus', target_production_id: production.id.to_s }

      expect(response).to redirect_to(rate_of_sales_admin_analysis_index_path)
    end
  end

  describe 'GET #rate_of_sales' do
    render_views

    let(:admin) { FactoryBot.create(:admin_user) }
    let(:target_performance) { make_performance(theater, season: 2026, on: Date.current - 5.days) }
    let(:target) { target_performance.production }
    let(:comparison_performance) { make_performance(theater, season: 2025, on: Date.current - 400.days) }
    let(:comparison) { comparison_performance.production }

    before { use_real_ability(admin) }

    it 'renders the form with no results when nothing has been submitted' do
      get :rate_of_sales

      expect(response).to have_http_status(:ok)
      page = Capybara.string(response.body)
      expect(page).to have_css('form#rate-of-sales-form')
      expect(page).to have_button('Run analysis', disabled: true)
      expect(page).not_to have_css('#rate-of-sales-results')
      expect(page).to have_css('#analysis-tabs li.tabs-title.is-active', text: 'Rate of Sales')
      expect(assigns(:results)).to be_nil
    end

    it 'shows all five tabs, including Pass Sales, to an administrator' do
      get :rate_of_sales

      tabs = Capybara.string(response.body).all('#analysis-tabs li.tabs-title').map { |li| li.text.strip }
      expect(tabs).to eq(['Rate of Sales', 'Ticket Revenue', 'Audience', 'Advance Sales', 'Pass Sales'])
      expect(Capybara.string(response.body)).to have_link('Pass Sales', href: memberships_admin_analysis_index_path)
    end

    it 'hides the Pass Sales tab from users who may not analyze passes' do
      allow(controller).to receive(:can?).with(:analyze_passes, Analysis).and_return(false)

      get :rate_of_sales

      page = Capybara.string(response.body)
      expect(page).to have_css('#analysis-tabs li.tabs-title.is-active', text: 'Rate of Sales')
      expect(page).not_to have_link('Pass Sales')
    end

    it 'renders results below the form, which keeps the picks' do
      sell(target_performance, tickets: 2, days_before: 3)
      sell(comparison_performance, tickets: 4, days_before: 3)

      get :rate_of_sales, params: { target_production_id: target.id.to_s,
                                    comparison_production_ids: [comparison.id.to_s] }

      expect(response).to have_http_status(:ok)
      expect(assigns(:results)).to be_present
      page = Capybara.string(response.body)
      expect(page).to have_css('#rate-of-sales-results')
      expect(page).to have_css("form#rate-of-sales-form input[name='target_production_id'][value='#{target.id}']",
                               visible: :all)
      expect(page).to have_css("form#rate-of-sales-form input[name='comparison_production_ids[]'][value='#{comparison.id}']",
                               visible: :all)
      expect(page).to have_css('#analysis-tabs li.tabs-title.is-active', text: 'Rate of Sales')
    end

    it 'pre-fills the form without running when only a current show is given' do
      get :rate_of_sales, params: { target_production_id: target.id.to_s }

      expect(response).to have_http_status(:ok)
      expect(flash.now[:error]).to be_nil
      expect(assigns(:results)).to be_nil
      page = Capybara.string(response.body)
      expect(page).not_to have_css('#rate-of-sales-results')
      expect(page).to have_css("form#rate-of-sales-form input[name='target_production_id'][value='#{target.id}']",
                               visible: :all)
    end

    it 'asks for a current show when the form was submitted without one' do
      get :rate_of_sales, params: { target_production_id: '', comparison_production_ids: ['', comparison.id.to_s] }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Select a current show.')
      expect(assigns(:results)).to be_nil
      expect(Capybara.string(response.body)).not_to have_css('#rate-of-sales-results')
    end

    it 'asks for a comparison show when none was submitted' do
      get :rate_of_sales, params: { target_production_id: target.id.to_s, comparison_production_ids: [''] }

      expect(response).to have_http_status(:ok)
      expect(flash.now[:error]).to eq('Select at least one comparison show.')
      expect(response.body).to include('Select at least one comparison show.')
      expect(assigns(:results)).to be_nil
      page = Capybara.string(response.body)
      expect(page).not_to have_css('#rate-of-sales-results')
      expect(page).to have_css("input[name='target_production_id'][value='#{target.id}']", visible: :all)
    end

    it 'says so when the submitted production cannot be found' do
      get :rate_of_sales, params: { target_production_id: '0', comparison_production_ids: [comparison.id.to_s] }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('That production could not be found.')
      expect(Capybara.string(response.body)).not_to have_css('#rate-of-sales-results')
    end

    describe 'a bookmark naming shows outside the user’s theaters' do
      let(:other_theater) { FactoryBot.create(:theater, name: 'ROS Other Theater') }
      let(:unreadable) { make_performance(other_theater, season: 2025, on: Date.current - 400.days).production }
      let(:theater_user) { FactoryBot.create(:user, theaters: [theater]) }

      it 'warns a theater user and runs on the readable comparison shows only' do
        use_real_ability(theater_user)

        get :rate_of_sales, params: { target_production_id: target.id.to_s,
                                      comparison_production_ids: [comparison.id.to_s, unreadable.id.to_s] }

        expect(response).to have_http_status(:ok)
        expect(flash.now[:warning]).to eq(described_class::NARROWED_NOTICE)
        expect(flash.now[:error]).to be_nil
        expect(assigns(:results)).to be_present
        expect(assigns(:comparison_productions)).to eq([comparison])
        page = Capybara.string(response.body)
        expect(page).to have_css('.flash_warning', exact_text: described_class::NARROWED_NOTICE, normalize_ws: true)
        table_rows = page.all('#rate-of-sales-results table.hover tbody tr').map { |row| row.text.squish }
        expect(table_rows.count).to eq(2)
        expect(table_rows.last).to include(comparison.name)
        expect(page).not_to have_text(unreadable.name)
        expect(page).not_to have_text('ROS Other Theater')
      end

      it 'asks for a comparison show, without the warning, when no comparison is readable' do
        use_real_ability(theater_user)

        get :rate_of_sales, params: { target_production_id: target.id.to_s,
                                      comparison_production_ids: [unreadable.id.to_s] }

        expect(response).to have_http_status(:ok)
        expect(flash.now[:error]).to eq('Select at least one comparison show.')
        expect(flash.now[:warning]).to be_nil
        expect(assigns(:results)).to be_nil
        page = Capybara.string(response.body)
        expect(page).to have_css('.flash_error', exact_text: 'Select at least one comparison show.', normalize_ws: true)
        expect(page).not_to have_css('.flash_warning')
        expect(page).not_to have_text(described_class::NARROWED_NOTICE)
      end

      it 'does not warn an administrator, who can read every show' do
        get :rate_of_sales, params: { target_production_id: target.id.to_s,
                                      comparison_production_ids: [comparison.id.to_s, unreadable.id.to_s] }

        expect(flash.now[:warning]).to be_nil
        expect(assigns(:comparison_productions)).to contain_exactly(comparison, unreadable)
        expect(response.body).not_to include(described_class::NARROWED_NOTICE)
      end
    end
  end

  describe 'GET #ticket_revenue' do
    render_views

    let(:admin) { FactoryBot.create(:admin_user) }
    let(:target_performance) { make_performance(theater, season: 2026, on: Date.current - 5.days) }
    let(:target) { target_performance.production }
    let(:comparison_performance) { make_performance(theater, season: 2025, on: Date.current - 400.days) }
    let(:comparison) { comparison_performance.production }

    before { use_real_ability(admin) }

    it 'renders the form with no results when nothing has been submitted' do
      get :ticket_revenue

      expect(response).to have_http_status(:ok)
      page = Capybara.string(response.body)
      expect(page).to have_css('form#ticket-revenue-form')
      expect(page).to have_button('Run analysis', disabled: true)
      expect(page).not_to have_css('#ticket-revenue-results')
      expect(page).to have_css('#analysis-tabs li.tabs-title.is-active', text: 'Ticket Revenue')
      expect(assigns(:target_result)).to be_nil
    end

    it 'renders results for a current show with no comparison' do
      sell(target_performance, tickets: 2, days_before: 3)

      get :ticket_revenue, params: { target_production_id: target.id.to_s, comparison_production_id: '' }

      expect(response).to have_http_status(:ok)
      expect(assigns(:comparison_result)).to be_nil
      page = Capybara.string(response.body)
      expect(page).to have_css('#ticket-revenue-results')
      expect(page).to have_css("form#ticket-revenue-form input[name='target_production_id'][value='#{target.id}']",
                               visible: :all)
    end

    it 'renders results against a comparison, keeping both picks in the form' do
      sell(target_performance, tickets: 2, days_before: 3)
      sell(comparison_performance, tickets: 4, days_before: 3)

      get :ticket_revenue, params: { target_production_id: target.id.to_s, comparison_production_id: comparison.id.to_s }

      expect(assigns(:comparison_result)).to be_present
      page = Capybara.string(response.body)
      expect(page).to have_css('#ticket-revenue-results')
      expect(page).to have_css("input[name='target_production_id'][value='#{target.id}']", visible: :all)
      expect(page).to have_css("input[name='comparison_production_id'][value='#{comparison.id}']", visible: :all)
    end

    it 'asks for a current show when the form was submitted without one' do
      get :ticket_revenue, params: { target_production_id: '', comparison_production_id: '' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Select a current show.')
      expect(Capybara.string(response.body)).not_to have_css('#ticket-revenue-results')
    end

    it 'says so when the submitted production cannot be found' do
      get :ticket_revenue, params: { target_production_id: '0' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('That production could not be found.')
      expect(Capybara.string(response.body)).not_to have_css('#ticket-revenue-results')
    end

    describe 'a bookmark naming a comparison outside the user’s theaters' do
      let(:other_theater) { FactoryBot.create(:theater, name: 'TR Other Theater') }
      let(:unreadable) { make_performance(other_theater, season: 2025, on: Date.current - 400.days).production }
      let(:theater_user) { FactoryBot.create(:user, theaters: [theater]) }

      before { sell(target_performance, tickets: 2, days_before: 3) }

      it 'warns a theater user and shows the current show on its own' do
        use_real_ability(theater_user)

        get :ticket_revenue, params: { target_production_id: target.id.to_s,
                                       comparison_production_id: unreadable.id.to_s }

        expect(response).to have_http_status(:ok)
        expect(flash.now[:warning]).to eq(described_class::NARROWED_NOTICE)
        expect(assigns(:target_result)).to be_present
        expect(assigns(:comparison_production)).to be_nil
        expect(assigns(:comparison_result)).to be_nil
        page = Capybara.string(response.body)
        expect(page).to have_css('.flash_warning', exact_text: described_class::NARROWED_NOTICE, normalize_ws: true)
        expect(page).to have_css('#ticket-revenue-results')
        expect(page).not_to have_css('#comparison-bucket-chart')
        expect(page.all('#ticket-revenue-results table.hover').first.all('thead th').count).to eq(2)
        expect(page).not_to have_text(unreadable.name)
      end

      it 'does not warn a theater user whose comparison is readable' do
        use_real_ability(theater_user)
        sell(comparison_performance, tickets: 4, days_before: 3)

        get :ticket_revenue, params: { target_production_id: target.id.to_s,
                                       comparison_production_id: comparison.id.to_s }

        expect(flash.now[:warning]).to be_nil
        expect(assigns(:comparison_result)).to be_present
        expect(response.body).not_to include(described_class::NARROWED_NOTICE)
      end

      it 'does not warn an administrator, who can read every show' do
        get :ticket_revenue, params: { target_production_id: target.id.to_s,
                                       comparison_production_id: unreadable.id.to_s }

        expect(flash.now[:warning]).to be_nil
        expect(assigns(:comparison_production)).to eq(unreadable)
        expect(response.body).not_to include(described_class::NARROWED_NOTICE)
      end
    end
  end

  describe 'GET #audience' do
    render_views

    let(:admin) { FactoryBot.create(:admin_user) }
    let(:target_performance) { make_performance(theater, season: 2026, on: Date.current - 5.days) }
    let(:target) { target_performance.production }

    before { use_real_ability(admin) }

    it 'renders the form with no results when nothing has been submitted' do
      get :audience

      expect(response).to have_http_status(:ok)
      page = Capybara.string(response.body)
      expect(page).to have_css('form#audience-form')
      expect(page).to have_button('Run analysis', disabled: true)
      expect(page).not_to have_css('#audience-results')
      expect(page).to have_css('#analysis-tabs li.tabs-title.is-active', text: 'Audience')
      expect(assigns(:results)).to be_nil
    end

    it 'renders results below the form, which keeps the picks' do
      sell(target_performance, tickets: 2, days_before: 3)

      get :audience, params: { target_production_id: target.id.to_s, comparison_theater_ids: [theater.id.to_s] }

      expect(response).to have_http_status(:ok)
      expect(assigns(:results)).to be_present
      page = Capybara.string(response.body)
      expect(page).to have_css('#audience-results')
      expect(page).to have_css("form#audience-form input[name='target_production_id'][value='#{target.id}']",
                               visible: :all)
      expect(page).to have_css("form#audience-form input[name='comparison_theater_ids[]'][value='#{theater.id}']",
                               visible: :all)
    end

    it 'pre-fills the form without running when only a current show is given' do
      get :audience, params: { target_production_id: target.id.to_s }

      expect(response).to have_http_status(:ok)
      expect(flash.now[:error]).to be_nil
      expect(assigns(:results)).to be_nil
      page = Capybara.string(response.body)
      expect(page).not_to have_css('#audience-results')
      expect(page).to have_css("form#audience-form input[name='target_production_id'][value='#{target.id}']",
                               visible: :all)
    end

    it 'asks for a current show when the form was submitted without one' do
      get :audience, params: { target_production_id: '', comparison_theater_ids: ['', theater.id.to_s] }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Select a current show.')
      expect(assigns(:results)).to be_nil
      expect(Capybara.string(response.body)).not_to have_css('#audience-results')
    end

    it 'asks for a comparison theater when none was submitted' do
      get :audience, params: { target_production_id: target.id.to_s, comparison_theater_ids: [''] }

      expect(response).to have_http_status(:ok)
      message = 'Select at least one comparison theater before running an audience analysis.'
      expect(flash.now[:error]).to eq(message)
      expect(response.body).to include(message)
      expect(assigns(:results)).to be_nil
      expect(Capybara.string(response.body)).not_to have_css('#audience-results')
    end

    it 'says so when the submitted production cannot be found' do
      get :audience, params: { target_production_id: '0', comparison_theater_ids: [theater.id.to_s] }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('That production could not be found.')
      expect(Capybara.string(response.body)).not_to have_css('#audience-results')
    end

    describe 'a bookmark naming theaters outside the user’s own' do
      let(:other_theater) { FactoryBot.create(:theater, name: 'AU Other Theater') }
      let(:theater_user) { FactoryBot.create(:user, theaters: [theater]) }

      before { sell(target_performance, tickets: 2, days_before: 3) }

      it 'warns a theater user and runs on the readable comparison theaters only' do
        use_real_ability(theater_user)

        get :audience, params: { target_production_id: target.id.to_s,
                                 comparison_theater_ids: [theater.id.to_s, other_theater.id.to_s] }

        expect(response).to have_http_status(:ok)
        expect(flash.now[:warning]).to eq(described_class::NARROWED_NOTICE)
        expect(flash.now[:error]).to be_nil
        expect(assigns(:comparison_theaters)).to eq([theater])
        expect(assigns(:results)).to be_present
        page = Capybara.string(response.body)
        expect(page).to have_css('.flash_warning', exact_text: described_class::NARROWED_NOTICE, normalize_ws: true)
        expect(page).to have_css('#audience-results')
        expect(page).not_to have_text('AU Other Theater')
      end

      it 'runs a single-theater user on their own theater, with the warning, when none named is readable' do
        use_real_ability(theater_user)

        get :audience, params: { target_production_id: target.id.to_s, comparison_theater_ids: [other_theater.id.to_s] }

        expect(flash.now[:error]).to be_nil
        expect(flash.now[:warning]).to eq(described_class::NARROWED_NOTICE)
        expect(assigns(:comparison_theaters)).to eq([theater])
        expect(assigns(:results)).to be_present
        page = Capybara.string(response.body)
        expect(page).to have_css('.flash_warning', exact_text: described_class::NARROWED_NOTICE, normalize_ws: true)
        expect(page).not_to have_css('.flash_error')
        expect(page).to have_css('#audience-results')
        expect(page).not_to have_text('AU Other Theater')
      end

      it 'asks a multi-theater user for a comparison theater, without the warning, when none is readable' do
        use_real_ability(FactoryBot.create(:user, theaters: [theater, FactoryBot.create(:theater)]))

        get :audience, params: { target_production_id: target.id.to_s, comparison_theater_ids: [other_theater.id.to_s] }

        message = 'Select at least one comparison theater before running an audience analysis.'
        expect(flash.now[:error]).to eq(message)
        expect(flash.now[:warning]).to be_nil
        expect(assigns(:results)).to be_nil
        page = Capybara.string(response.body)
        expect(page).to have_css('.flash_error', exact_text: message, normalize_ws: true)
        expect(page).not_to have_css('.flash_warning')
      end

      it 'does not warn an administrator, who can read every theater' do
        get :audience, params: { target_production_id: target.id.to_s,
                                 comparison_theater_ids: [theater.id.to_s, other_theater.id.to_s] }

        expect(flash.now[:warning]).to be_nil
        expect(assigns(:comparison_theaters)).to contain_exactly(theater, other_theater)
        expect(assigns(:results)).to be_present
      end
    end

    describe 'the comparison picker for a user who can read one theater' do
      before do
        sell(target_performance, tickets: 2, days_before: 3)
        use_real_ability(FactoryBot.create(:user, theaters: [theater]))
      end

      it 'is not rendered, nor its seeding script, but the submission marker is' do
        get :audience

        page = Capybara.string(response.body)
        expect(page).not_to have_css('.theater-multi-picker', visible: :all)
        expect(page).not_to have_css('form#audience-form legend', text: 'Comparison group')
        expect(page).to have_css('form#audience-form input[type="hidden"][name="comparison_theater_ids[]"][value=""]',
                                 visible: :all)
        expect(response.body).not_to include('theater-multi-picker:add')
      end

      it 'enables Run as soon as the current show is given' do
        get :audience, params: { target_production_id: target.id.to_s }

        expect(Capybara.string(response.body)).to have_button('Run analysis', disabled: false)
      end

      it 'runs against that theater when the form names no comparison theater' do
        get :audience, params: { target_production_id: target.id.to_s, comparison_theater_ids: [''] }

        expect(flash.now[:error]).to be_nil
        expect(flash.now[:warning]).to be_nil
        expect(assigns(:comparison_theaters)).to eq([theater])
        expect(assigns(:results)).to be_present
        page = Capybara.string(response.body)
        expect(page).to have_css('#audience-results')
        expect(page).to have_css('#audience-results p.help-text', text: "Comparison group: #{theater.name}",
                                                                  normalize_ws: true)
        expect(page).not_to have_css('.flash_error')
        expect(page).not_to have_css('.flash_warning')
      end
    end

    it 'renders the comparison picker for a theater user with two theaters' do
      second = FactoryBot.create(:theater, name: 'AU Second Theater')
      use_real_ability(FactoryBot.create(:user, theaters: [theater, second]))

      get :audience

      expect(Capybara.string(response.body)).to have_css('#audience-form .theater-multi-picker', visible: :all)
    end

    it 'renders the comparison picker for an administrator' do
      get :audience

      expect(Capybara.string(response.body)).to have_css('#audience-form .theater-multi-picker', visible: :all)
    end
  end
end
