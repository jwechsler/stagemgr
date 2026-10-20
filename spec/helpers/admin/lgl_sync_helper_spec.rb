# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::LglSyncHelper, type: :helper do
  let!(:house) { Theater.default_theater || FactoryBot.create(:theater, theater_class: Theater::DEFAULT) }

  def named(lgl_id)
    "#{Lgl::ConstituentReplicator.several_matches_prefix(lgl_id)} named Derek Phillips by email: " \
      'merge them in Stagemgr, then Re-sync'
  end

  def several(lgl_id)
    "#{Lgl::ConstituentReplicator.several_matches_prefix(lgl_id)} by email and last name"
  end

  def flag(full_name, email, reason)
    FactoryBot.create(:address, full_name: full_name, email: email).tap { |address| address.lgl_review!(reason) }
  end

  def only_row
    rows = Lgl::ReviewList.new(limit: 10).rows
    expect(rows.size).to eq(1)
    rows.first
  end

  describe '#lgl_review_merge_button' do
    it 'links to the Merge customers page with the customers and the constituent' do
      first = flag('Derek Phillips', 'derek@example.com', named(971_217))
      second = flag('Derek Phillip', 'dphillips@example.com', named(971_217))

      html = helper.lgl_review_merge_button(only_row)

      path = new_admin_address_merge_path(ids: [first.id, second.id], constituent_id: 971_217)
      expect(html).to eq(%(<a class="button tiny" href="#{ERB::Util.html_escape(path)}">Merge</a>))
    end

    it 'links a household the same way: the page warns about the first names' do
      glen = flag('Glen Kosalko', 'kosalko@example.com', several(920_008))
      beth = flag('Beth Kosalko', 'kosalko@example.com', several(920_008))

      html = helper.lgl_review_merge_button(only_row)

      path = new_admin_address_merge_path(ids: [glen.id, beth.id], constituent_id: 920_008)
      expect(html).to include(ERB::Util.html_escape(path))
    end

    it 'offers no Merge for a single flagged customer' do
      flag('Derek Phillips', 'derek@example.com', named(971_217))

      expect(helper.lgl_review_merge_button(only_row)).to be_nil
    end

    it 'offers nothing on a pair row' do
      jane = FactoryBot.create(:address, full_name: 'Jane Doe')
      other = FactoryBot.create(:address, full_name: 'Jane D')
      jane.lgl_review!("LGL constituent 5512 is also linked to ##{other.id}")
      other.lgl_review!("LGL constituent 5512 is also linked to ##{jane.id}")

      expect(helper.lgl_review_merge_button(only_row)).to be_nil
    end
  end

  describe '#lgl_review_first_names' do
    it 'lists the distinct first names of the customers' do
      customers = ['Glen Kosalko', 'glen K.', 'Beth Kosalko'].map { |name| FactoryBot.create(:address, full_name: name) }

      expect(helper.lgl_review_first_names(customers)).to eq('Glen, Beth')
    end
  end

  describe '#lgl_review_identity' do
    it 'shows one line per flagged customer: a link to their page, then their email as text' do
      first = flag('Derek Phillips', 'derek@example.com', named(971_217))
      second = flag('Derek Phillip', 'dphillips@example.com', named(971_217))

      html = helper.lgl_review_identity(only_row)

      expect(html).to eq(
        %(<a href="#{admin_address_path(first)}">Derek Phillips (##{first.id})</a> derek@example.com<br>) +
        %(<a href="#{admin_address_path(second)}">Derek Phillip (##{second.id})</a> dphillips@example.com)
      )
      expect(html).not_to include('mailto:', admin_addresses_path(search: 'derek@example.com'))
    end

    it 'links each customer on a pair row' do
      jane = FactoryBot.create(:address, full_name: 'Jane Doe')
      other = FactoryBot.create(:address, full_name: 'Jane D')
      jane.lgl_review!("LGL constituent 5512 is also linked to ##{other.id}")
      other.lgl_review!("LGL constituent 5512 is also linked to ##{jane.id}")

      html = helper.lgl_review_identity(only_row)

      expect(html).to include(%(href="#{admin_address_path(jane)}"), %(href="#{admin_address_path(other)}"))
      expect(html).not_to include('<br>')
    end
  end

  describe '#lgl_review_reason_html' do
    def link(id)
      %(<a target="_blank" rel="noopener" href="https://example.littlegreenlight.com/constituents/#{id}">#{id}</a>)
    end

    before { allow(Lgl).to receive(:constituent_url) { |id| "https://example.littlegreenlight.com/constituents/#{id}" } }

    it 'links each constituent id in a list' do
      expect(helper.lgl_review_reason_html('LGL constituents 1234, 5678 and 9012 share this email'))
        .to eq("LGL constituents #{link(1234)}, #{link(5678)} and #{link(9012)} share this email")
    end

    it 'leaves customer ids and the external id as text' do
      expect(helper.lgl_review_reason_html('LGL constituents 11 and 12 carry external id 42'))
        .to eq("LGL constituents #{link(11)} and #{link(12)} carry external id 42")
      expect(helper.lgl_review_reason_html('LGL constituent 5512 is also linked to #5678'))
        .to eq("LGL constituent #{link(5512)} is also linked to #5678")
      expect(helper.lgl_review_reason_html('Also LGL constituent 77: merge the two in LGL'))
        .to eq("Also LGL constituent #{link(77)}: merge the two in LGL")
    end

    it 'is the plain reason when no web URL is configured' do
      allow(Lgl).to receive(:constituent_url).and_return(nil)

      expect(helper.lgl_review_reason_html('LGL constituents 11 and 12 share this email'))
        .to eq('LGL constituents 11 and 12 share this email')
    end

    it 'escapes the rest of the reason' do
      html = helper.lgl_review_reason_html('<b>LGL constituent 9</b> & co')

      expect(html).to eq("&lt;b&gt;LGL constituent #{link(9)}&lt;/b&gt; &amp; co")
      expect(html).to be_html_safe
    end
  end

  describe '#lgl_review_constituent' do
    before { flag('Derek Phillips', 'derek@example.com', named(971_217)) }

    it 'links the constituent id to LGL when the web URL is configured' do
      allow(Lgl).to receive(:constituent_url).with(971_217)
                                             .and_return('https://example.littlegreenlight.com/constituents/971217')

      expect(helper.lgl_review_constituent(only_row)).to eq(
        'LGL constituent <a target="_blank" rel="noopener" ' \
        'href="https://example.littlegreenlight.com/constituents/971217">971217</a>'
      )
    end

    it 'shows the id as plain text when no web URL is configured' do
      allow(Lgl).to receive(:constituent_url).with(971_217).and_return(nil)

      expect(helper.lgl_review_constituent(only_row)).to eq('LGL constituent 971217')
    end

    it 'links each constituent an other row\'s reason names' do
      FactoryBot.create(:address).lgl_review!('LGL constituents 11 and 12 share this email')
      allow(Lgl).to receive(:constituent_url).with(11).and_return('https://example.littlegreenlight.com/constituents/11')
      allow(Lgl).to receive(:constituent_url).with(12).and_return(nil)
      row = Lgl::ReviewList.new(limit: 10).rows.find { |r| r.kind == :other }

      expect(helper.lgl_review_constituent(row)).to eq(
        'LGL constituent <a target="_blank" rel="noopener" ' \
        'href="https://example.littlegreenlight.com/constituents/11">11</a>, LGL constituent 12'
      )
    end

    it 'is nil for a row with no constituent' do
      FactoryBot.create(:address).lgl_review!('No LGL match')
      row = Lgl::ReviewList.new(limit: 10).rows.find { |r| r.kind == :other }

      expect(helper.lgl_review_constituent(row)).to be_nil
    end
  end
end
