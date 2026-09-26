require 'rails_helper'

RSpec.describe Admin::ResourcedTicketClassesController, type: :controller do
  let(:admin_user)   { FactoryBot.create(:admin_user) }
  let(:theater)      { FactoryBot.create(:theater) }
  let(:theater_user) { FactoryBot.create(:user, theaters: [theater]) }
  let(:venue)        { FactoryBot.create(:venue) }
  let(:other_venue)  { FactoryBot.create(:venue) }

  def valid_params(overrides = {})
    { class_code: 'TABLET', class_name: 'Captioning Tablet', ticket_type: 'Fixed',
      ticket_price: '0.00', ticketing_fee: '0.00', quantity: 2, changeover_minutes: 30,
      venue_ids: [venue.id] }.merge(overrides)
  end

  describe 'as an admin' do
    render_views

    before { allow(controller).to receive(:current_user).and_return(admin_user) }

    describe 'GET #index' do
      it 'renders the html index' do
        get :index
        expect(response).to have_http_status(:ok)
      end

      it 'renders the datatable json' do
        FactoryBot.create(:resourced_ticket_class, class_code: 'RESJSON', venues: [venue])

        get :index, format: :json
        payload = response.parsed_body
        codes = payload['data'].pluck('class_code')
        expect(codes.join).to include('RESJSON')
      end
    end

    describe 'GET #show' do
      it 'renders the resource' do
        resource = FactoryBot.create(:resourced_ticket_class, venues: [venue])

        get :show, params: { id: resource.id }
        expect(response).to have_http_status(:ok)
      end

      it 'renders the running-time and sync-status warnings once the sync has settled' do
        # Created before the resource exists, so Production#after_create's
        # assign_resourced_ticket_classes never sees this resource, and the
        # resource's own sync job (enqueued, not inline in test) never runs --
        # exactly the "never got a shadow row" state the show page should flag.
        #
        # Production#default_running_time pre-fills running_time from
        # server.yml on create, so the blank has to be forced back in after
        # save to exercise the nil-running_time warning branch too.
        no_runtime = FactoryBot.create(:production, venue: venue, theater: theater)
        no_runtime.update_column(:running_time, nil)
        FactoryBot.create(:performance, production: no_runtime, performance_date: Date.current + 30.days)

        resource = FactoryBot.create(:resourced_ticket_class, venues: [venue])
        # The create's after_commit marked a sync as pending; settle it so the
        # page reports real warnings instead of the syncing banner.
        resource.mark_sync_completed!

        get :show, params: { id: resource.id }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(no_runtime.production_code)
        expect(response.body).to include('Running time not set')
        expect(response.body).to include('Not synced')
      end

      it 'shows the syncing banner instead of conflict warnings while a sync is pending' do
        production = FactoryBot.create(:production, venue: venue, theater: theater)
        FactoryBot.create(:performance, production: production, performance_date: Date.current + 30.days)
        resource = FactoryBot.create(:resourced_ticket_class, venues: [venue])
        expect(resource).to be_syncing

        get :show, params: { id: resource.id }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('being synced')
        expect(response.body).not_to include('Not synced')
      end
    end

    describe 'GET #sync_status' do
      it 'reports the pending sync and its completion' do
        resource = FactoryBot.create(:resourced_ticket_class, venues: [venue])

        get :sync_status, params: { id: resource.id }
        expect(response.parsed_body).to eq('syncing' => true)

        resource.mark_sync_completed!
        get :sync_status, params: { id: resource.id }
        expect(response.parsed_body).to eq('syncing' => false)
      end
    end

    describe 'GET #new' do
      it 'renders ok' do
        get :new
        expect(response).to have_http_status(:ok)
      end
    end

    describe 'GET #edit' do
      it 'renders ok' do
        resource = FactoryBot.create(:resourced_ticket_class, venues: [venue])

        get :edit, params: { id: resource.id }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Admission type')
      end
    end

    describe 'POST #create' do
      it 'persists a new resourced ticket class with its venues' do
        expect do
          post :create, params: { resourced_ticket_class: valid_params }
        end.to change(ResourcedTicketClass, :count).by(1)

        created = ResourcedTicketClass.find_by(class_code: 'TABLET')
        expect(created.quantity).to eq(2)
        expect(created.changeover_minutes).to eq(30)
        expect(created.venue_ids).to eq([venue.id])
      end

      it 'saves the admission type' do
        post :create, params: { resourced_ticket_class: valid_params(admission: 'other') }

        expect(ResourcedTicketClass.find_by(class_code: 'TABLET').admission).to eq('other')
      end

      it 'rejects an invalid resource and re-renders new' do
        post :create, params: { resourced_ticket_class: valid_params(quantity: 0) }

        expect(response).to have_http_status(:ok)
        expect(ResourcedTicketClass.find_by(class_code: 'TABLET')).to be_nil
      end
    end

    describe 'PATCH #update' do
      # The model's after_commit on: :update enqueues SyncResourcedTicketClassJob
      # so every production in the (possibly changed) venue set gets a
      # freshly-attributed shadow row. Assigning venue_ids in the same #update
      # call (rather than a separate venues= + save) still fires exactly one
      # commit, so this asserts the single enqueue.
      it 'updates attributes and venues, enqueuing the sync job once' do
        resource = FactoryBot.create(:resourced_ticket_class, venues: [venue])

        expect(Resque).to receive(:enqueue).with(SyncResourcedTicketClassJob, resource.id).once

        patch :update, params: { id: resource.id,
                                 resourced_ticket_class: valid_params(class_name: 'Renamed Tablet',
                                                                      venue_ids: [other_venue.id]) }

        resource.reload
        expect(resource.class_name).to eq('Renamed Tablet')
        expect(resource.venue_ids).to eq([other_venue.id])
      end

      it 're-renders edit on failure' do
        resource = FactoryBot.create(:resourced_ticket_class, venues: [venue])

        patch :update, params: { id: resource.id, resourced_ticket_class: valid_params(class_name: '') }

        expect(response).to have_http_status(:ok)
        expect(resource.reload.class_name).not_to eq('')
      end
    end

    describe 'DELETE #destroy' do
      it 'destroys a resource with no sales' do
        resource = FactoryBot.create(:resourced_ticket_class, venues: [venue])

        expect { delete :destroy, params: { id: resource.id } }.to change(ResourcedTicketClass, :count).by(-1)
        expect(response).to redirect_to(admin_resourced_ticket_classes_url)
        expect(flash[:notice]).to be_present
      end

      it 'decommissions instead of deleting, and surfaces the model errors, when a shadow class has sales' do
        production = FactoryBot.create(:production, venue: venue, theater: theater, running_time: 120)
        performance = FactoryBot.create(:performance, production: production,
                                                      performance_date: Date.current + 30.days,
                                                      performance_time: Time.parse('19:00'))
        resource = FactoryBot.create(:resourced_ticket_class, venues: [venue])
        shadow = TicketClass.find_or_initialize_by(production_id: production.id,
                                                   resourced_ticket_class_id: resource.id)
        shadow.synced_from_resource = true
        shadow.attributes = resource.shadow_attributes
        shadow.save!
        TicketClassAllocation.find_or_create_by!(performance: performance, ticket_class: shadow)
                             .update!(available: true)
        performance.ticket_class_allocations.reload
        order = TicketOrder.new(status: Order::PROCESSED, performance: performance,
                                address: FactoryBot.create(:address),
                                payment_type: FactoryBot.create(:cash_payment_type))
        order.ticket_line_items << TicketLineItem.new(ticket_class: shadow, ticket_count: 1)
        order.save!

        expect { delete :destroy, params: { id: resource.id } }.not_to change(ResourcedTicketClass, :count)
        expect(response).to redirect_to(admin_resourced_ticket_classes_url)
        expect(flash[:error]).to include('already sold this equipment')

        shadow.reload
        expect(shadow.web_visible).to be false
        expect(shadow.auto_attach).to be false
      end
    end
  end

  describe 'as a theater user' do
    before { allow(controller).to receive(:current_user).and_return(theater_user) }

    it 'denies index access' do
      get :index
      expect(response).to redirect_to(root_url)
    end

    it 'denies create' do
      expect do
        post :create, params: { resourced_ticket_class: valid_params }
      end.not_to change(ResourcedTicketClass, :count)
      expect(response).to redirect_to(root_url)
    end

    it 'denies destroy' do
      resource = FactoryBot.create(:resourced_ticket_class, venues: [venue])

      expect { delete :destroy, params: { id: resource.id } }.not_to change(ResourcedTicketClass, :count)
      expect(response).to redirect_to(root_url)
    end
  end
end
