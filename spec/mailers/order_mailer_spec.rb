require 'rails_helper'

RSpec.describe OrderMailer, type: :mailer do
  describe 'emails for different production types' do
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
                        production_class: Production::PLAY)
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
        expect(mail.body.encoded).to include('Dining')
        expect(mail.body.encoded).to include('Handy stuff')
        expect(mail.body.encoded).to include('Getting Here')
      end

      it 'excludes box office references for external productions' do
        mail = OrderMailer.ticket_confirmation(external_order)

        expect(mail.body.encoded).not_to include('box office')
        expect(mail.body.encoded).not_to include('Handy stuff')
        expect(mail.body.encoded).not_to include('Dining')
        expect(mail.body.encoded).not_to include('Getting Here')
      end

      it 'excludes box office references for conference productions' do
        mail = OrderMailer.ticket_confirmation(conference_order)

        expect(mail.body.encoded).not_to include('box office')
        expect(mail.body.encoded).not_to include('Handy stuff')
        expect(mail.body.encoded).not_to include('Dining')
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
        expect(mail.body.encoded).to include('Handy stuff you')
        expect(mail.body.encoded).to include('Dining Recommendations')
        expect(mail.body.encoded).to include('Getting Here')
      end

      it 'excludes box office references for external productions' do
        mail = OrderMailer.performance_reminder(external_order, nil, nil, true)

        expect(mail.body.encoded).not_to include('box office')
        expect(mail.body.encoded).not_to include('See you at the theater')
        expect(mail.body.encoded).not_to include('Handy stuff you')
        expect(mail.body.encoded).not_to include('Dining Recommendations')
        expect(mail.body.encoded).not_to include('Getting Here')
      end

      it 'excludes box office references for conference productions' do
        mail = OrderMailer.performance_reminder(conference_order, nil, nil, true)

        expect(mail.body.encoded).not_to include('box office')
        expect(mail.body.encoded).not_to include('See you at the theater')
        expect(mail.body.encoded).not_to include('Handy stuff you')
        expect(mail.body.encoded).not_to include('Dining Recommendations')
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

    describe '"Also playing" sidebar' do
      def eligible_production(**attrs)
        FactoryBot.create(:production, {
          theater: theater,
          venue: venue,
          status: Production::ACTIVE,
          production_class: Production::PLAY,
          opening_at: Date.today,
          first_preview_at: Date.today,
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
end
