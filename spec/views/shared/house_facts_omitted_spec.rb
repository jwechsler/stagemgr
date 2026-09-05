require 'rails_helper'

# A house that has configured no phone, address or pickup window still has to
# read like English. Every public sentence built from a `theater:` fact guards
# itself, and the failure mode when a guard is wrong is not an exception -- it
# is "...at our box office ." on a confirmation page. So each of those sentences
# is rendered here against a TheaterInfo with nothing configured, and checked
# for dangling punctuation.
#
# The configured side of the same sentences is covered where the page itself is
# (the cucumber order features, the calendar view spec).
RSpec.describe 'public copy with no house facts configured', type: :view do
  let(:unconfigured) { TheaterInfo.new(server_config: {}, email_addresses: {}) }

  before { allow(view).to receive(:theater_info).and_return(unconfigured) }

  # These templates render sibling partials by bare name, which resolves against
  # the controller's prefix -- a view spec has none until it is told.
  def render_from(prefix, **args)
    view.lookup_context.prefixes = [prefix]
    render(**args)
  end

  # Tag soup to readable prose, so "box office ." is visible to an assertion.
  def text
    CGI.unescapeHTML(rendered.gsub(/<[^>]*>/, ' ')).squish
  end

  # A space before a full stop or comma, or a doubled one: the tell-tale of a
  # sentence assembled from a fact that turned out to be missing.
  def expect_no_dangling_punctuation
    expect(text).not_to match(/\s[.,]/)
    expect(text).not_to match(/[.,]{2}/)
  end

  describe 'shared/_box_office_help' do
    it 'renders nothing rather than inviting patrons to call nobody' do
      render partial: 'shared/box_office_help'

      expect(rendered.strip).to be_empty
    end
  end

  describe 'shared/_mailing_list_optin_label' do
    it 'names the house alone and drops the blurb' do
      render partial: 'shared/mailing_list_optin_label'

      expect(text).to eq("Join the #{unconfigured.name} mailing list.")
      expect_no_dangling_punctuation
    end

    it 'names a partner company when one is given' do
      partner = FactoryBot.create(:theater, name: 'Visiting Company')

      render partial: 'shared/mailing_list_optin_label', locals: { other_theater: partner }

      expect(text).to eq("Join the #{unconfigured.name} and Visiting Company mailing lists.")
    end
  end

  describe 'ticket_orders/show' do
    it 'ends the pickup sentence cleanly and offers no phone or email' do
      order = FactoryBot.create(:ticket_order, :for_a_single_ticket, :paid_with_cash)
      assign(:ticket_order, order)

      render_from 'ticket_orders', template: 'ticket_orders/show'

      expect(text).to include('available for pickup under your name at our box office.')
      expect(text).not_to include('call us at')
      expect(text).not_to include('reach us by email')
      expect_no_dangling_punctuation
    end
  end

  describe 'ticket_orders/_edit' do
    it 'says sales are in person at our theater, with no address' do
      # happening_soon? compares wall-clock time in two zones and flakes in the
      # late-evening Pacific window; the view's copy is what is under test.
      performance = FactoryBot.create(:performance)
      allow(performance).to receive(:happening_soon?).and_return(true)
      order = TicketOrder.new(performance: performance, status: Order::NEW)

      render_from 'ticket_orders', partial: 'ticket_orders/edit', locals: { order: order }

      expect(text).to include('in person only at our theater.')
      expect_no_dangling_punctuation
    end
  end

  describe 'ticket_orders/confirm' do
    it 'omits the "give us a call" line' do
      order = FactoryBot.create(:ticket_order, :for_a_single_ticket, :paid_with_cash)
      assign(:ticket_order, order)

      render_from 'ticket_orders', template: 'ticket_orders/confirm'

      expect(text).not_to include('Problems?')
      expect_no_dangling_punctuation
    end
  end

  describe 'orders/not_available' do
    it 'says only that the item is gone' do
      render template: 'orders/not_available'

      expect(text).to eq('That item is no longer available for sale.')
    end
  end

  describe 'membership_orders/_thanks' do
    it 'omits the "give us a call" sentence for a straight membership' do
      assign(:order, FactoryBot.create(:membership_order))

      render partial: 'membership_orders/thanks'

      expect(text).to include("you'll get an email in a few minutes.")
      expect(text).not_to include('give us a call')
      expect_no_dangling_punctuation
    end

    it 'omits the membership-card sentence for a gift' do
      order = FactoryBot.create(:membership_order)
      allow(order).to receive(:gift?).and_return(true)
      allow(order).to receive(:recipient_name).and_return('Gift Getter')
      assign(:order, order)

      render partial: 'membership_orders/thanks'

      expect(text).to include('for unlimited theater!')
      expect(text).not_to include('membership card in advance')
      expect_no_dangling_punctuation
    end
  end

  describe 'flex_pass_orders/_flex_pass_detail' do
    it 'thanks the patron without a phone number to call' do
      order = FactoryBot.create(:flex_pass_order)
      offer = order.flex_pass_line_item.flex_pass_offer
      offer.update!(theater: nil)

      render partial: 'flex_pass_orders/flex_pass_detail',
             locals: { flex_pass_offer: offer.reload, flex_pass: order.flex_pass_line_item.flex_pass }

      expect(text).to include("Thank you for supporting #{unconfigured.name}.")
      expect(text).not_to include('call our box office')
      expect_no_dangling_punctuation
    end
  end
end
