require 'rails_helper'

RSpec.describe AudienceCohortReport do
  # Stub Production.find — segment-name building only needs production_code
  # and (optionally) name/season. The full create flow is exercised by manual
  # smoke testing; here we focus on the pure-logic segment-name builder.
  def stub_production(code, name: 'Some Show', season: 2025)
    instance_double(Production, id: 42, production_code: code, name: name, season: season).tap do |p|
      allow(Production).to receive(:find).with(42).and_return(p)
    end
  end

  describe "#segment_name" do
    it "joins production_code, metric label, and window phrase" do
      stub_production('SHOW-X')
      r = described_class.new(42, [1], :first_time_vs_comparison, "3 months", false, [], 99)
      expect(r.segment_name).to eq("SHOW-X - First Time (group) - Last 3mo")
    end

    it "omits the window phrase for non-windowed segments" do
      stub_production('SHOW-X')
      r = described_class.new(42, [1], :cohort, nil, false, [], 99)
      expect(r.segment_name).to eq("SHOW-X - Attendees")
    end

    it "renders 'Returning from <CODE>' for previous_production keys" do
      stub_production('SHOW-X')
      prev = instance_double(Production, production_code: 'OLD-Y')
      allow(Production).to receive(:find_by).with(id: 777).and_return(prev)

      r = described_class.new(42, [1], "previous_production:777", nil, false, [], 99)
      expect(r.segment_name).to eq("SHOW-X - Returning from OLD-Y")
    end

    it "is capped at 50 characters" do
      stub_production('LONGCODE')
      r = described_class.new(42, [1], :first_time_vs_comparison, "3 months", false, [], 99)
      expect(r.segment_name.length).to be <= AudienceCohortReport::SEGMENT_NAME_LIMIT
    end

    it "drops the window first when over the cap, keeping production_code + metric" do
      stub_production('AAAAAAAA') # 8 chars (max production_code length)
      # Force a metric label that fits without the window but overflows with it.
      # AAAAAAAA (8) + " - " (3) + label + " - Last 3mo" (11) > 50 → drop window.
      # AAAAAAAA (8) + " - " (3) + label ≤ 50 → keep metric.
      stub_const("AudienceCohortReport::METRIC_LABELS", {
        "first_time_vs_comparison" => "First Time Visitor (group qualifier)"  # 36 chars
      }.freeze)

      r = described_class.new(42, [1], :first_time_vs_comparison, "3 months", false, [], 99)
      expect(r.segment_name).to eq("AAAAAAAA - First Time Visitor (group qualifier)")
      expect(r.segment_name).not_to include("Last 3mo")
      expect(r.segment_name.length).to be <= 50
    end
  end

  describe "email gate" do
    # Drive the row-building code path without hitting the DB or filestore.
    # The cohort math (AudienceAnalysis#cohort_for), the comparison-theater
    # production query, the address loader, and the file save are all stubbed.
    # The unit under test is purely the per-row decision: which email gets
    # blanked, what OptedInForEmail value gets written, and whether the CSV
    # headers carry the new column.
    let(:opted_in_email)     { 'opted-in@example.com' }
    let(:not_opted_in_email) { 'silent@example.com' }

    let(:opted_in_address) do
      instance_double(Address,
                      id: 101,
                      email: opted_in_email,
                      first_name: 'Opted', last_name: 'In', full_name: 'Opted In',
                      line1: '1 A St', line2: nil, city: 'Chi', state: 'IL', zipcode: '60000',
                      phone: '555-0001')
    end

    let(:silent_address) do
      instance_double(Address,
                      id: 102,
                      email: not_opted_in_email,
                      first_name: 'Sil', last_name: 'Ent', full_name: 'Sil Ent',
                      line1: '2 B St', line2: nil, city: 'Chi', state: 'IL', zipcode: '60001',
                      phone: '555-0002')
    end

    let(:target) do
      instance_double(Production, id: 42, production_code: 'TGT', name: 'Target', season: 2025)
    end

    let(:analysis) { instance_double(AudienceAnalysis) }

    before do
      allow(Production).to receive(:find).with(42).and_return(target)
      # No comparison-theater productions in scope by default; the helper
      # still gets called and we stub its return per-test.
      allow(Production).to receive(:where).with(theater_id: [7]).and_return([])

      allow(AudienceAnalysis).to receive(:new).and_return(analysis)
      allow(analysis).to receive(:cohort_for).and_return(Set.new([101, 102]))

      address_relation = double('Address::Relation')
      allow(Address).to receive(:where).with(id: [101, 102]).and_return(address_relation)
      allow(address_relation).to receive(:find_each).and_yield(opted_in_address).and_yield(silent_address)

      # mailing_hash_from_buyer reaches address.external_id via
      # MailingList.client_patron_id_for.
      [opted_in_address, silent_address].each do |a|
        allow(a).to receive(:external_id).and_return('')
      end
    end

    def build_report(allow_email_export:, allowlist:)
      allow(Admin::ReportsHelper).to receive(:attendees_on_email_list_for_productions).and_return(allowlist)
      r = described_class.new(42, [7], :cohort, nil, allow_email_export, [], 99)
      allow(r).to receive(:save_report_to_filestore) # bypass IO
      r.create
      r
    end

    it "exposes :OptedInForEmail as the last CSV header" do
      allow(Admin::ReportsHelper).to receive(:attendees_on_email_list_for_productions).and_return({})
      r = described_class.new(42, [7], :cohort, nil, false, [], 99)
      expect(r.headers.last).to eq(:OptedInForEmail)
      expect(r.headers).to include(*MailingList::TRG_IMPORT_HEADERS)
    end

    it "view_email OFF, address NOT in Emma: blanks email, marks N" do
      r = build_report(allow_email_export: false, allowlist: {})
      rows = r.data[AudienceCohortReport::TRG_SEGMENT_CODE]
      silent_row = rows.find { |h| h[:FirstName] == 'Sil' }
      expect(silent_row[:Email]).to eq('')
      expect(silent_row[:OptedInForEmail]).to eq('N')
    end

    it "view_email OFF, address IS in Emma: keeps email, marks Y" do
      r = build_report(allow_email_export: false,
                       allowlist: { opted_in_email => double('member') })
      rows = r.data[AudienceCohortReport::TRG_SEGMENT_CODE]
      opted_row = rows.find { |h| h[:FirstName] == 'Opted' }
      expect(opted_row[:Email]).to eq(opted_in_email)
      expect(opted_row[:OptedInForEmail]).to eq('Y')
    end

    it "view_email ON, address NOT in Emma: keeps email, marks N" do
      r = build_report(allow_email_export: true, allowlist: {})
      rows = r.data[AudienceCohortReport::TRG_SEGMENT_CODE]
      silent_row = rows.find { |h| h[:FirstName] == 'Sil' }
      expect(silent_row[:Email]).to eq(not_opted_in_email)
      expect(silent_row[:OptedInForEmail]).to eq('N')
    end

    it "view_email ON, address IS in Emma: keeps email, marks Y" do
      r = build_report(allow_email_export: true,
                       allowlist: { opted_in_email => double('member') })
      rows = r.data[AudienceCohortReport::TRG_SEGMENT_CODE]
      opted_row = rows.find { |h| h[:FirstName] == 'Opted' }
      expect(opted_row[:Email]).to eq(opted_in_email)
      expect(opted_row[:OptedInForEmail]).to eq('Y')
    end

    it "passes target + comparison-theater productions to the allowlist helper" do
      other_prod = instance_double(Production)
      allow(Production).to receive(:where).with(theater_id: [7]).and_return([other_prod])

      expect(Admin::ReportsHelper)
        .to receive(:attendees_on_email_list_for_productions)
        .with([target, other_prod])
        .and_return({})

      r = described_class.new(42, [7], :cohort, nil, false, [], 99)
      allow(r).to receive(:save_report_to_filestore)
      r.create
    end
  end
end
