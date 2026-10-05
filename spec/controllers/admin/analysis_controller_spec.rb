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
end
