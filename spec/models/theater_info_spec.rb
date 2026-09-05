require 'rails_helper'

RSpec.describe TheaterInfo do
  # Facts are injected rather than read from config/server.yml: every developer
  # has their own (gitignored) copy of that file, and Theater Wit's carries real
  # values. One example at the end checks the wiring to the real config.
  let(:email_addresses) { { 'box_office' => 'boxoffice@yourtheater.org' } }

  def info(theater_facts = {}, addresses = email_addresses)
    described_class.new(server_config: { 'theater' => theater_facts }, email_addresses: addresses)
  end

  describe 'reading facts' do
    it 'returns the configured value' do
      expect(info('phone' => '555-BOX-OFFICE').phone).to eq('555-BOX-OFFICE')
    end

    it 'reads the doors-open time as a number however it was typed' do
      expect(info('doors_open_minutes_before' => 25).doors_open_minutes_before).to eq(25)
      expect(info('doors_open_minutes_before' => '25').doors_open_minutes_before).to eq(25)
      expect(info.doors_open_minutes_before).to be_nil
    end

    # A fact that returns nil for a name nobody registered drops a sentence from
    # a page and leaves no trace of why.
    it 'refuses to read a fact that does not exist' do
      expect { info[:phone_number] }.to raise_error(KeyError, /phone_number/)
    end

    # A key left in place with nothing after the colon parses as nil, and a key
    # someone typed a space into parses as "". Both mean "not configured", so
    # the sentence that would use them is dropped rather than printed empty.
    it 'treats a missing, nil or blank fact as absent' do
      expect(info.phone).to be_nil
      expect(info('phone' => nil).phone).to be_nil
      expect(info('phone' => '   ').phone).to be_nil
    end

    it 'reads a symbol-keyed theater block, as specs write it' do
      expect(info(phone: '555-1234').phone).to eq('555-1234')
    end

    it 'survives a server.yml with no theater block at all' do
      bare = described_class.new(server_config: {}, email_addresses: email_addresses)

      expect(bare.phone).to be_nil
      expect(bare.full_address).to be_nil
    end
  end

  describe '#name' do
    it 'is the name of the Default theater row' do
      FactoryBot.create(:theater, name: 'House Theater')

      expect(info.name).to eq('House Theater')
    end

    # A brand-new install has no theater yet, and half the app's sentences name
    # the house. Fall back to something rather than rendering "Welcome to ."
    it 'falls back to the application display name when there is no Default theater' do
      expect(Theater.default_theater).to be_nil

      expect(info.name).to eq(Rails.configuration.x.app_display_name)
    end
  end

  describe '#website_url' do
    it 'prefers the configured fact' do
      FactoryBot.create(:theater, name: 'House Theater', url: 'https://from-the-database.test')

      expect(info('website_url' => 'https://from-config.test').website_url).to eq('https://from-config.test')
    end

    it 'falls back to the Default theater row, which the admin form already fills in' do
      FactoryBot.create(:theater, name: 'House Theater', url: 'https://from-the-database.test')

      expect(info.website_url).to eq('https://from-the-database.test')
    end

    it 'is nil when neither is set, so the link is omitted' do
      expect(info.website_url).to be_nil
    end
  end

  describe '#box_office_display_name' do
    it 'prefers the configured fact' do
      expect(info('box_office_display_name' => 'Test Theater Box Office').box_office_display_name)
        .to eq('Test Theater Box Office')
    end

    it 'is built from the house name otherwise' do
      FactoryBot.create(:theater, name: 'House Theater')

      expect(info.box_office_display_name).to eq('House Theater Box Office')
    end
  end

  describe '#full_address' do
    it 'joins the two configured halves' do
      facts = { 'street_address' => '1 Example Street', 'city_state_zip' => 'Chicago, IL 60657' }

      expect(info(facts).full_address).to eq('1 Example Street, Chicago, IL 60657')
    end

    it 'omits a half that is not configured' do
      expect(info('city_state_zip' => 'Chicago, IL 60657').full_address).to eq('Chicago, IL 60657')
    end

    it 'is nil when neither half is configured' do
      expect(info.full_address).to be_nil
    end
  end

  describe '#artistic_director?' do
    let(:director) do
      { 'artistic_director_name' => 'Test Director', 'artistic_director_email' => 'director@yourtheater.org' }
    end

    it 'is true when both the name and the address are configured' do
      expect(info(director)).to be_artistic_director
    end

    it 'is false with only a name -- a name cannot be a From: header' do
      expect(info(director.except('artistic_director_email'))).not_to be_artistic_director
    end

    it 'is false with only an address -- an unnamed address reads as a robot' do
      expect(info(director.except('artistic_director_name'))).not_to be_artistic_director
    end
  end

  describe '#box_office_email' do
    it 'comes from the existing email addresses block, not a second copy of it' do
      expect(info.box_office_email).to eq('boxoffice@yourtheater.org')
    end

    it 'is nil when that block has no box office address' do
      expect(info({}, {}).box_office_email).to be_nil
    end
  end

  describe 'From: headers' do
    let(:director) do
      { 'box_office_display_name' => 'Test Theater Box Office',
        'artistic_director_name' => 'Test Director',
        'artistic_director_email' => 'director@yourtheater.org' }
    end

    it 'formats the box office address' do
      expect(info(director).box_office_from).to eq('Test Theater Box Office <boxoffice@yourtheater.org>')
    end

    it 'formats the artistic director address' do
      expect(info(director).artistic_director_from).to eq('Test Director <director@yourtheater.org>')
    end

    it 'quotes a display name that needs quoting' do
      facts = { 'box_office_display_name' => 'Wilma Theater, Box Office' }

      expect(info(facts).box_office_from).to eq('"Wilma Theater, Box Office" <boxoffice@yourtheater.org>')
    end

    # Most houses have no artistic director in the config. Follow-up mail still
    # has to go out, so it degrades to the box office rather than failing.
    it 'signs as the box office when no artistic director is configured' do
      expect(info(director.except('artistic_director_email')).artistic_director_from)
        .to eq('Test Theater Box Office <boxoffice@yourtheater.org>')
    end

    it 'falls back to the bare address rather than raising on an unparseable one' do
      expect(info({}, 'box_office' => 'not an address').box_office_from).to eq('not an address')
    end

    # ActionMailer merges its defaults with reverse_merge, so `from: nil` is a
    # value that beats the default and sends a From-less message. Every step of
    # this chain exists to keep that from happening.
    describe 'when no box office address is configured' do
      let(:addresses) { { 'software_address' => 'stagemgr@yourtheater.org' } }

      it 'falls back to the software address' do
        expect(info({}, addresses).box_office_from)
          .to eq("#{info({}, addresses).box_office_display_name} <stagemgr@yourtheater.org>")
      end

      it 'falls back to ActionMailer\'s own default when even that is unset' do
        allow(ActionMailer::Base).to receive(:default).and_return(from: 'fallback@yourtheater.org')

        expect(info({}, {}).box_office_from).to include('<fallback@yourtheater.org>')
      end

      it 'raises a message naming the key to set when nothing at all is configured' do
        allow(ActionMailer::Base).to receive(:default).and_return({})

        expect { info({}, {}).box_office_from }
          .to raise_error(described_class::MissingAddress, /email: addresses: box_office/)
      end

      # The artistic director path goes through the same chain, so an
      # unconfigured director cannot produce a From-less follow-up either.
      it 'still produces a From: header for follow-up mail' do
        expect(info({}, addresses).artistic_director_from).to include('<stagemgr@yourtheater.org>')
      end
    end
  end

  # The test environment reads the tracked config/server.yml.example rather than
  # the developer's own config/server.yml, so its `test:` sentinels are the same
  # everywhere and can be asserted directly.
  describe 'the real application configuration' do
    subject(:house) { described_class.new }

    it 'reads the theater block from the test sentinels' do
      expect(house.phone).to eq('555-BOX-OFFICE')
      expect(house.full_address).to eq('1 EXAMPLE ST, TESTCITY, IL 60657')
      expect(house.pickup_window_text).to eq('PICKUPWINDOW.TEST')
      expect(house.box_office_display_name).to eq('Test Theater Box Office')
      expect(house).to be_artistic_director
    end

    it 'reads the configured email addresses' do
      expect(house.box_office_email).to eq(Rails.configuration.x.email_address['box_office'])
      expect(house.box_office_from).to eq('Test Theater Box Office <boxoffice@yourtheater.org>')
      expect(house.artistic_director_from).to eq('Test Director <director@yourtheater.org>')
    end
  end
end
