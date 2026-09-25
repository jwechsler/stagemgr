require 'rails_helper'

RSpec.describe OrderMailer, type: :mailer do
  describe 'emails for different production types' do
    # Theater.default_theater drives every proper noun in the mail, and the
    # :theater factory names its theaters from a sequence -- so the house is
    # created first, by name, or the copy under test is whatever ran before it.
    let!(:house) { FactoryBot.create(:theater, name: 'House Theater') }
    let(:theater) { FactoryBot.create(:theater) }
    let(:venue) { FactoryBot.create(:venue) }
    let(:address) { FactoryBot.create(:address, email: 'customer@example.com') }
    let(:payment_type) { FactoryBot.create(:cash_payment_type) }

    # Create a regular Primetime production
    let(:regular_production) do
      FactoryBot.create(:production,
                        theater: theater,
                        venue: venue,
                        name: 'Regular Play',
                        production_class: Production::PRIMETIME)
    end

    # Create an External production
    let(:external_production) do
      FactoryBot.create(:production,
                        theater: theater,
                        venue: venue,
                        name: 'External Event',
                        production_class: Production::EXTERNAL)
    end

    # Create a Conference production
    let(:conference_production) do
      FactoryBot.create(:production,
                        theater: theater,
                        venue: venue,
                        name: 'Conference Event',
                        production_class: Production::CONFERENCE)
    end

    # Performance for the regular production
    let(:regular_performance) do
      FactoryBot.create(:performance,
                        production: regular_production)
    end

    # Performance for the external production
    let(:external_performance) do
      FactoryBot.create(:performance,
                        production: external_production)
    end

    # Performance for the conference production
    let(:conference_performance) do
      FactoryBot.create(:performance,
                        production: conference_production)
    end

    # Order for regular production
    let(:regular_order) do
      order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets,
                                performance: regular_performance,
                                address: address,
                                payment_type: payment_type)
      order.hold_under = 'Test Customer'
      order.status = Order::PROCESSED
      order.save!
      order
    end

    # Order for external production
    let(:external_order) do
      order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets,
                                performance: external_performance,
                                address: address,
                                payment_type: payment_type)
      order.hold_under = 'Test Customer'
      order.status = Order::PROCESSED
      order.save!
      order
    end

    # Order for conference production
    let(:conference_order) do
      order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets,
                                performance: conference_performance,
                                address: address,
                                payment_type: payment_type)
      order.hold_under = 'Test Customer'
      order.status = Order::PROCESSED
      order.save!
      order
    end

    describe '#ticket_confirmation' do
      it 'includes box office references for regular productions' do
        mail = OrderMailer.ticket_confirmation(regular_order)

        expect(mail.body.encoded).to include('box office')
        expect(mail.body.encoded).to include('Seating and Admission')
        expect(mail.body.encoded).to include("About your visit to #{house.name}")
        expect(mail.body.encoded).to include('Getting Here')
      end

      it 'excludes box office references for external productions' do
        mail = OrderMailer.ticket_confirmation(external_order)

        expect(mail.body.encoded).not_to include('box office')
        expect(mail.body.encoded).not_to include('About your visit')
        expect(mail.body.encoded).not_to include('Seating and Admission')
        expect(mail.body.encoded).not_to include('Getting Here')
      end

      it 'excludes box office references for conference productions' do
        mail = OrderMailer.ticket_confirmation(conference_order)

        expect(mail.body.encoded).not_to include('box office')
        expect(mail.body.encoded).not_to include('About your visit')
        expect(mail.body.encoded).not_to include('Seating and Admission')
        expect(mail.body.encoded).not_to include('Getting Here')
      end

      it 'still includes performance details for all production types' do
        # Regular production
        regular_mail = OrderMailer.ticket_confirmation(regular_order)
        expect(regular_mail.subject).to include(regular_order.performance.production.name)
        # Check for date format in a way that's robust against HTML formatting
        date_format = regular_order.performance.performance_date.strftime('%A, %B')
        expect(regular_mail.body.encoded).to include(date_format)

        # External production
        external_mail = OrderMailer.ticket_confirmation(external_order)
        expect(external_mail.subject).to include(external_order.performance.production.name)
        date_format = external_order.performance.performance_date.strftime('%A, %B')
        expect(external_mail.body.encoded).to include(date_format)

        # Conference production
        conference_mail = OrderMailer.ticket_confirmation(conference_order)
        expect(conference_mail.subject).to include(conference_order.performance.production.name)
        date_format = conference_order.performance.performance_date.strftime('%A, %B')
        expect(conference_mail.body.encoded).to include(date_format)
      end
    end

    describe '#performance_reminder' do
      it 'includes box office references for regular productions' do
        mail = OrderMailer.performance_reminder(regular_order, nil, nil, true)

        expect(mail.body.encoded).to include('box office')
        expect(mail.body.encoded).to include('See you at the theater')
        expect(mail.body.encoded).to include("About your visit to #{house.name}")
        expect(mail.body.encoded).to include('Seating and Admission')
        expect(mail.body.encoded).to include('Getting Here')
      end

      it 'excludes box office references for external productions' do
        mail = OrderMailer.performance_reminder(external_order, nil, nil, true)

        expect(mail.body.encoded).not_to include('box office')
        expect(mail.body.encoded).not_to include('See you at the theater')
        expect(mail.body.encoded).not_to include('About your visit')
        expect(mail.body.encoded).not_to include('Seating and Admission')
        expect(mail.body.encoded).not_to include('Getting Here')
      end

      it 'excludes box office references for conference productions' do
        mail = OrderMailer.performance_reminder(conference_order, nil, nil, true)

        expect(mail.body.encoded).not_to include('box office')
        expect(mail.body.encoded).not_to include('See you at the theater')
        expect(mail.body.encoded).not_to include('About your visit')
        expect(mail.body.encoded).not_to include('Seating and Admission')
        expect(mail.body.encoded).not_to include('Getting Here')
      end

      it 'still includes essential performance information for all production types' do
        # Regular production
        regular_mail = OrderMailer.performance_reminder(regular_order, nil, nil, true)
        expect(regular_mail.subject).to include(regular_order.performance.production.name)
        # Test for performance time in a way that's more robust against HTML formatting
        time_format = regular_order.performance.performance_time.strftime('%l:%M').strip
        expect(regular_mail.body.encoded).to match(/#{time_format}\s*(AM|PM)/i)

        # External production
        external_mail = OrderMailer.performance_reminder(external_order, nil, nil, true)
        expect(external_mail.subject).to include(external_order.performance.production.name)
        time_format = external_order.performance.performance_time.strftime('%l:%M').strip
        expect(external_mail.body.encoded).to match(/#{time_format}\s*(AM|PM)/i)

        # Conference production
        conference_mail = OrderMailer.performance_reminder(conference_order, nil, nil, true)
        expect(conference_mail.subject).to include(conference_order.performance.production.name)
        time_format = conference_order.performance.performance_time.strftime('%l:%M').strip
        expect(conference_mail.body.encoded).to match(/#{time_format}\s*(AM|PM)/i)
      end
    end

    describe 'admission-aware ticket emails' do
      let(:stream_note) { 'Stream link: https://stream.example.com/watch' }

      def add_virtual_tickets(order, count, holds_seats: false)
        stream_class = FactoryBot.create(:ticket_class, production: order.performance.production,
                                                        class_code: 'STRM', holds_seats: holds_seats,
                                                        admission: 'virtual', purchase_email_annotation: stream_note)
        FactoryBot.create(:ticket_class_allocation, performance: order.performance, ticket_class: stream_class,
                                                    ticket_limit: 10)
        FactoryBot.create(:ticket_line_item, ticket_class: stream_class, ticket_count: count, order: order)
        order.reload
      end

      def text_of(mail)
        Nokogiri::HTML(mail.body.decoded).text.squish
      end

      let(:virtual_order) do
        order = regular_order
        order.ticket_line_items.each(&:destroy)
        add_virtual_tickets(order.reload, 2)
      end

      let(:mixed_order) { add_virtual_tickets(regular_order, 1) }

      let(:drink_note) { 'Includes one drink (beer/wine/cocktail) at our bar' }

      # Two seats, plus a drink voucher ('other', never counted) and a stream
      # (virtual, counted), neither of which holds a seat.
      let(:drink_and_stream_order) do
        drink_class = FactoryBot.create(:ticket_class, production: regular_production,
                                                       class_code: 'DRNK', holds_seats: false,
                                                       admission: 'other', purchase_email_annotation: drink_note)
        FactoryBot.create(:ticket_class_allocation, performance: regular_performance, ticket_class: drink_class,
                                                    ticket_limit: 10)
        FactoryBot.create(:ticket_line_item, ticket_class: drink_class, ticket_count: 1, order: regular_order)
        add_virtual_tickets(regular_order, 1)
      end

      describe '#ticket_confirmation' do
        it 'keeps the box office line, visit block and late-seating note for in-person orders' do
          regular_production.update!(allow_late_seating: false)
          text = text_of(OrderMailer.ticket_confirmation(regular_order))

          expect(text).to include('will be waiting at the box office under Test Customer')
          expect(text).to include("About your visit to #{house.name}")
          expect(text).to include('there is no late seating available for this performance.')
          expect(text).not_to include('virtual ticket')
        end

        it 'drops pickup and visit copy for a virtual-only order and points to the stream notes' do
          regular_production.update!(allow_late_seating: false)
          text = text_of(OrderMailer.ticket_confirmation(virtual_order))

          expect(text).to include('Your 2 virtual tickets for Regular Play')
          expect(text).to include('Access details are in the notes about your order below.')
          expect(text).to include(stream_note)
          expect(text).not_to include('box office')
          expect(text).not_to include('About your visit')
          expect(text).not_to include('0 tickets')
          expect(text).not_to include('no late seating')
        end

        it 'gives a mixed order both summaries and the visit block, with the charge sentence once' do
          text = text_of(OrderMailer.ticket_confirmation(mixed_order))

          expect(text).to include('will be waiting at the box office')
          expect(text).to include('Your 1 virtual ticket for Regular Play')
          expect(text).to include("About your visit to #{house.name}")
          expect(text).to include(stream_note)
          expect(text.scan('the total charge was').size).to be <= 1
          expect(text).not_to include('Access details are in the notes')
        end

        it 'counts in-person and virtual tickets but not an other-class drink in the ticket total' do
          text = text_of(OrderMailer.ticket_confirmation(drink_and_stream_order))

          expect(text).to include('We have 3 tickets reserved for Regular Play')
          expect(text).to include('Your 2 tickets will be waiting at the box office')
          expect(text).not_to match(/\b4 tickets\b/)
          expect(text).to include(drink_note)
          expect(text).to include('Your 1 virtual ticket for Regular Play')
          expect(text).to include(stream_note)
        end

        it 'leaves the number out of the pickup sentence when no in-person ticket holds a seat' do
          regular_order.ticket_line_items.each { |tli| tli.ticket_class.update!(holds_seats: false) }
          text = text_of(OrderMailer.ticket_confirmation(regular_order.reload))

          expect(text).to include('We have 2 tickets reserved for Regular Play')
          expect(text).to include('Your tickets will be waiting at the box office')
          expect(text).not_to include('0 tickets')
        end

        it 'counts a seat-holding virtual ticket once in the ticket total' do
          text = text_of(OrderMailer.ticket_confirmation(add_virtual_tickets(regular_order, 1, holds_seats: true)))

          expect(text).to include('We have 3 tickets reserved for Regular Play')
          expect(text).to include('Your 2 tickets will be waiting at the box office')
          expect(text).not_to match(/\b4 tickets\b/)
          expect(text).to include('Your 1 virtual ticket for Regular Play')
        end
      end

      describe '#performance_reminder' do
        it 'keeps the in-person reminder copy' do
          text = text_of(OrderMailer.performance_reminder(regular_order, nil, nil, true))

          expect(text).to include('Just a reminder, you have')
          expect(text).to include('box office')
          expect(text).to include('See you at the theater!')
        end

        it 'reminds a virtual-only order about the stream without pickup or visit copy' do
          regular_production.update!(allow_late_seating: false)
          text = text_of(OrderMailer.performance_reminder(virtual_order, nil, nil, true))

          expect(text).to include('Just a reminder: the stream is at')
          expect(text).to include(stream_note)
          expect(text).not_to include('box office')
          expect(text).not_to include('About your visit')
          expect(text).not_to include('See you at the theater')
          expect(text).not_to include('0 tickets')
          expect(text).not_to include('no late seating')
        end

        it 'gives a mixed order both summaries and the visit block' do
          text = text_of(OrderMailer.performance_reminder(mixed_order, nil, nil, true))

          expect(text).to include('Just a reminder, you have')
          expect(text).to include('You also have 1 virtual ticket for this performance.')
          expect(text).to include("About your visit to #{house.name}")
          expect(text).to include('See you at the theater!')
        end

        it 'counts in-person and virtual tickets but not an other-class drink in the ticket total' do
          text = text_of(OrderMailer.performance_reminder(drink_and_stream_order, nil, nil, true))

          expect(text).to include('Just a reminder, you have 3 tickets at')
          expect(text).not_to match(/\b[24] tickets\b/)
          expect(text).to include(drink_note)
          expect(text).to include('You also have 1 virtual ticket for this performance.')
          expect(text).to include(stream_note)
        end

        it 'counts a seat-holding virtual ticket once in the ticket total' do
          order = add_virtual_tickets(regular_order, 1, holds_seats: true)
          text = text_of(OrderMailer.performance_reminder(order, nil, nil, true))

          expect(text).to include('Just a reminder, you have 3 tickets at')
          expect(text).not_to match(/\b4 tickets\b/)
        end
      end
    end

    describe '"Also playing" sidebar' do
      def eligible_production(**attrs)
        FactoryBot.create(:production, {
          theater: theater,
          venue: venue,
          status: Production::ACTIVE,
          production_class: Production::PRIMETIME,
          opening_at: Date.current,
          first_preview_at: Date.current,
          closing_at: Time.now.end_of_week + 2.weeks
        }.merge(attrs))
      end

      it 'renders an active festival once, linking to its landing page when enabled' do
        festival = FactoryBot.create(:festival, status: Festival::ACTIVE, landing_page_enabled: true,
                                                url_name: 'fringe-fest')
        first_member = eligible_production(festival: festival)
        eligible_production(festival: festival)

        mail = OrderMailer.ticket_confirmation(regular_order)

        expect(mail.body.encoded.scan(festival.name).size).to eq(1)
        expect(mail.body.encoded).not_to include(first_member.name)
        expect(mail.body.encoded).to include('/festivals/fringe-fest')
      end

      it 'links to the box office anchor when the landing page is disabled' do
        festival = FactoryBot.create(:festival, status: Festival::ACTIVE, landing_page_enabled: false)
        eligible_production(festival: festival)
        eligible_production(festival: festival)

        mail = OrderMailer.ticket_confirmation(regular_order)

        expect(mail.body.encoded.scan(festival.name).size).to eq(1)
        expect(mail.body.encoded).to include("/productions/box_office")
        expect(mail.body.encoded).to include("festival-#{festival.id}")
      end
    end
  end
  describe 'presenter-aware follow-ups and transactional emails' do
    let!(:house) { FactoryBot.create(:theater, name: 'House Theater') }
    let(:address) { FactoryBot.create(:address, email: 'patron@example.com') }
    let(:venue) { FactoryBot.create(:venue) }
    let(:payment_type) { FactoryBot.create(:cash_payment_type) }
    let(:producing_theater) { FactoryBot.create(:theater) }
    let(:visiting_theater) { FactoryBot.create(:theater, theater_class: Theater::VISITING) }

    def order_for(theater, follow_up_message_2: nil)
      production = FactoryBot.create(:production,
                                     theater: theater,
                                     venue: venue,
                                     production_class: Production::PRIMETIME,
                                     follow_up_message_2: follow_up_message_2)
      performance = FactoryBot.create(:performance, production: production)
      FactoryBot.create(:ticket_order, :for_a_pair_of_tickets,
                        performance: performance,
                        address: address,
                        payment_type: payment_type)
    end

    describe '#standard_followup' do
      context 'for a default (producing) theater' do
        let(:order) { order_for(producing_theater) }

        it 'keeps the personal letter: sent by the artistic director with the current subject' do
          mail = OrderMailer.standard_followup(order)
          expect(mail.from).to eq(['director@yourtheater.org'])
          expect(mail.subject).to eq('Nice to see you again')
        end

        it 'keeps the letter sections and renders the shared survey prompt' do
          body = OrderMailer.standard_followup(order).body.decoded
          expect(body).to include('Tell us about it')
          expect(body).to include('Stay in touch')
          expect(body).to include('Tell us what you thought of')
          expect(body).to include('fill out a brief survey')
          expect(body).not_to include("A note from #{house.name}")
        end

        it 'does not place a virtual-only patron at the theater' do
          order.ticket_line_items.each { |tli| tli.ticket_class.update!(admission: 'virtual') }
          body = OrderMailer.standard_followup(order.reload).body.decoded

          expect(body).to include('We hope you enjoyed the performance')
          expect(body).not_to include('here at the theater')
          expect(body).to include('about your experience with')
          expect(body).not_to include('in our home here')
        end

        it 'invites an in-person patron to describe their experience in the house' do
          body = OrderMailer.standard_followup(order).body.decoded

          expect(body).to include('about your experience in our home here at')
        end
      end

      context 'for a visiting theater' do
        let(:order) { order_for(visiting_theater, follow_up_message_2: 'A word from **the visiting company**') }

        it 'is sent by the box office with a show-centered subject' do
          mail = OrderMailer.standard_followup(order)
          expect(mail.from).to eq(['boxoffice@yourtheater.org'])
          expect(mail.subject).to eq("Thanks for coming to #{order.performance.production.name}")
        end

        it 'leads with the presenting company message, then the survey, then the host callout' do
          body = OrderMailer.standard_followup(order).body.decoded
          expect(body).to include('the visiting company')
          expect(body).to include("A note from #{house.name}")
          expect(body).to include('Stay in touch')
          expect(body).to include('Test Director')
          custom_at  = body.index('the visiting company')
          survey_at  = body.index('Tell us what you thought of')
          callout_at = body.index("A note from #{house.name}")
          expect(custom_at).to be < survey_at
          expect(survey_at).to be < callout_at
        end

        it 'falls back to a neutral thanks when the company wrote no message' do
          plain_order = order_for(visiting_theater)
          body = OrderMailer.standard_followup(plain_order).body.decoded
          expect(body).to include('We hope you enjoyed the performance')
          expect(body).not_to include('We hope you had a good time here at the theater')
        end
      end
    end

    describe '#first_time_followup' do
      it 'no longer generates a special offer' do
        order = order_for(producing_theater)
        expect { OrderMailer.first_time_followup(order).message }.not_to change(SpecialOffer, :count)
      end

      it 'keeps the personal letter for producing theaters' do
        mail = OrderMailer.first_time_followup(order_for(producing_theater))
        expect(mail.from).to eq(['director@yourtheater.org'])
        expect(mail.subject).to eq("Thanks for coming to #{house.name}")
      end

      it 'sends the box office version with the welcome pitch in the host callout for visiting theaters' do
        order = order_for(visiting_theater)
        mail = OrderMailer.first_time_followup(order)
        expect(mail.from).to eq(['boxoffice@yourtheater.org'])
        expect(mail.subject).to eq("Thanks for coming to #{order.performance.production.name}")
        body = mail.body.decoded
        expect(body).to include("A note from #{house.name}")
        expect(body).to include("welcome you to #{house.name}")
      end
    end

    describe '#member_followup' do
      it 'preserves the current editorial format even for visiting theaters' do
        order = order_for(visiting_theater)
        mail = OrderMailer.member_followup(order)
        expect(mail.from).to eq(['director@yourtheater.org'])
        expect(mail.subject).to eq("Thanks for coming to #{order.performance.production.name}")
        body = mail.body.decoded
        expect(body).to include('As a member')
        expect(body).to include('Tell us what you thought of')
        expect(body).not_to include("A note from #{house.name}")
      end
    end

    describe 'presenter identity on transactional emails' do
      it 'features the presenting company on confirmations for visiting theaters' do
        order = order_for(visiting_theater)
        body = OrderMailer.ticket_confirmation(order).body.decoded
        expect(body).to include('Presented by')
        expect(body).to include(visiting_theater.name)
      end

      it 'does not add a presenter block for producing theaters' do
        order = order_for(producing_theater)
        body = OrderMailer.ticket_confirmation(order).body.decoded
        expect(body).not_to include('Presented by')
      end

      it 'features the presenting company on reminders for visiting theaters' do
        order = order_for(visiting_theater)
        body = OrderMailer.performance_reminder(order, nil, nil, true).body.decoded
        expect(body).to include('Presented by')
        expect(body).to include(visiting_theater.name)
      end
    end
  end
end
