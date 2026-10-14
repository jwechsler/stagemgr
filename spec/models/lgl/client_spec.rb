# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lgl::Client do
  subject(:client) { described_class.new(api_key: 'secret-key', http: http, min_interval: 0) }

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

  describe 'requests' do
    it 'sends the key as a bearer token and asks for JSON' do
      client.find(1)

      req = requests.first[:req]
      expect(req['Authorization']).to eq('Bearer secret-key')
      expect(req['Accept']).to eq('application/json')
      expect(requests.first[:uri].to_s).to eq('https://api.littlegreenlight.com/api/v1/constituents/1.json')
    end

    it 'double-encodes the q[] value because LGL decodes it twice' do
      client.search_by_email('jeremy+test@theaterwit.org')

      raw = requests.first[:uri].query
      expect(raw).to include('q%5B%5D=eaddr%3Djeremy%252Btest%2540theaterwit.org')
      expect(query_of).to include(['q[]', 'eaddr=jeremy%2Btest%40theaterwit.org'])
    end

    it 'searches external ids with an exact eq clause' do
      respond_with(fake_response(200, { 'items' => [{ 'id' => 9 }] }))

      expect(client.search_by_external_id(42)).to eq([{ 'id' => 9 }])
      expect(requests.first[:uri].path).to eq('/api/v1/constituents/search')
      expect(requests.first[:uri].query).to include('q%5B%5D=external_id%3Deq%257C42')
      expect(query_of).to include(['q[]', 'external_id=eq%7C42'])
    end
  end

  describe '#find' do
    it 'returns the constituent, sending no query string (LGL 403s on expand)' do
      respond_with(fake_response(200, { 'id' => 3, 'first_name' => 'Ada' }))

      expect(client.find(3)).to eq('id' => 3, 'first_name' => 'Ada')
      expect(requests.first[:uri].query).to be_nil
    end

    it 'returns nil on 404 (deleted or merged away in LGL)' do
      respond_with(fake_response(404, { 'error' => 'not found' }))

      expect(client.find(3)).to be_nil
    end
  end

  describe 'errors' do
    it 'raises Lgl::Error with status and body on a non-2xx answer' do
      respond_with(fake_response(500, 'boom'))

      expect { client.find(3) }.to raise_error(Lgl::Error) { |e|
        expect(e.status).to eq(500)
        expect(e.body).to eq('boom')
      }
    end

    it 'raises Lgl::RateLimited on 429' do
      respond_with(fake_response(429, 'slow down'))

      expect { client.search_by_external_id(1) }.to raise_error(Lgl::RateLimited) { |e| expect(e.status).to eq(429) }
    end

    it 'lets network timeouts propagate' do
      timeout_client = described_class.new(api_key: 'k', min_interval: 0, http: ->(_req, _uri) { raise Net::ReadTimeout })

      expect { timeout_client.find(1) }.to raise_error(Net::ReadTimeout)
    end
  end

  describe '#search_by_email' do
    it 'keeps only constituents carrying exactly that address, ignoring case and spaces' do
      respond_with(fake_response(200, { 'items' => [
                                   { 'id' => 1, 'email_addresses' => [{ 'address' => ' Pat@Example.com ' }] },
                                   { 'id' => 2, 'email_addresses' => [{ 'address' => 'xpat@example.com' }] },
                                   { 'id' => 3, 'email_addresses' => [] }
                                 ] }))

      expect(client.search_by_email('pat@example.com ').pluck('id')).to eq([1])
      expect(query_of).to include(%w[expand email_addresses])
    end

    it 'makes no request for a blank email' do
      expect(client.search_by_email(' ')).to eq([])
      expect(requests).to be_empty
    end
  end

  describe '#search_updated_since' do
    it 'yields every constituent across pages, following next_item' do
      respond_with(
        fake_response(200, { 'total_items' => 3, 'next_item' => 2, 'items' => [{ 'id' => 1 }, { 'id' => 2 }] }),
        fake_response(200, { 'total_items' => 3, 'next_item' => 3, 'items' => [{ 'id' => 3 }] })
      )

      ids = client.search_updated_since(Time.utc(2026, 10, 1, 12, 0, 0)).pluck('id')

      expect(ids).to eq([1, 2, 3])
      expect(requests.size).to eq(2)
      expect(requests.first[:uri].query).to include('q%5B%5D=updated_from%3D2026-10-01T12%253A00%253A00Z')
      expect(query_of(0)).to include(['q[]', 'updated_from=2026-10-01T12%3A00%3A00Z'], %w[sort date_updated],
                                     %w[limit 1000], %w[offset 0])
      expect(query_of(1)).to include(%w[offset 2])
    end

    it 'expands street addresses and phone numbers as well as emails' do
      client.search_updated_since(Time.utc(2026, 10, 1)).to_a

      expand = query_of.assoc('expand').last.split(',')
      expect(expand).to include('email_addresses', 'street_addresses', 'phone_numbers')
    end
  end

  describe '#each_constituent' do
    it 'yields every full constituent hash across pages of the plain listing' do
      respond_with(
        fake_response(200, { 'total_items' => 3, 'next_item' => 2,
                             'items' => [{ 'id' => 10, 'external_constituent_id' => '5' }, { 'id' => 11 }] }),
        fake_response(200, { 'total_items' => 3, 'next_item' => 3, 'items' => [{ 'id' => 12 }] })
      )

      constituents = client.each_constituent.to_a

      expect(constituents.first).to eq({ 'id' => 10, 'external_constituent_id' => '5' })
      expect(constituents.pluck('id')).to eq([10, 11, 12])
      expect(requests.map { |r| r[:uri].path }.uniq).to eq(['/api/v1/constituents'])
      expect(query_of(0)).to eq([%w[limit 1000], %w[offset 0]])
      expect(query_of(1)).to include(%w[offset 2])
    end
  end

  describe '#each_constituent_id' do
    it 'pages the full list and returns the ids with the reported total' do
      respond_with(
        fake_response(200, { 'total_items' => 3, 'next_item' => 2, 'items' => [{ 'id' => 10 }, { 'id' => 11 }] }),
        fake_response(200, { 'total_items' => 3, 'next_item' => 3, 'items' => [{ 'id' => 12 }] })
      )

      expect(client.each_constituent_id).to eq([[10, 11, 12], 3])
      expect(requests.map { |r| r[:uri].path }.uniq).to eq(['/api/v1/constituents'])
    end
  end

  describe 'writes' do
    before { Lgl.configure('secret-key') }

    it 'skips and logs a create when the environment is read-only for the address' do
      Lgl.read_only!
      allow(Rails.logger).to receive(:warn)

      expect(client.create({ 'first_name' => 'Ada' }, for_address_id: 5)).to be_nil
      expect(requests).to be_empty
      expect(Rails.logger).to have_received(:warn).with('[LGL] read-only: skipped POST /constituents for address #5')
    end

    it 'skips and logs an update when the environment is read-only for the address' do
      Lgl.read_only!
      allow(Rails.logger).to receive(:warn)

      expect(client.update(77, { 'last_name' => 'L' }, for_address_id: 5)).to be_nil
      expect(requests).to be_empty
      expect(Rails.logger).to have_received(:warn).with('[LGL] read-only: skipped PATCH /constituents/77 for address #5')
    end

    it 'skips writes while LGL is disabled' do
      Lgl.disable

      expect(client.create({}, for_address_id: 5)).to be_nil
      expect(requests).to be_empty
    end

    it 'posts JSON for an allowlisted address in a read-only environment' do
      Lgl.read_only!(except_address_ids: '5')
      respond_with(fake_response(200, { 'id' => 99 }))

      expect(client.create({ 'first_name' => 'Ada' }, for_address_id: 5)).to eq('id' => 99)
      req = requests.first[:req]
      expect(req.method).to eq('POST')
      expect(req['Content-Type']).to eq('application/json')
      expect(JSON.parse(req.body)).to eq('first_name' => 'Ada')
    end

    it 'patches the constituent when writable' do
      respond_with(fake_response(200, { 'id' => 77 }))

      client.update(77, { 'external_constituent_id' => '5' }, for_address_id: 5)

      expect(requests.first[:req].method).to eq('PATCH')
      expect(requests.first[:uri].path).to eq('/api/v1/constituents/77')
    end

    {
      update_street_address: ['PATCH', '/api/v1/street_addresses/11'],
      add_street_address: ['POST', '/api/v1/constituents/77/street_addresses'],
      update_phone_number: ['PATCH', '/api/v1/phone_numbers/11'],
      add_phone_number: ['POST', '/api/v1/constituents/77/phone_numbers']
    }.each do |method_name, (verb, path)|
      id = method_name.to_s.start_with?('add_') ? 77 : 11

      it "#{method_name} sends #{verb} #{path.delete_prefix('/api/v1')} with the JSON attrs" do
        client.public_send(method_name, id, { 'number' => '1' }, for_address_id: 5)

        req = requests.first[:req]
        expect(req.method).to eq(verb)
        expect(requests.first[:uri].path).to eq(path)
        expect(JSON.parse(req.body)).to eq('number' => '1')
      end

      it "#{method_name} skips and logs when read-only" do
        Lgl.read_only!
        allow(Rails.logger).to receive(:warn)

        expect(client.public_send(method_name, id, { 'number' => '1' }, for_address_id: 5)).to be_nil
        expect(requests).to be_empty
        expect(Rails.logger).to have_received(:warn)
          .with("[LGL] read-only: skipped #{verb} #{path.delete_prefix('/api/v1')} for address #5")
      end
    end
  end

  it 'has no way to delete anything' do
    expect(client).not_to respond_to(:delete)
    expect(described_class.private_instance_methods(false)).not_to include(:delete)
    expect(Rails.root.join('app/models/lgl/client.rb').read).not_to match(/Delete/)
  end
end
