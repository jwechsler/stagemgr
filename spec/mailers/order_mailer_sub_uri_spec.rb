require 'rails_helper'

# The app is mounted under a sub-URI (server.yml `sub_uri`). Passenger exports
# RAILS_RELATIVE_URL_ROOT so route helpers prefix it, but a Resque worker
# sending the same mail has no such env. Mail must carry the mount point
# exactly once either way: folding it into the host instead produced
# /tickets/tickets/... for mail delivered inline from a web request, which
# 404'd every sidebar image and link.
RSpec.describe OrderMailer, type: :mailer do
  describe 'URLs under a sub-URI mount' do
    let(:mount_point) { '/tickets' }
    let(:url_options) do
      MailerUrlOptions.for('host' => 'www.example.org', 'host_protocol' => 'https', 'sub_uri' => mount_point)
    end

    let(:theater) { FactoryBot.create(:theater) }
    let(:venue) { FactoryBot.create(:venue) }
    let(:address) { FactoryBot.create(:address, email: 'customer@example.com') }
    let(:payment_type) { FactoryBot.create(:cash_payment_type) }

    let(:production) do
      FactoryBot.create(:production, theater: theater, venue: venue,
                                     name: 'Booked Show', production_class: Production::PRIMETIME)
    end
    let(:performance) { FactoryBot.create(:performance, production: production) }
    let(:order) do
      FactoryBot.create(:ticket_order, :for_a_pair_of_tickets,
                        performance: performance, address: address, payment_type: payment_type,
                        status: Order::PROCESSED)
    end

    # 1x1 transparent PNG, enough for the sidebar variant to be generated.
    let(:tiny_png) do
      Base64.decode64(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
      )
    end

    # The "Also playing at …" sidebar renders an Active Storage variant of this
    # production's promo -- the URL that was reported broken.
    let!(:sidebar_production) do
      FactoryBot.create(:production, theater: theater, venue: venue,
                                     name: 'Also Playing', production_class: Production::PRIMETIME,
                                     status: Production::ACTIVE,
                                     opening_at: Date.current, closing_at: Date.current + 6.weeks).tap do |sidebar|
        sidebar.promo.attach(io: StringIO.new(tiny_png), filename: 'promo.png', content_type: 'image/png')
      end
    end

    around do |example|
      original = ActionMailer::Base.default_url_options
      ActionMailer::Base.default_url_options = url_options
      example.run
      ActionMailer::Base.default_url_options = original
    end

    def urls_in(mail)
      part = mail.html_part || mail
      part.body.decoded.scan(%r{https://www\.example\.org[^"'\s>]*})
    end

    shared_examples 'a mail mounted once at the sub-URI' do
      it 'prefixes every link with the mount point exactly once' do
        urls = urls_in(OrderMailer.ticket_confirmation(order))

        expect(urls).to be_present
        expect(urls).to all(start_with('https://www.example.org/tickets/'))
        expect(urls).to all(exclude_doubled_mount)
      end

      it 'prefixes the sidebar image once' do
        urls = urls_in(OrderMailer.ticket_confirmation(order))
        image_urls = urls.grep(%r{/rails/active_storage/})

        expect(image_urls).to be_present
        expect(image_urls).to all(start_with('https://www.example.org/tickets/rails/active_storage/'))
      end

      # The masthead resolves its own variant URL rather than going through the
      # decorator, so it needs the same proof as the sidebar image: a mount
      # point, present exactly once.
      it 'prefixes the masthead logo once' do
        theater.logo.attach(io: StringIO.new(tiny_png), filename: 'logo.png', content_type: 'image/png')

        body = OrderMailer.ticket_confirmation(order).body.decoded
        masthead = body[/<img[^>]*alt=['"]#{Regexp.escape(theater.name)}['"][^>]*>/]

        expect(masthead).to be_present
        expect(masthead).to include('https://www.example.org/tickets/rails/active_storage/')
        expect(masthead).not_to include('/tickets/tickets')
      end
    end

    matcher :exclude_doubled_mount do
      match { |url| url.exclude?('/tickets/tickets') }
      failure_message { |url| "expected #{url} not to repeat the /tickets mount point" }
    end

    context 'in a worker process, where relative_url_root is unset' do
      before { allow(Rails.application.routes).to receive(:relative_url_root).and_return(nil) }

      it_behaves_like 'a mail mounted once at the sub-URI'
    end

    context 'inside Passenger, where relative_url_root is the mount point' do
      before { allow(Rails.application.routes).to receive(:relative_url_root).and_return(mount_point) }

      it_behaves_like 'a mail mounted once at the sub-URI'
    end
  end
end
