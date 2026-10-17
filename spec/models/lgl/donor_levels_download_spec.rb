require 'rails_helper'

RSpec.describe Lgl::DonorLevelsDownload do
  let(:url) { 'https://reports.example.org/saved/abc?token=s3cr3t-token' }
  let(:csv) { "﻿External constituent ID,First Name,TG Tier Last Fiscal,TG Tier This Fiscal\n42,Ann,Gold,Silver\n" }
  let(:requests) { [] }

  def response(klass, code, body: '', headers: {})
    res = klass.new('1.1', code.to_s, 'message')
    headers.each { |name, value| res[name] = value }
    res.instance_variable_set(:@read, true)
    res.instance_variable_set(:@body, body)
    res
  end

  def ok(body = csv, type: 'text/csv; charset=utf-8', headers: {})
    response(Net::HTTPOK, 200, body: body, headers: { 'Content-Type' => type }.merge(headers))
  end

  def redirect(location)
    response(Net::HTTPFound, 302, headers: { 'Location' => location })
  end

  # Answers each request with the next queued response, recording what was sent.
  def http_answering(*responses)
    queue = responses.dup
    lambda do |request, uri|
      requests << { uri: uri, authorization: request['Authorization'] }
      queue.shift
    end
  end

  def fetch(*responses, user: 'lgl-user', password: 'pw')
    described_class.fetch(url, user: user, password: password, http: http_answering(*responses))
  end

  def expect_failure(*responses, message, status: nil, **creds)
    expect { fetch(*responses, **creds) }.to raise_error(Lgl::Error) do |error|
      expect(error.message).to match(message)
      expect(error.status).to eq(status) if status
      expect(error.message).not_to include(url, 'token', 'lgl-user', '/saved/')
    end
  end

  it 'returns the CSV body on a 200' do
    expect(fetch(ok)).to eq(csv)
  end

  it 'follows one redirect' do
    expect(fetch(redirect('https://storage.example.net/file.csv?sig=x'), ok)).to eq(csv)
    expect(requests.map { |r| r[:uri].host }).to eq(%w[reports.example.org storage.example.net])
  end

  it 'raises on a second redirect' do
    expect_failure(redirect('/one'), redirect('/two'), /redirected more than once/, status: 302)
  end

  it 'raises with the status and a credentials hint on 401 and 403' do
    expect_failure(response(Net::HTTPUnauthorized, 401), %r{check LGL_USER / LGL_PASSWORD}, status: 401)
    expect_failure(response(Net::HTTPForbidden, 403), %r{check LGL_USER / LGL_PASSWORD}, status: 403)
  end

  it 'raises with the status on a 500' do
    expect_failure(response(Net::HTTPInternalServerError, 500), /HTTP 500/, status: 500)
  end

  it 'raises on an unexpected content type' do
    expect_failure(ok('<html></html>', type: 'text/html'), %r{content type text/html})
  end

  it 'accepts application/octet-stream' do
    expect(fetch(ok(type: 'application/octet-stream'))).to eq(csv)
  end

  it 'raises on an empty body' do
    expect_failure(ok(''), /empty/)
  end

  it 'raises when Content-Length is over the limit' do
    too_big = (described_class::MAX_BYTES + 1).to_s
    expect_failure(ok(headers: { 'Content-Length' => too_big }), /larger than/)
  end

  it 'raises when the body is over the limit' do
    stub_const("#{described_class}::MAX_BYTES", 10)
    expect_failure(ok, /larger than/)
  end

  it 'raises when a required column is missing from the first line' do
    expect_failure(ok("External constituent ID,TG Tier Last Fiscal\n1,Gold\n"), /missing column TG Tier This Fiscal/)
  end

  it 'matches header names case-insensitively' do
    body = "external CONSTITUENT id,tg tier last fiscal,TG TIER THIS FISCAL\n"
    expect(fetch(ok(body))).to eq(body)
  end

  it 'raises without the URL when the network fails' do
    failing = ->(_request, _uri) { raise Errno::ECONNREFUSED }
    expect { described_class.fetch(url, user: nil, password: nil, http: failing) }
      .to raise_error(Lgl::Error) { |error| expect(error.message).to include('reports.example.org').and(exclude('token')) }
  end

  describe 'Basic auth' do
    it 'is sent when both user and password are set' do
      fetch(ok)
      expect(requests.first[:authorization]).to start_with('Basic ')
    end

    it 'is not sent when either is blank' do
      fetch(ok, user: 'lgl-user', password: '')
      fetch(ok, user: nil, password: 'pw')
      expect(requests.pluck(:authorization)).to eq([nil, nil])
    end

    it 'is re-sent on a same-host redirect' do
      fetch(redirect('/download/file.csv'), ok)
      expect(requests.pluck(:authorization)).to all(start_with('Basic '))
    end

    it 'is dropped on a cross-host redirect' do
      fetch(redirect('https://storage.example.net/file.csv'), ok)
      expect(requests.pluck(:authorization)).to eq([requests.first[:authorization], nil])
      expect(requests.first[:authorization]).to be_present
    end

    it 'is dropped when the redirect changes scheme' do
      fetch(redirect('http://reports.example.org/file.csv'), ok)
      expect(requests.last[:authorization]).to be_nil
    end
  end

  it 'never logs the URL or the user' do
    logged = []
    allow(Rails.logger).to receive(:info) { |message| logged << message }
    fetch(ok)
    expect(logged.join).to include('reports.example.org')
    expect(logged.join).not_to include('token', 'lgl-user')
  end

  RSpec::Matchers.define_negated_matcher :exclude, :include
end
