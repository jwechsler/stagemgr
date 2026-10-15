# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lgl::Client::Fundraising do
  subject(:client) { Lgl::Client.new(api_key: 'secret-key', http: http, min_interval: 0) }

  let(:requests) { [] }
  let(:responses) { [] }
  let(:http) do
    lambda do |req, uri|
      requests << { req: req, uri: uri }
      responses.shift || fake_response(200, {})
    end
  end

  def fake_response(code, body)
    Struct.new(:code, :body).new(code.to_s, body.is_a?(String) ? body : JSON.generate(body))
  end

  def respond_with(*list)
    responses.concat(list)
  end

  def query_of(index = 0)
    URI.decode_www_form(requests[index][:uri].query)
  end

  after do
    Lgl.read_write!
    Lgl.disable
  end

  describe '#campaigns' do
    it 'returns every campaign across pages of GET /campaigns' do
      respond_with(
        fake_response(200, { 'total_items' => 3, 'next_item' => 2,
                             'items' => [{ 'id' => 1, 'is_active' => true }, { 'id' => 2 }] }),
        fake_response(200, { 'total_items' => 3, 'next_item' => 3, 'items' => [{ 'id' => 3 }] })
      )

      campaigns = client.campaigns

      expect(campaigns.first).to eq('id' => 1, 'is_active' => true)
      expect(campaigns.pluck('id')).to eq([1, 2, 3])
      expect(requests.map { |r| r[:req].method }.uniq).to eq(['GET'])
      expect(requests.map { |r| r[:uri].path }.uniq).to eq(['/api/v1/campaigns'])
      expect(query_of(0)).to eq([%w[limit 1000], %w[offset 0]])
      expect(query_of(1)).to eq([%w[limit 1000], %w[offset 2]])
    end
  end

  describe 'searches' do
    it 'search_appeals finds appeals by double-encoded name' do
      respond_with(fake_response(200, { 'items' => [{ 'id' => 5, 'name' => '2026 Ticketing' }] }))

      expect(client.search_appeals('2026 Ticketing')).to eq([{ 'id' => 5, 'name' => '2026 Ticketing' }])
      expect(requests.first[:req].method).to eq('GET')
      expect(requests.first[:uri].path).to eq('/api/v1/appeals/search')
      expect(requests.first[:uri].query).to eq('q%5B%5D=name%3D2026%2520Ticketing&limit=1000')
    end

    it 'search_events finds events by double-encoded name' do
      respond_with(fake_response(200, { 'items' => [{ 'id' => 6 }] }))

      expect(client.search_events('Gala Night')).to eq([{ 'id' => 6 }])
      expect(requests.first[:req].method).to eq('GET')
      expect(requests.first[:uri].path).to eq('/api/v1/events/search')
      expect(requests.first[:uri].query).to eq('q%5B%5D=name%3DGala%2520Night&limit=1000')
    end

    it 'search_gifts_by_external_ids sends one double-encoded in| clause' do
      respond_with(fake_response(200, { 'items' => [{ 'id' => 7 }] }))

      expect(client.search_gifts_by_external_ids(%w[a b])).to eq([{ 'id' => 7 }])
      expect(requests.first[:req].method).to eq('GET')
      expect(requests.first[:uri].path).to eq('/api/v1/gifts/search')
      expect(requests.first[:uri].query).to eq('q%5B%5D=external_gift_ids%3Din%257Ca%252Cb&limit=1000')
      expect(query_of).to include(['q[]', 'external_gift_ids=in%7Ca%2Cb'])
    end

    it 'returns an empty list when the answer has no items' do
      expect(client.search_appeals('x')).to eq([])
    end
  end

  { find_event: '/api/v1/events/12.json', find_gift: '/api/v1/gifts/12.json' }.each do |method_name, path|
    describe "##{method_name}" do
      it "returns the hash from GET #{path.delete_prefix('/api/v1')} with no query string" do
        respond_with(fake_response(200, { 'id' => 12 }))

        expect(client.public_send(method_name, '12')).to eq('id' => 12)
        expect(requests.first[:req].method).to eq('GET')
        expect(requests.first[:uri].path).to eq(path)
        expect(requests.first[:uri].query).to be_nil
      end

      it 'returns nil on 404' do
        respond_with(fake_response(404, { 'error' => 'not found' }))

        expect(client.public_send(method_name, 12)).to be_nil
      end

      it 'raises on other errors' do
        respond_with(fake_response(500, 'boom'))

        expect { client.public_send(method_name, 12) }.to raise_error(Lgl::Error) { |e| expect(e.status).to eq(500) }
      end
    end
  end

  describe 'writes' do
    before { Lgl.configure('secret-key') }

    {
      create_appeal: [[], 'POST', '/appeals'],
      update_appeal: [[11], 'PATCH', '/appeals/11'],
      create_event: [[], 'POST', '/events'],
      update_event: [[11], 'PATCH', '/events/11'],
      create_gift: [[77], 'POST', '/constituents/77/gifts'],
      update_gift: [[11], 'PATCH', '/gifts/11']
    }.each do |method_name, (ids, verb, path)|
      it "#{method_name} sends #{verb} #{path} with the JSON attrs and the bearer key" do
        respond_with(fake_response(200, { 'id' => 99 }))

        expect(client.public_send(method_name, *ids, { 'name' => 'N' }, for_address_id: 5)).to eq('id' => 99)
        req = requests.first[:req]
        expect(req.method).to eq(verb)
        expect(requests.first[:uri].path).to eq("/api/v1#{path}")
        expect(req['Authorization']).to eq('Bearer secret-key')
        expect(req['Content-Type']).to eq('application/json')
        expect(JSON.parse(req.body)).to eq('name' => 'N')
      end

      it "#{method_name} skips and logs, making no request, when read-only for the address" do
        Lgl.read_only!
        allow(Rails.logger).to receive(:warn)

        expect(client.public_send(method_name, *ids, { 'name' => 'N' }, for_address_id: 5)).to be_nil
        expect(requests).to be_empty
        expect(Rails.logger).to have_received(:warn).with("[LGL] read-only: skipped #{verb} #{path} for address #5")
      end
    end

    it 'writes for an allowlisted address in a read-only environment' do
      Lgl.read_only!(except_address_ids: '5')

      client.create_gift(77, { 'received_amount' => 10 }, for_address_id: 5)

      expect(requests.size).to eq(1)
    end
  end

  it 'has no way to delete anything' do
    expect(Rails.root.join('app/models/lgl/client/fundraising.rb').read).not_to match(/Delete/)
  end
end
