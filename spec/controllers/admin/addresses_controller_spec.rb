require 'rails_helper'

RSpec.describe Admin::AddressesController, type: :controller do
  render_views

  let(:admin_user) { FactoryBot.create(:admin_user) }

  before do
    allow(controller).to receive(:current_user).and_return(admin_user)
  end

  describe '#index' do
    it 'puts a search term from the query string on the table for the DataTable to apply' do
      get :index, params: { search: 'Reviewme' }

      table_tag = response.body[/<table[^>]*\bid=['"]address-listing['"][^>]*>/]
      expect(table_tag).to match(/data-search=['"]Reviewme['"]/)
    end

    it 'points Merge Selected at the Merge customers page and caps the selection' do
      get :index

      table_tag = response.body[/<table[^>]*\bid=['"]address-listing['"][^>]*>/]
      expect(table_tag).to match(/data-merge-url=['"]#{Regexp.escape(new_admin_address_merge_path)}['"]/)
      expect(table_tag).to match(/data-merge-max=['"]#{Address::ManualMerge::MAX_RECORDS}['"]/)
    end

    it 'puts no search term on the table without one' do
      get :index

      table_tag = response.body[/<table[^>]*\bid=['"]address-listing['"][^>]*>/]
      expect(table_tag).to be_present
      expect(table_tag).not_to include('data-search')
    end
  end

  describe '#show' do
    let(:membership_order) { FactoryBot.create(:membership_order) }
    let(:address) { membership_order.address }
    let(:membership) { membership_order.membership_line_item.membership }
    # A theater user may read a customer only through an order at one of their theaters.
    let(:readable_order) { FactoryBot.create(:ticket_order, address: address) }
    let(:readable_order_theater) { readable_order.performance.production.theater }

    it 'links each active member code to its membership order' do
      get :show, params: { id: address.id }

      expect(response.body).to include('Active Memberships')
      expect(response.body).to include(
        %(<a href="#{admin_membership_order_path(membership_order)}">#{membership.member_code}</a>)
      )
    end

    it 'links an active membership issued without an order to the membership itself' do
      issued = FactoryBot.create(:membership, address: address, member_code: 'NOORDER1',
                                              membership_offer: membership.membership_offer)

      get :show, params: { id: address.id }

      expect(response.body).to include(%(<a href="#{admin_membership_path(issued)}">NOORDER1</a>))
    end

    it 'offers no Issue Membership button; memberships come from orders or Issue Pass' do
      get :show, params: { id: address.id }

      expect(response.body).not_to include('Issue Membership', new_admin_membership_path)
    end

    it 'shows only the current fiscal year donor tier as a green label above the tag list' do
      address.update!(donor_tier_for_current_fiscal_year: 'Gold', donor_tier_for_last_fiscal_year: nil)

      get :show, params: { id: address.id }

      body = response.body
      donor_labels = body[%r{<div class=['"]donor-tier-labels text-right['"]>.*?</div>}m]
      expect(donor_labels).to match(%r{<span class=['"]label success['"]>Current FY: Gold</span>})
      expect(donor_labels).not_to include('warning', 'Previous FY', 'none')
      expect(body.index('donor-tier-labels')).to be < body.index('<td>Tag</td>')
      expect(body.index('donor-tier-labels')).to be < body.index('Attended')
    end

    it 'shows the previous fiscal year tier in yellow before the current fiscal year tier in green' do
      address.update!(donor_tier_for_current_fiscal_year: 'Gold', donor_tier_for_last_fiscal_year: 'Silver')

      get :show, params: { id: address.id }

      donor_labels = response.body[%r{<div class=['"]donor-tier-labels text-right['"]>.*?</div>}m]
      previous_label = %r{<span class=['"]label warning['"]>Previous FY: Silver</span>}
      current_label = %r{<span class=['"]label success['"]>Current FY: Gold</span>}
      expect(donor_labels).to match(previous_label)
      expect(donor_labels).to match(current_label)
      expect(donor_labels.index(previous_label)).to be < donor_labels.index(current_label)
    end

    it 'shows no donor tier labels for a customer with no tier in either year' do
      address.update!(donor_tier_for_current_fiscal_year: nil, donor_tier_for_last_fiscal_year: nil)

      get :show, params: { id: address.id }

      expect(response.body).not_to include('donor-tier-labels', 'Current FY', 'Previous FY')
    end

    it 'hides active memberships and donor tier labels from a theater user but still shows the tag list' do
      theater_user = FactoryBot.create(:user, theaters: [readable_order_theater])
      allow(controller).to receive(:current_user).and_return(theater_user)
      address.update!(donor_tier_for_current_fiscal_year: 'Gold', donor_tier_for_last_fiscal_year: 'Silver')
      expect(address.is_current_member?).to be(true)

      get :show, params: { id: address.id }

      expect(response.body).to include('<td>Tag</td>')
      expect(response.body).not_to include('Active Memberships', membership.member_code)
      expect(response.body).not_to include('donor-tier-labels', 'Current FY', 'Previous FY')
    end

    context 'when the customer attended productions at two theaters' do
      let(:own_production) { readable_order.performance.production }
      let!(:other_production) do
        FactoryBot.create(:production, theater: FactoryBot.create(:theater), name: 'Elsewhere Show')
      end

      before { address.productions << [own_production, other_production] }

      it 'lists only productions at the theater user\'s theaters' do
        theater_user = FactoryBot.create(:user, theaters: [readable_order_theater])
        allow(controller).to receive(:current_user).and_return(theater_user)

        get :show, params: { id: address.id }

        expect(response.body).to include('1 Production Attended', own_production.name)
        expect(response.body).not_to include('Elsewhere Show')
      end

      it 'lists every attended production for staff' do
        get :show, params: { id: address.id }

        expect(response.body).to include('2 Productions Attended', own_production.name, 'Elsewhere Show')
      end
    end

    it 'highlights the LGL Review tag in the tag list' do
      Theater.default_theater || FactoryBot.create(:theater, theater_class: Theater::DEFAULT)
      allow(Lgl).to receive(:enabled?).and_return(true)
      address.lgl_review!('LGL constituent 1234 matches several customers by email and last name')

      get :show, params: { id: address.id }

      review_row = response.body[%r{<tr class=['"]lgl-review['"]>.*?</tr>}m]
      expect(review_row).to include('LGL Review', 'matches several customers by email and last name')
      expect(response.body).not_to include('LGL review:')
    end
  end

  describe '#update' do
    it 'truly merges when an edit makes the record match an existing one' do
      keeper = FactoryBot.create(:address, full_name: 'Merged Patron', email: 'merged@example.com')
      edited = FactoryBot.create(:address, full_name: 'Merged Patron-typo', email: 'merged@example.com')
      order = FactoryBot.create(:ticket_order, :for_a_single_ticket, address: edited)

      put :update, params: { id: edited.id, address: { full_name: 'Merged Patron' } }

      # The old behavior copied fields onto the match but abandoned the edited
      # record with all of its orders, leaving a permanent duplicate.
      expect(order.reload.address_id).to eq(keeper.id)
      expect(Address.exists?(edited.id)).to be(false)
      expect(response).to redirect_to(admin_address_path(keeper))
    end

    it 'updates normally when no duplicate exists' do
      address = FactoryBot.create(:address, full_name: 'Solo Patron', email: 'solo@example.com')

      put :update, params: { id: address.id, address: { full_name: 'Solo Patron Jr' } }

      expect(address.reload.full_name).to eq('Solo Patron Jr')
      expect(response).to redirect_to(admin_address_path(address))
    end
  end

  describe '#new' do
    it 'renders the customer form posting to the addresses path' do
      get :new

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('New Customer')
      expect(response.body).to match(/<form[^>]+action="#{Regexp.escape(admin_addresses_path)}"[^>]+method="post"/)
      expect(response.body).to include('Save Customer')
    end
  end

  describe '#create' do
    it 'creates an address from valid params' do
      expect do
        post :create, params: { address: { full_name: 'Brand New Patron', email: 'brandnew@example.com' } }
      end.to change(Address, :count).by(1)

      expect(response).to redirect_to(admin_address_path(Address.find_by(email: 'brandnew@example.com')))
    end
  end

  describe '#lgl_sync' do
    let!(:house) { Theater.default_theater || FactoryBot.create(:theater, theater_class: Theater::DEFAULT) }
    let(:address) { FactoryBot.create(:address) }

    before { allow(Resque).to receive(:enqueue) }

    context 'when LGL is enabled' do
      before { allow(Lgl).to receive(:enabled?).and_return(true) }

      it 'queues a manual sync and returns to the customer page' do
        post :lgl_sync, params: { id: address.id }

        expect(Resque).to have_received(:enqueue).with(LglSyncAddressJob, address.id, 'manual')
        expect(response).to redirect_to(admin_address_path(address))
        expect(flash[:notice]).to eq('Queued a sync with Little Green Light')
      end

      it 'refuses a box office user without queuing' do
        box_office = FactoryBot.create(:user, is_box_office_user: true)
        allow(controller).to receive(:current_user).and_return(box_office)

        post :lgl_sync, params: { id: address.id }

        expect(Resque).not_to have_received(:enqueue)
        expect(response).to redirect_to(root_path)
      end

      it 'refuses a theater user without queuing' do
        theater_user = FactoryBot.create(:user, theaters: [house])
        allow(controller).to receive(:current_user).and_return(theater_user)

        post :lgl_sync, params: { id: address.id }

        expect(Resque).not_to have_received(:enqueue)
        expect(response).to redirect_to(root_path)
      end

      it 'links the LGL ID tag value to the configured account beside the sync button' do
        address.set_lgl_id!(4321)
        allow(Lgl).to receive(:constituent_url).with('4321')
                                               .and_return('https://house.littlegreenlight.com/constituents/4321')

        get :show, params: { id: address.id }

        page = Nokogiri::HTML(response.body)
        lgl_id_row = page.css('tr').find { |row| row.css('td').first&.text&.strip == AddressTag::LGL_ID }
        expect(lgl_id_row).to be_present
        expect(lgl_id_row.to_html).to include('href="https://house.littlegreenlight.com/constituents/4321"')
        expect(lgl_id_row.to_html).to include('Re-sync with LGL', lgl_sync_admin_address_path(address))
      end

      it 'shows the LGL ID as plain text when no LGL web URL is configured' do
        address.set_lgl_id!(4321)

        get :show, params: { id: address.id }

        expect(response.body).to include('4321')
        expect(response.body).not_to include('littlegreenlight.com')
      end

      it 'shows the review reason for an unlinked address' do
        address.lgl_review!('LGL constituents 11 and 12 share this email')

        get :show, params: { id: address.id }

        review_row = response.body[%r{<tr class=['"]lgl-review['"]>.*?</tr>}m]
        expect(review_row).to include('LGL Review', 'LGL constituents 11 and 12 share this email')
      end

      it 'links each constituent the review reason names, leaving the customer id as text' do
        allow(Lgl).to receive(:constituent_url) { |id| "https://house.littlegreenlight.com/constituents/#{id}" }
        address.lgl_review!('LGL constituent 5512 is also linked to #77')

        get :show, params: { id: address.id }

        review_row = response.body[%r{<tr class=['"]lgl-review['"]>.*?</tr>}m]
        expect(review_row).to include(
          'LGL constituent <a target="_blank" rel="noopener" ' \
          'href="https://house.littlegreenlight.com/constituents/5512">5512</a> is also linked to #77'
        )
      end
    end

    context 'when LGL is disabled' do
      it 'redirects with an alert and queues nothing' do
        post :lgl_sync, params: { id: address.id }

        expect(Resque).not_to have_received(:enqueue)
        expect(response).to redirect_to(admin_address_path(address))
        expect(flash[:alert]).to be_present
      end

      it 'shows no Re-sync button on the customer page' do
        address.set_lgl_id!(4321)

        get :show, params: { id: address.id }

        expect(response.body).to include('4321')
        expect(response.body).not_to include('Re-sync with LGL')
      end
    end
  end
end
