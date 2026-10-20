# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::AddressMergesController, type: :controller do
  render_views

  let!(:house) { Theater.default_theater || FactoryBot.create(:theater, theater_class: Theater::DEFAULT) }
  let(:admin_user) { FactoryBot.create(:admin_user) }

  before do
    allow(controller).to receive(:current_user).and_return(admin_user)
    allow(Resque).to receive(:enqueue)
  end

  def address(**attributes)
    FactoryBot.create(:address, **attributes)
  end

  # The th of the second thead row, one per customer, holding its Exclude/Include button.
  def button_row
    Nokogiri::HTML(response.body).css('table.address-merge thead tr')[1].css('th').drop(1)
  end

  def radios(field)
    response.body.scan(/<input[^>]*type="radio"[^>]*name="choices\[#{field}\]"[^>]*>/)
  end

  describe 'GET #new' do
    let!(:older) { address(full_name: 'Glen Kosalko', email: 'k@example.com', phone: '555-0001') }
    let!(:newer) { address(full_name: 'Beth Kosalko', email: 'K@example.com ', phone: '555-0002') }

    it 'shows one column per customer and radios only for fields whose values differ' do
      get :new, params: { ids: [newer.id, older.id] }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Merge customers', "##{older.id} Glen Kosalko</a> (master, kept)",
                                       %(href="#{admin_address_path(newer)}"), "Merge into ##{older.id}")
      expect(radios(:name).size).to eq(2)
      expect(radios(:phone).size).to eq(2)
      expect(radios(:email)).to be_empty
      expect(radios(:address)).to be_empty
      expect(radios(:name).find { |radio| radio.include?(%(value="#{newer.id}")) }).to include('checked')
      expect(response.body).to include('callout warning', 'different first names (Glen, Beth)')
      expect(response.body).not_to include('Check the constituent in LGL')
      expect(response.body).to include("Keeps ##{older.id} and deletes ##{newer.id}.",
                                       "Name and phone come from ##{newer.id}.")
      expect(response.body).to include(%(href="#{admin_addresses_path}"))
    end

    it 'shows the LGL link, the LGL sentence and the re-link for an LGL Review merge' do
      allow(Lgl).to receive(:enabled?).and_return(true)
      allow(Lgl).to receive(:constituent_url).with(900_002).and_return('https://lgl.example.com/constituents/900002')

      get :new, params: { ids: [older.id, newer.id], constituent_id: '900002' }

      expect(response.body).to include('View in LGL', 'href="https://lgl.example.com/constituents/900002"',
                                       'Check the constituent in LGL before merging.',
                                       "Re-links LGL constituent 900002 to ##{older.id}.",
                                       'name="constituent_id"', %(href="#{admin_lgl_sync_path}"))
      expect(response.body).to include('LGL constituent <a target="_blank" rel="noopener" ' \
                                       'href="https://lgl.example.com/constituents/900002">900002</a>')
    end

    it 'puts each differing LGL constituent link after its radio label, not inside it' do
      allow(Lgl).to receive(:constituent_url) { |id| "https://lgl.example.com/constituents/#{id}" }
      older.set_lgl_id!(11)
      newer.set_lgl_id!(22)

      get :new, params: { ids: [older.id, newer.id] }

      expect(radios(:lgl_id).size).to eq(2)
      expect(response.body).to match(%r{</label> <a target="_blank" rel="noopener" href="https://lgl.example.com/constituents/22">22</a>})
      expect(response.body).not_to match(%r{<label[^>]*>(?:(?!</label>).)*constituents/22}m)
    end

    it 'shows no warning and says what moves for one person' do
      same = address(full_name: 'Glen K', email: 'k@example.com', phone: '555-0001')
      FactoryBot.create(:membership, address: same)

      get :new, params: { ids: [older.id, same.id] }

      expect(response.body).not_to include('callout warning')
      expect(response.body).to include('1 membership moves to', 'Active member', 'Donor', 'Orders')
    end

    it 'shows a Last order row with each customer\'s newest order date or a dash' do
      FactoryBot.create(:donation_order, address: older, theater: house)
                .update_column(:created_at, Time.zone.local(2026, 10, 20, 12))

      get :new, params: { ids: [newer.id, older.id] }

      row = response.body[%r{<th>Last order</th>.*?</tr>}m]
      expect(row).to be_present
      expect(row.scan(%r{<td>(.*?)</td>}m).flatten).to contain_exactly('October 20, 2026', '—')
    end

    context 'with a third customer' do
      let!(:third) { address(full_name: 'Gail Kosalko', email: 'g@example.com', phone: '555-0003') }

      it 'greys an excluded customer, offers to include it and gives it no radio' do
        get :new, params: { ids: [older.id, newer.id, third.id], excluded: [newer.id] }

        expect(response).to have_http_status(:ok)
        include_path = new_admin_address_merge_path(ids: [older.id, newer.id, third.id])
        include_link = %(href="#{ERB::Util.html_escape(include_path)}">Include</a>)
        expect(response.body).to match(%r{<th class='excluded'><a [^>]*>##{newer.id} Beth Kosalko</a></th>})
        excluded_th, merged_ths = button_row.partition { |th| th['class'] == 'excluded' }
        expect(excluded_th.size).to eq(1)
        expect(excluded_th.first.to_html).to include(include_link)
        expect(merged_ths.map { |th| th.text.strip }).to eq(%w[Exclude Exclude])
        expect(response.body.scan("<th class='excluded'>").size).to eq(2)
        expect(radios(:name).size).to eq(2)
        expect(radios(:name)).to all(satisfy { |radio| radio.exclude?(%(value="#{newer.id}")) })
        expect(response.body).to match(/<input[^>]*type="hidden"[^>]*name="excluded\[\]"[^>]*value="#{newer.id}"/)
        expect(response.body.scan('name="excluded[]"').size).to eq(1)
        expect(response.body).to include("Keeps ##{older.id} and deletes ##{third.id}.", "Leaves ##{newer.id} alone.")
      end

      it 'shows an Exclude link on each column when three customers are merged' do
        get :new, params: { ids: [older.id, newer.id, third.id] }

        expect(response.body.scan(%r{>Exclude</a>}).size).to eq(3)
        expect(response.body).not_to include('>Include</a>', "class='excluded'", 'alone.')
      end
    end

    it 'shows a disabled Exclude button on each column when only two customers are merged' do
      get :new, params: { ids: [older.id, newer.id] }

      expect(button_row.size).to eq(2)
      buttons = button_row.map { |th| th.at_css('span.button') }
      expect(buttons.map(&:text)).to eq(%w[Exclude Exclude])
      expect(buttons).to all(satisfy { |b| b['class'].include?('disabled') && b['href'].nil? })
      expect(response.body).not_to include('>Exclude</a>', '>Include</a>')
    end

    it 'redirects back with the error for one customer' do
      request.env['HTTP_REFERER'] = admin_addresses_url(search: 'Kosalko')

      get :new, params: { ids: [older.id] }

      expect(response).to redirect_to(admin_addresses_url(search: 'Kosalko'))
      expect(flash[:alert]).to eq('Choose 2 to 4 customers to merge (got 1)')
    end

    it 'redirects to the LGL page, not back to itself, when the referrer is this page' do
      request.env['HTTP_REFERER'] = new_admin_address_merge_url(ids: [older.id, newer.id], constituent_id: 900_002)

      get :new, params: { ids: [older.id], constituent_id: '900002' }

      expect(response).to redirect_to(admin_lgl_sync_path)
    end

    it 'redirects to the Customers page with the error for five customers' do
      ids = [older.id, newer.id] + Array.new(3) { address.id }

      get :new, params: { ids: ids }

      expect(response).to redirect_to(admin_addresses_path)
      expect(flash[:alert]).to eq('Choose 2 to 4 customers to merge (got 5)')
    end

    it 'refuses a box office user' do
      allow(controller).to receive(:current_user).and_return(FactoryBot.create(:user, is_box_office_user: true))

      get :new, params: { ids: [older.id, newer.id] }

      expect(response).to redirect_to(root_path)
    end
  end

  describe 'POST #create' do
    let!(:older) { address(full_name: 'Pat Older', email: 'pat@old.example.com') }
    let!(:newer) { address(full_name: 'Patricia Newer', email: 'pat@new.example.com') }

    it 'merges with the chosen values and redirects to the kept customer' do
      newer.lgl_review!('No LGL match')

      post :create, params: { ids: [older.id, newer.id], choices: { name: older.id.to_s, email: newer.id.to_s } }

      expect(Address.exists?(newer.id)).to be(false)
      expect(older.reload.attributes.slice('full_name', 'email'))
        .to eq('full_name' => 'Pat Older', 'email' => 'pat@new.example.com')
      expect(older.lgl_review_reason).to be_nil
      expect(Resque).not_to have_received(:enqueue)
      expect(response).to redirect_to(admin_address_path(older))
      expect(flash[:notice]).to eq("Merged 2 customers into ##{older.id}")
    end

    it 'queues the re-link and returns to the LGL page for an LGL Review merge' do
      allow(Lgl).to receive(:enabled?).and_return(true)

      post :create, params: { ids: [older.id, newer.id], constituent_id: '900002' }

      expect(Address.exists?(newer.id)).to be(false)
      expect(Resque).to have_received(:enqueue).with(LglSyncAddressJob, older.id, LglSyncAddressJob::LINK_TRIGGER)
      expect(response).to redirect_to(admin_lgl_sync_path)
      expect(flash[:notice]).to eq("Merged 2 customers into ##{older.id}; re-linking to LGL constituent 900002")
    end

    it 'goes to the kept customer without a re-link when LGL is not configured' do
      allow(Lgl).to receive(:enabled?).and_return(false)

      post :create, params: { ids: [older.id, newer.id], constituent_id: '900002' }

      expect(Resque).not_to have_received(:enqueue)
      expect(response).to redirect_to(admin_address_path(older))
    end

    it 'still reports the merge, and says to Re-sync, when the re-link cannot be queued' do
      allow(Lgl).to receive(:enabled?).and_return(true)
      allow(Resque).to receive(:enqueue).and_raise(Redis::CannotConnectError, 'Connection refused')
      allow(Rails.logger).to receive(:error)

      post :create, params: { ids: [older.id, newer.id], constituent_id: '900002' }

      expect(Address.exists?(newer.id)).to be(false)
      expect(Rails.logger).to have_received(:error).with(/re-link of ##{older.id}: .*Connection refused/)
      expect(flash[:notice]).to eq(
        "Merged 2 customers into ##{older.id}, but re-linking to LGL constituent 900002 could not be queued: " \
        "use Re-sync on the customer's page"
      )
    end

    it 'returns to the page with the error for a choice outside the set' do
      post :create, params: { ids: [older.id, newer.id], choices: { name: '999999999' } }

      expect(Address.exists?(newer.id)).to be(true)
      expect(response).to redirect_to(new_admin_address_merge_path(ids: [older.id.to_s, newer.id.to_s]))
      expect(flash[:alert]).to eq('Customer #999999999 for name is not one of the customers being merged')
    end

    context 'with a third customer excluded' do
      let!(:excluded) { address(full_name: 'Pat Other', email: 'pat@other.example.com') }
      let(:ids) { [older.id, newer.id, excluded.id] }
      let(:lgl_merged_notice) do
        "Merged 2 customers into ##{older.id}; re-linking to LGL constituent 900002"
      end

      before { excluded.lgl_review!('No LGL match') }

      it 'merges the others, clears the excluded LGL Review and re-syncs it after the re-link' do
        allow(Lgl).to receive(:enabled?).and_return(true)

        post :create, params: { ids: ids, excluded: [excluded.id], constituent_id: '900002' }

        expect(Address.exists?(newer.id)).to be(false)
        expect(Address.exists?(excluded.id)).to be(true)
        expect(excluded.reload.lgl_review_reason).to be_nil
        expect(Resque).to have_received(:enqueue).with(LglSyncAddressJob, older.id, LglSyncAddressJob::LINK_TRIGGER).ordered
        expect(Resque).to have_received(:enqueue)
          .with(LglSyncAddressJob, excluded.id, LglSyncAddressJob::MANUAL_TRIGGER).ordered
        expect(Resque).to have_received(:enqueue).twice
        expect(response).to redirect_to(admin_lgl_sync_path)
        expect(flash[:notice]).to eq("#{lgl_merged_notice}; re-syncing ##{excluded.id}")
      end

      it 'still reports the merge, and says to Re-sync, when the excluded re-sync cannot be queued' do
        allow(Lgl).to receive(:enabled?).and_return(true)
        allow(Resque).to receive(:enqueue) do |_job, id, _trigger|
          raise Redis::CannotConnectError, 'Connection refused' if id == excluded.id
        end
        allow(Rails.logger).to receive(:error)

        post :create, params: { ids: ids, excluded: [excluded.id], constituent_id: '900002' }

        expect(Address.exists?(newer.id)).to be(false)
        expect(Address.exists?(excluded.id)).to be(true)
        expect(Resque).to have_received(:enqueue).with(LglSyncAddressJob, older.id, LglSyncAddressJob::LINK_TRIGGER)
        expect(Rails.logger).to have_received(:error).with(/re-sync excluded ##{excluded.id}: .*Connection refused/)
        expect(response).to redirect_to(admin_lgl_sync_path)
        expect(flash[:notice]).to eq(
          "#{lgl_merged_notice}; re-syncing ##{excluded.id} could not be queued: use Re-sync on the customer's page"
        )
      end

      it 'leaves the excluded customer untouched and goes to the kept customer without an LGL Review' do
        post :create, params: { ids: ids, excluded: [excluded.id] }

        expect(Address.exists?(newer.id)).to be(false)
        expect(excluded.reload.lgl_review_reason).to eq('No LGL match')
        expect(excluded.email).to eq('pat@other.example.com')
        expect(Resque).not_to have_received(:enqueue)
        expect(response).to redirect_to(admin_address_path(older))
        expect(flash[:notice]).to eq("Merged 2 customers into ##{older.id}")
      end

      it 'returns to the page, still excluding, for a choice naming the excluded customer' do
        post :create, params: { ids: ids, excluded: [excluded.id], choices: { name: excluded.id.to_s } }

        expect(Address.exists?(newer.id)).to be(true)
        expect(response).to redirect_to(new_admin_address_merge_path(ids: ids.map(&:to_s), excluded: [excluded.id.to_s]))
        expect(flash[:alert]).to eq("Customer ##{excluded.id} for name is not one of the customers being merged")
      end
    end

    it 'logs a failed merge, changes nothing and returns to the page' do
      allow_any_instance_of(Address).to receive(:merge_and_purge).and_raise(ActiveRecord::RecordNotDestroyed, 'finalized orders')
      allow(Rails.logger).to receive(:error)

      post :create, params: { ids: [older.id, newer.id], constituent_id: '900002' }

      expect(Address.exists?(newer.id)).to be(true)
      expect(Rails.logger).to have_received(:error).with(/failed: ActiveRecord::RecordNotDestroyed: finalized orders\n/)
      expect(Resque).not_to have_received(:enqueue)
      expect(response).to redirect_to(new_admin_address_merge_path(ids: [older.id.to_s, newer.id.to_s],
                                                                   constituent_id: 900_002))
      expect(flash[:alert]).to eq('Merge failed. See server log.')
    end

    it 'refuses a box office user without merging' do
      allow(controller).to receive(:current_user).and_return(FactoryBot.create(:user, is_box_office_user: true))

      post :create, params: { ids: [older.id, newer.id] }

      expect(Address.exists?(newer.id)).to be(true)
      expect(response).to redirect_to(root_path)
    end
  end
end
