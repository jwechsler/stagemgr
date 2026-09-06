require 'rails_helper'

# A smoke test over every customer-facing email, rendered twice: once with no
# site theme (the generic copy every new install gets) and once with the
# theaterwit theme installed.
#
# What it is for:
#
#   * the generic pass proves no house's copy is left hard-coded in app/views.
#     A partial that still names a particular theater fails here rather than in
#     someone else's outbox.
#   * the theme pass proves the overrides still compile and still say what they
#     were written to say. A partial renamed under app/views but not in the
#     theme raises only while that theme is active, so nothing else in the suite
#     would catch it. If you add a house theme, add it here.
#
# Facts (phone, artistic director, box office) come from the `theater:` block of
# config/server.yml.example either way -- installing a theme does not change
# them -- so the theme expectations below assert override COPY, never facts.
#
# Set MAIL_DUMP_DIR to write every rendered body to disk:
#
#   MAIL_DUMP_DIR=tmp/mail-after bundle exec rspec spec/mailers/theme_render_spec.rb
#
# Running that on the commit before a copy change and again after gives a
# diffable before/after of the whole mail suite.
#
# EXPECTED differences when diffing tmp/mail-before against
# tmp/mail-after/theaterwit for the genericization branch (B9). Anything else
# the diff turns up is a regression:
#
#   * _contact_information: "CONNECT WITH THE WIT:" -> "CONNECT WITH THEATER
#     WIT:" (the heading is now the house name, upcased).
#   * _contact_information: "What's playing?" points at box_office_productions_url
#     in this app instead of the hard-coded marketing-site URL.
#   * _contact_information: the phone prints in the `theater: phone:` format
#     ("773-975-8150"); the dotted "773.975.8150" form that appeared only here
#     is gone.
#   * _contact_information: the address line gains ", IL 60657" -- it is now
#     TheaterInfo#full_address rather than a shorter hand-written copy of it.
#   * Both mail layouts: the logo <img> now comes from the `theater: logo_url:`
#     fact and carries alt text. order_mailer_no_sidebar previously pointed at
#     /static/img/... while order_mailer pointed at /assets/img/...; both are now
#     the one configured URL.
#   * membership_confirmation: the Stripe portal button's surrounding <table>
#     was previously left unclosed and is now balanced, so indentation and tag
#     order shift around it.
#   * _stay_in_touch: "at our website, on Facebook page, or Twitter" becomes
#     "on our website, Facebook, or Twitter" -- the list is built from whichever
#     social facts are configured, so its connectives are generated.
#   * _stay_in_touch, donation_thank_you, membership_confirmation,
#     membership_friend_pass: the signature block is now the shared
#     order_mailer/_signature partial, so its whitespace differs even where the
#     words do not.
RSpec.describe 'mailer rendering under each site theme', type: :mailer do
  # Anything that would identify one particular house. None of it may survive
  # in app/views.
  let(:house_copy) { /theaterwit|theater wit|the Wit\b|975[-.]8150|Belmont|Chicago|Jeremy/i }

  let!(:house) { FactoryBot.create(:theater, name: 'House Theater') }
  # The :address factory's default patron is called Jeremy, which this spec's
  # own "no house copy" regex would flag. full_name is authoritative -- the
  # model derives first/last from it -- so all three are set here.
  let(:address) do
    FactoryBot.create(:address, email: 'patron@example.com',
                                full_name: 'Pat Patron', first_name: 'Pat', last_name: 'Patron')
  end
  let(:venue) { FactoryBot.create(:venue) }
  let(:payment_type) { FactoryBot.create(:cash_payment_type) }

  let(:production) do
    FactoryBot.create(:production, theater: house, venue: venue, name: 'The Show',
                                   production_class: Production::PRIMETIME)
  end
  let(:performance) { FactoryBot.create(:performance, production: production) }

  let(:ticket_order) do
    FactoryBot.create(:ticket_order, :for_a_pair_of_tickets,
                      performance: performance, address: address, payment_type: payment_type)
  end

  let(:donation_order) { FactoryBot.create(:donation_order_for_one_thousand_dollars, address: address) }
  # The friend pass is only offered when the membership carries a code to hand
  # out, so the offer needs one or that mailer declines to build a message.
  let(:membership_order) do
    FactoryBot.create(:membership_order, address: address).tap do |order|
      order.membership.membership_offer.update!(use_member_friend_code: 'PASS')
    end
  end
  let(:flex_pass_order) { FactoryBot.create(:flex_pass_order, address: address) }

  let!(:broadcast) do
    FactoryBot.create(:performance_broadcast, performance: performance,
                                              user: FactoryBot.create(:user),
                                              subject: 'A change of curtain time',
                                              sent_at: 5.minutes.ago)
  end

  # Every message the box office can send a patron, keyed by the name its dump
  # file gets. Built fresh per call so the two theme passes share no state.
  def render_all
    {
      'ticket_confirmation' => OrderMailer.ticket_confirmation(ticket_order),
      'performance_reminder' => OrderMailer.performance_reminder(ticket_order, nil, nil, true),
      'standard_followup' => OrderMailer.standard_followup(ticket_order),
      'first_time_followup' => OrderMailer.first_time_followup(ticket_order),
      'member_followup' => OrderMailer.member_followup(ticket_order),
      'donation_thank_you' => OrderMailer.donation_thank_you(donation_order),
      'membership_confirmation' => OrderMailer.membership_confirmation(membership_order),
      'membership_friend_pass' => OrderMailer.membership_friend_pass(membership_order),
      'flexpass_confirmation' => OrderMailer.flexpass_confirmation(flex_pass_order),
      'custom_performance_broadcast' => OrderMailer.custom_performance_broadcast(ticket_order)
    }
  end

  def dump(theme, name, body)
    directory = ENV['MAIL_DUMP_DIR'].presence
    return if directory.nil?

    target = Rails.root.join(directory, theme)
    FileUtils.mkdir_p(target)
    File.write(target.join("#{name}.html"), body)
  end

  describe 'the generic theme' do
    it 'renders every customer-facing email with no house copy left in it' do
      render_all.each do |name, message|
        body = message.body.decoded
        dump('generic', name, body)

        expect(body).to be_present, "#{name} rendered an empty body"
        expect(body).not_to match(house_copy), "#{name} still carries house copy"
        expect(message.subject.to_s).not_to match(house_copy), "#{name}'s subject still carries house copy"
      end
    end

    it 'names the house from the Default theater row' do
      body = OrderMailer.ticket_confirmation(ticket_order).body.decoded

      expect(body).to include("About your visit to #{house.name}")
    end

    it 'uses the generic donation subject' do
      expect(OrderMailer.donation_thank_you(donation_order).subject).to eq('Thank you for your donation!')
    end
  end

  describe "the 'theaterwit' theme" do
    it 'renders every customer-facing email' do
      SiteTheme.with_theme('theaterwit') do
        render_all.each do |name, message|
          body = message.body.decoded
          dump('theaterwit', name, body)

          expect(body).to be_present, "#{name} rendered an empty body"
        end
      end
    end

    it 'keeps the copy its overrides exist to carry' do
      SiteTheme.with_theme('theaterwit') do
        confirmation = OrderMailer.ticket_confirmation(ticket_order).body.decoded
        expect(confirmation).to include('Kubo')
        expect(confirmation).to include('tears and recriminations')

        donation = OrderMailer.donation_thank_you(donation_order)
        expect(donation.subject).to include('AWESOME')
        expect(donation.body.decoded).to include('storefront theaters')
        expect(donation.body.decoded).to include('Jeremy Wechsler')

        expect(OrderMailer.membership_confirmation(membership_order).body.decoded).to include('storefront theaters')
      end
    end

    it 'renders the host callout for a show the house only presented' do
      visiting = FactoryBot.create(:theater, name: 'Visiting Company', theater_class: Theater::VISITING)
      visiting_production = FactoryBot.create(:production, theater: visiting, venue: venue,
                                                           production_class: Production::PRIMETIME)
      visiting_order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets,
                                         performance: FactoryBot.create(:performance,
                                                                        production: visiting_production),
                                         address: address, payment_type: payment_type)

      SiteTheme.with_theme('theaterwit') do
        body = OrderMailer.standard_followup(visiting_order).body.decoded

        # The callout is what pulls in the renamed partials (_host_callout ->
        # _house_pride), and a name the theme has not caught up with raises only
        # here.
        expect(body).to include("A note from #{house.name}")
        expect(body).to include('Tell us about it')
        expect(body).to include('Stay in touch')
      end
    end

    it 'still takes its facts from config, not from the theme' do
      SiteTheme.with_theme('theaterwit') do
        expect(OrderMailer.standard_followup(ticket_order).from).to eq(['director@yourtheater.org'])
      end
    end
  end

  describe 'a house whose name is not ASCII' do
    # Mail::Address#format hands back raw UTF-8; it is the header that has to
    # encode it. A house called Théâtre du Châtelet should not be sending mail
    # from a mojibaked -- or, worse, rejected -- From: header.
    let!(:house) { FactoryBot.create(:theater, name: 'Théâtre du Châtelet') }

    around do |example|
      configured = Rails.configuration.x.server_config
      # The test block names the box office explicitly; drop that so the display
      # name falls back to the house name, which is the string under test.
      Rails.configuration.x.server_config =
        configured.merge('theater' => configured['theater'].except('box_office_display_name'))
      example.run
    ensure
      Rails.configuration.x.server_config = configured
    end

    it 'encodes the house name in the From header' do
      message = OrderMailer.ticket_confirmation(ticket_order)

      expect(message.from).to eq(['boxoffice@yourtheater.org'])
      expect(message[:from].encoded).to match(/=\?UTF-8\?/i)
      expect(message[:from].decoded).to include('Théâtre du Châtelet Box Office')
    end
  end
end
