# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::AddressMergesHelper, type: :helper do
  let!(:house) { Theater.default_theater || FactoryBot.create(:theater, theater_class: Theater::DEFAULT) }
  let(:address) { FactoryBot.create(:address) }

  def order_created_at(created_at)
    FactoryBot.create(:donation_order, address: address, theater: house).tap do |order|
      order.update_column(:created_at, created_at)
    end
  end

  describe '#address_merge_last_order' do
    it 'shows a dash when the customer has no orders' do
      expect(helper.address_merge_last_order(address)).to eq('—')
    end

    it "shows the newest order's date in long format, never an older one" do
      order_created_at(Time.zone.local(2025, 12, 31, 12))
      order_created_at(Time.zone.local(2026, 10, 20, 12))
      order_created_at(Time.zone.local(2026, 10, 17, 12))

      expect(helper.address_merge_last_order(address)).to eq('October 20, 2026')
    end
  end

  describe 'excluded customers' do
    let!(:first) { FactoryBot.create(:address, full_name: 'Ann First', email: 'a@example.com') }
    let!(:second) { FactoryBot.create(:address, full_name: 'Bea Second', email: 'b@example.com') }
    let!(:third) { FactoryBot.create(:address, full_name: 'Cy Third', email: 'c@example.com') }
    let(:ids) { [first.id, second.id, third.id] }

    def merge(ids: self.ids, excluded: [])
      Address::ManualMerge.new(ids: ids, excluded: excluded)
    end

    def link_href(html, label)
      Nokogiri::HTML.fragment(html).css('a').find { |a| a.text == label }&.[]('href')
    end

    # The text of the disabled toggle button: a span, no href, aria-disabled.
    def disabled_button(html)
      span = Nokogiri::HTML.fragment(html).at_css('span.button.disabled')
      return unless span && span['href'].nil? && span['aria-disabled'] == 'true' && span['title'].nil?

      span.text
    end

    describe '#address_merge_header' do
      it 'gives an excluded customer only the linked name' do
        html = helper.address_merge_header(merge(excluded: [third.id]), third)

        expect(html).to eq(%(<a href="#{admin_address_path(third)}">##{third.id} Cy Third</a>))
      end

      it 'marks the master as kept, with no button' do
        html = helper.address_merge_header(merge, first)

        expect(html).to end_with("##{first.id} Ann First</a> (master, kept)")
        expect(html).not_to include('<br>', 'button')
      end

      it 'gives a merged customer that is not the master only the linked name' do
        html = helper.address_merge_header(merge, second)

        expect(html).to eq(%(<a href="#{admin_address_path(second)}">##{second.id} Bea Second</a>))
      end
    end

    describe '#address_merge_toggle_button' do
      it 'gives an excluded customer an Include link that drops it from excluded' do
        html = helper.address_merge_toggle_button(merge(excluded: [third.id]), third, constituent_id: 900_002)

        expect(html).not_to include('>Exclude</a>')
        expect(link_href(html, 'Include')).to eq(new_admin_address_merge_path(ids: ids, constituent_id: 900_002))
      end

      it 'gives the master an Exclude link that adds it to excluded' do
        html = helper.address_merge_toggle_button(merge, first)

        expect(link_href(html, 'Exclude')).to eq(new_admin_address_merge_path(ids: ids, excluded: [first.id]))
      end

      it 'gives a merged customer that is not the master an Exclude link carrying the constituent' do
        html = helper.address_merge_toggle_button(merge, second, constituent_id: 900_002)

        expect(link_href(html, 'Exclude'))
          .to eq(new_admin_address_merge_path(ids: ids, excluded: [second.id], constituent_id: 900_002))
      end

      it 'disables the Exclude buttons when only two customers are merged' do
        two_merged = merge(excluded: [third.id])

        [first, second].each do |address|
          html = helper.address_merge_toggle_button(two_merged, address)

          expect(disabled_button(html)).to eq('Exclude')
          expect(link_href(html, 'Exclude')).to be_nil
        end
      end

      it 'disables the Include button when four customers are already merged' do
        extra = Array.new(2) { FactoryBot.create(:address) }
        html = helper.address_merge_toggle_button(merge(ids: ids + extra.map(&:id), excluded: [third.id]), third)

        expect(disabled_button(html)).to eq('Include')
        expect(link_href(html, 'Include')).to be_nil
      end
    end

    describe '#address_merge_column_attributes' do
      it 'gives an excluded customer the excluded class and any other customer no attributes' do
        excluding = merge(excluded: [second.id])

        expect(helper.address_merge_column_attributes(excluding, second)).to eq(class: 'excluded')
        expect(helper.address_merge_column_attributes(excluding, first)).to eq({})
        expect(helper.address_merge_column_attributes(excluding, third)).to eq({})
      end
    end

    describe '#address_merge_cell' do
      def radio(html)
        Nokogiri::HTML.fragment(html).at_css('input[type=radio]')
      end

      it "shows a disabled, unchecked radio with no data attributes for an excluded customer's differing value" do
        excluding = merge(excluded: [second.id])

        excluded_radio = radio(helper.address_merge_cell(excluding, :name, second))
        expect(excluded_radio).to be_present
        expect(excluded_radio['value']).to eq(second.id.to_s)
        expect(excluded_radio['disabled']).to eq('disabled')
        expect(excluded_radio['checked']).to be_nil
        expect(excluded_radio.attributes.keys.grep(/\Adata-/)).to be_empty
        expect(helper.address_merge_cell(excluding, :name, second)).to include('Bea Second')
        expect(radio(helper.address_merge_cell(excluding, :name, third))['value']).to eq(third.id.to_s)
      end

      it 'keeps radios on the merged columns, the default checked, for a field that differs only through the excluded customer' do
        third.update!(full_name: 'Ann First')
        excluding = merge(excluded: [second.id])

        expect(excluding.differs?(:name)).to be(false)
        first_radio = radio(helper.address_merge_cell(excluding, :name, first))
        third_radio = radio(helper.address_merge_cell(excluding, :name, third))
        expect(first_radio['checked']).to be_nil
        expect(first_radio['disabled']).to be_nil
        expect(third_radio['checked']).to eq('checked')
        expect(third_radio['data-customer']).to eq(third.id.to_s)
        expect(radio(helper.address_merge_cell(excluding, :name, second))['disabled']).to eq('disabled')
        expect(helper.address_merge_row_data(excluding, :name)).to eq(merge_field: :name)
        expect(helper.address_merge_source(excluding, :name)).to eq(third.id)
      end
    end

    describe '#address_merge_summary' do
      it 'says one excluded customer is left alone, with no LGL sentence outside LGL Review' do
        summary = helper.address_merge_summary(merge(excluded: [second.id]), constituent_id: nil)

        expect(summary).to include("Keeps ##{first.id} and deletes ##{third.id}.", " Leaves ##{second.id} alone.")
        expect(summary).not_to include('LGL')
      end

      it 'says the LGL Review of one excluded customer is cleared and it is re-synced' do
        allow(Lgl).to receive(:enabled?).and_return(true)

        summary = helper.address_merge_summary(merge(excluded: [second.id]), constituent_id: 900_002)

        expect(summary).to include(" Leaves ##{second.id} alone.",
                                   " Re-links LGL constituent 900002 to ##{first.id}; " \
                                   "clears the LGL Review on ##{second.id} and re-syncs it.")
      end

      it 'names two excluded customers together and re-syncs them' do
        allow(Lgl).to receive(:enabled?).and_return(true)
        fourth = FactoryBot.create(:address, full_name: 'Di Fourth')

        summary = helper.address_merge_summary(merge(ids: ids + [fourth.id], excluded: [second.id, fourth.id]),
                                               constituent_id: 900_002)

        expect(summary).to include("Keeps ##{first.id} and deletes ##{third.id}.",
                                   " Leaves ##{second.id} and ##{fourth.id} alone.",
                                   " Re-links LGL constituent 900002 to ##{first.id}; " \
                                   "clears the LGL Review on ##{second.id} and ##{fourth.id} and re-syncs them.")
      end

      it 'leaves two excluded customers alone without an LGL sentence when LGL is not configured' do
        allow(Lgl).to receive(:enabled?).and_return(false)
        fourth = FactoryBot.create(:address, full_name: 'Di Fourth')

        summary = helper.address_merge_summary(merge(ids: ids + [fourth.id], excluded: [second.id, fourth.id]),
                                               constituent_id: 900_002)

        expect(summary).to include(" Leaves ##{second.id} and ##{fourth.id} alone.")
        expect(summary).not_to include('Re-links', 're-syncs')
      end
    end
  end
end
