require "rails_helper"

# All Stripe API calls are stubbed — no network calls are made.
RSpec.describe StripeGateway, type: :model do
  # StripeGateway inherits from ActiveMerchant::Billing::StripePaymentIntentsGateway
  # which requires a :login (API key). We pass a test key so the object can be
  # instantiated without a real credential.
  let(:test_api_key) { "sk_test_fakekeyfortesting" }
  let(:live_api_key) { "sk_live_fakekeyfortesting" }
  let(:gateway) { StripeGateway.new(login: test_api_key) }

  before do
    allow(Stripe).to receive(:api_key).and_return(test_api_key)
  end

  # ---------------------------------------------------------------------------
  # #external_type
  # ---------------------------------------------------------------------------
  describe "#external_type" do
    it "returns 'invoice' for transaction ids starting with 'in_'" do
      expect(gateway.external_type("in_1234567890")).to eq("invoice")
    end

    it "returns 'subscription' for transaction ids starting with 'sub_'" do
      expect(gateway.external_type("sub_1234567890")).to eq("subscription")
    end

    it "returns 'payment' for transaction ids starting with 'pm_'" do
      expect(gateway.external_type("pm_1234567890")).to eq("payment")
    end

    it "returns 'unknown' for unrecognized prefixes" do
      expect(gateway.external_type("ch_1234567890")).to eq("unknown")
    end

    it "returns 'unknown' for a nil transaction_id" do
      expect(gateway.external_type(nil)).to eq("unknown")
    end

    it "returns 'unknown' for an empty string" do
      # NOTE: SUSPECTED BUG (stripe_gateway.rb:124): The `case` statement uses
      # `when transaction_id.nil?` as the first branch, then calls
      # `transaction_id.starts_with?(...)` on subsequent branches.
      # An empty string is not nil, so it falls through to starts_with? calls
      # which return false, resulting in 'unknown'. This is the actual behavior.
      expect(gateway.external_type("")).to eq("unknown")
    end
  end

  # ---------------------------------------------------------------------------
  # #external_url (test mode)
  # ---------------------------------------------------------------------------
  describe "#external_url" do
    context "in test mode (api_key starts with sk_test)" do
      it "builds a test invoice URL for 'in_' prefixed ids" do
        url = gateway.external_url("in_abc123")
        expect(url).to eq("https://dashboard.stripe.com/test/invoices/in_abc123")
      end

      it "builds a test subscription URL for 'sub_' prefixed ids" do
        url = gateway.external_url("sub_abc123")
        expect(url).to eq("https://dashboard.stripe.com/test/subscriptions/sub_abc123")
      end

      it "builds a test payment URL for 'pm_' prefixed ids" do
        url = gateway.external_url("pm_abc123")
        expect(url).to eq("https://dashboard.stripe.com/test/payments/pm_abc123")
      end

      it "builds an 'unknown' URL for unrecognized ids" do
        url = gateway.external_url("ch_abc123")
        expect(url).to eq("https://dashboard.stripe.com/test/unknowns/ch_abc123")
      end
    end

    context "in live mode (api_key starts with sk_live)" do
      before { allow(Stripe).to receive(:api_key).and_return(live_api_key) }

      it "builds a live invoice URL for 'in_' prefixed ids" do
        url = gateway.external_url("in_abc123")
        expect(url).to eq("https://dashboard.stripe.com/invoices/in_abc123")
      end

      it "builds a live subscription URL for 'sub_' prefixed ids" do
        url = gateway.external_url("sub_abc123")
        expect(url).to eq("https://dashboard.stripe.com/subscriptions/sub_abc123")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # #subscription_url
  # ---------------------------------------------------------------------------
  describe "#subscription_url" do
    context "in test mode" do
      it "returns a test subscription URL for sub_ ids" do
        url = gateway.subscription_url("sub_abc123")
        expect(url).to eq("https://dashboard.stripe.com/test/subscriptions/sub_abc123")
      end

      it "returns '#' when subscription_id does not start with 'sub'" do
        expect(gateway.subscription_url("pm_abc123")).to eq("#")
      end

      it "returns '#' when subscription_id is nil" do
        expect(gateway.subscription_url(nil)).to eq("#")
      end
    end

    context "in live mode" do
      before { allow(Stripe).to receive(:api_key).and_return(live_api_key) }

      it "returns a live subscription URL for sub_ ids" do
        url = gateway.subscription_url("sub_abc123")
        expect(url).to eq("https://dashboard.stripe.com/subscriptions/sub_abc123")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # #product_url
  # ---------------------------------------------------------------------------
  describe "#product_url" do
    context "in test mode" do
      it "returns a test price URL" do
        url = gateway.product_url("price_abc123")
        expect(url).to eq("https://dashboard.stripe.com/test/prices/price_abc123")
      end
    end

    context "in live mode" do
      before { allow(Stripe).to receive(:api_key).and_return(live_api_key) }

      it "returns a live price URL" do
        url = gateway.product_url("price_abc123")
        expect(url).to eq("https://dashboard.stripe.com/prices/price_abc123")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # #subscription (retrieve)
  # ---------------------------------------------------------------------------
  describe "#subscription" do
    it "delegates to Stripe::Subscription.retrieve with the given id" do
      fake_subscription = double("Stripe::Subscription", id: "sub_xyz")
      expect(Stripe::Subscription).to receive(:retrieve).with("sub_xyz").and_return(fake_subscription)

      result = gateway.subscription("sub_xyz")
      expect(result).to eq(fake_subscription)
    end
  end

  # ---------------------------------------------------------------------------
  # #create_subscription
  # ---------------------------------------------------------------------------
  describe "#create_subscription" do
    # Build a minimal order double with all attributes that create_subscription
    # reads from the order.
    let(:fake_address) do
      double("Address",
             id: 42,
             full_name: "John Doe",
             parse_full_name: %w[John Doe],
             line1: "123 Main St",
             line2: nil,
             city: "Springfield",
             state: "IL",
             zipcode: "62701",
             email: "john@example.com",
             phone: "555-1234",
             processor_id: nil,
             'processor_id=': nil)
    end

    let(:fake_recurring_offer) do
      double("RecurringOffer", price_id: "price_test123")
    end

    let(:fake_order) do
      double("MembershipOrder",
             address: fake_address,
             recurring_offer: fake_recurring_offer,
             credit_card_type: "visa",
             credit_card_number: "4111111111111111",
             credit_card_expiration_month: "12",
             credit_card_expiration_year: "2025",
             'credit_card_expiration_year=': nil,
             credit_card_verification_number: "123",
             gift?: false,
             id: 99)
    end

    let(:fake_stripe_price) do
      double("Stripe::Price", product: "prod_test123")
    end

    let(:fake_stripe_product) do
      double("Stripe::Product", id: "prod_test123", name: "Test Membership")
    end

    let(:fake_payment_method) do
      double("Stripe::PaymentMethod", id: "pm_test123")
    end

    let(:fake_customer) do
      double("Stripe::Customer", id: "cus_test123")
    end

    let(:fake_subscription) do
      double("Stripe::Subscription", id: "sub_test123")
    end

    before do
      # Stub Order.fix_expiration_year as it's called as a class method
      allow(Order).to receive(:fix_expiration_year).and_return("2025")

      # Stub PaymentProcessing.credit_card
      fake_card = double("ActiveMerchant::Billing::CreditCard",
                         number: "4111111111111111",
                         month: "12",
                         year: "2025",
                         verification_value: "123")
      allow(PaymentProcessing).to receive(:credit_card).and_return(fake_card)

      # Stub all Stripe API calls
      allow(Stripe::Price).to receive(:retrieve).with("price_test123").and_return(fake_stripe_price)
      allow(Stripe::Product).to receive(:retrieve).with("prod_test123").and_return(fake_stripe_product)
      allow(Stripe::PaymentMethod).to receive(:create).and_return(fake_payment_method)
      allow(Stripe::Customer).to receive(:create).and_return(fake_customer)
      allow(Stripe::PaymentMethod).to receive(:attach).and_return(true)
      allow(Stripe::Customer).to receive(:update).and_return(fake_customer)
      allow(Stripe::Subscription).to receive(:create).and_return(fake_subscription)

      # Allow address.processor_id to be set
      allow(fake_address).to receive(:processor_id=)
    end

    it "retrieves the price from Stripe using the recurring_offer's price_id" do
      expect(Stripe::Price).to receive(:retrieve).with("price_test123").and_return(fake_stripe_price)
      gateway.create_subscription(fake_order)
    end

    it "creates a Stripe::Customer when address has no processor_id" do
      allow(fake_address).to receive(:processor_id).and_return(nil)
      expect(Stripe::Customer).to receive(:create).and_return(fake_customer)
      gateway.create_subscription(fake_order)
    end

    it "creates a Stripe::PaymentMethod of type 'card'" do
      expect(Stripe::PaymentMethod).to receive(:create).with(
        hash_including(type: "card")
      ).and_return(fake_payment_method)
      gateway.create_subscription(fake_order)
    end

    it "attaches the payment method to the customer" do
      expect(Stripe::PaymentMethod).to receive(:attach).with(
        "pm_test123",
        { customer: "cus_test123" }
      )
      gateway.create_subscription(fake_order)
    end

    it "creates a subscription with the price_id and customer" do
      expect(Stripe::Subscription).to receive(:create).with(
        hash_including(
          customer: "cus_test123",
          payment_behavior: "error_if_incomplete"
        )
      ).and_return(fake_subscription)
      gateway.create_subscription(fake_order)
    end

    it "returns the subscription id" do
      result = gateway.create_subscription(fake_order)
      expect(result).to eq("sub_test123")
    end

    context "when address already has a processor_id" do
      # Previously a bug lived here (stripe_gateway.rb): the else branch called
      # `Stripe::Customer.retrieve(customer.processor_id)`, but `customer` was an
      # as-yet-unassigned local in this branch, so `nil.processor_id` raised
      # NoMethodError and a returning Stripe customer could never renew. The
      # receiver is now `order.address.processor_id`, so the existing customer is
      # retrieved and the rescue fallback is reachable.
      before do
        allow(fake_address).to receive(:processor_id).and_return("cus_existing")
        allow(Stripe::Customer).to receive(:retrieve).with("cus_existing").and_return(fake_customer)
      end

      it "retrieves the existing Stripe customer by its processor_id" do
        expect(Stripe::Customer).to receive(:retrieve).with("cus_existing").and_return(fake_customer)
        gateway.create_subscription(fake_order)
      end

      it "does not create a new customer when one already exists" do
        expect(Stripe::Customer).not_to receive(:create)
        gateway.create_subscription(fake_order)
      end

      it "still creates the subscription for the retrieved customer" do
        expect(Stripe::Subscription).to receive(:create).and_return(fake_subscription)
        expect(gateway.create_subscription(fake_order)).to eq(fake_subscription.id)
      end

      context "and Stripe no longer has that customer" do
        # The rescue branch is now reachable: a stale processor_id makes
        # retrieve raise InvalidRequestError, and the code falls back to
        # creating a fresh customer rather than crashing.
        before do
          allow(Stripe::Customer).to receive(:retrieve).with("cus_existing").and_raise(
            Stripe::InvalidRequestError.new("No such customer", "customer")
          )
        end

        it "falls back to creating a new customer" do
          expect(Stripe::Customer).to receive(:create).and_return(fake_customer)
          gateway.create_subscription(fake_order)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Shared card/customer setup for #create_subscription gift ends and
  # #charge_one_time
  # ---------------------------------------------------------------------------
  shared_context "a stubbed Stripe customer" do
    let(:offer) do
      FactoryBot.build(:membership_offer, price_id: "price_test123", billing_interval: "month",
                                          billing_interval_count: 1, billing_period_synced_at: Time.current)
    end
    let(:address) do
      double("Address", id: 42, full_name: "Jane Doe", parse_full_name: %w[Jane Doe], line1: "1 Main St",
                        line2: nil, city: "Chicago", state: "IL", zipcode: "60601", email: "jane@example.com",
                        phone: "555-1234", processor_id: nil, 'processor_id=': nil)
    end
    let(:gift) { false }
    let(:order) do
      double("MembershipOrder", address: address, recurring_offer: offer, credit_card_type: "visa",
                                credit_card_number: "4111111111111111", credit_card_expiration_month: "12",
                                credit_card_expiration_year: "2030", 'credit_card_expiration_year=': nil,
                                credit_card_verification_number: "123", gift?: gift, id: 77)
    end
    let(:customer) { double("Stripe::Customer", id: "cus_77") }

    before do
      allow(PaymentProcessing).to receive(:credit_card)
        .and_return(double("CreditCard", number: "4111111111111111", month: "12", year: "2030",
                                         verification_value: "123"))
      allow(Stripe::PaymentMethod).to receive(:create).and_return(double("Stripe::PaymentMethod", id: "pm_77"))
      allow(Stripe::Customer).to receive(:create).and_return(customer)
      allow(Stripe::PaymentMethod).to receive(:attach)
      allow(Stripe::Customer).to receive(:update).and_return(customer)
    end
  end

  # ---------------------------------------------------------------------------
  # #refund_one_time
  # ---------------------------------------------------------------------------
  describe "#refund_one_time" do
    it "refunds the invoice's charge with the given metadata, once per invoice" do
      allow(Stripe::Invoice).to receive(:retrieve).with("in_77").and_return(double("Stripe::Invoice", charge: "ch_77"))
      allow(Stripe::Refund).to receive(:create)

      gateway.refund_one_time("in_77", { source: "stagemgr", order_id: 77 })

      expect(Stripe::Refund).to have_received(:create).with({ charge: "ch_77", metadata: { source: "stagemgr", order_id: 77 } },
                                                            { idempotency_key: "one-time-reversal-in_77" })
    end
  end

  # ---------------------------------------------------------------------------
  # #create_subscription for a gift: ends after max_cycles_if_gift periods
  # ---------------------------------------------------------------------------
  describe "#create_subscription for a gift" do
    include_context "a stubbed Stripe customer"

    let(:gift) { true }

    before do
      allow(Stripe::Price).to receive(:retrieve).and_return(double("Stripe::Price", product: "prod_77"))
      allow(Stripe::Product).to receive(:retrieve)
      allow(Stripe::Subscription).to receive(:create).and_return(double("Stripe::Subscription", id: "sub_77"))
    end

    # Noon CDT is 17:00 UTC; Stripe's period boundaries keep the UTC hour.
    around { |example| travel_to(Time.zone.local(2026, 10, 6, 12, 0, 0)) { example.run } }

    def created_params
      gateway.create_subscription(order)
      params = nil
      expect(Stripe::Subscription).to have_received(:create) { |p| params = p }
      params
    end

    it "cancels a monthly gift after its gift length in months, without proration" do
      offer.max_cycles_if_gift = 3

      expect(created_params).to include(cancel_at: Time.utc(2027, 1, 6, 17).to_i,
                                        proration_behavior: "none")
    end

    it "cancels a yearly gift after its gift length in years" do
      offer.assign_attributes(billing_interval: "year", max_cycles_if_gift: 2)

      expect(created_params).to include(cancel_at: Time.utc(2028, 10, 6, 17).to_i)
    end

    it "syncs an unsynced offer before computing the end" do
      offer.assign_attributes(billing_interval: nil, billing_interval_count: nil, max_cycles_if_gift: 1)
      allow(offer).to receive(:sync_billing_period!) { offer.assign_attributes(billing_interval: "year") }

      expect(created_params).to include(cancel_at: Time.utc(2027, 10, 6, 17).to_i)
      expect(offer).to have_received(:sync_billing_period!)
    end

    # Created in July (CDT), ending in January (CST): Stripe's last boundary is
    # 20:00 UTC, and an end even an hour later bills the buyer a 7th month.
    it "never cancels after the final UTC period boundary across a DST change" do
      offer.max_cycles_if_gift = 6
      start = Time.zone.local(2026, 7, 1, 15, 0)

      travel_back
      travel_to(start)
      cancel_at = created_params[:cancel_at]

      expect(cancel_at).to eq(Time.utc(2027, 1, 1, 20).to_i)
      expect(cancel_at).to be <= (start.utc + 6.months).to_i
    end

    it "renews indefinitely when the offer sets no gift length" do
      offer.max_cycles_if_gift = nil

      expect(created_params).not_to include(:cancel_at, :proration_behavior)
    end

    context "when the order is not a gift" do
      let(:gift) { false }

      it "sets no cancel_at" do
        offer.max_cycles_if_gift = 3

        expect(created_params).not_to include(:cancel_at)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # #charge_one_time
  # ---------------------------------------------------------------------------
  describe "#charge_one_time" do
    include_context "a stubbed Stripe customer"

    let(:invoice) { double("Stripe::Invoice", id: "in_77") }
    let(:paid_invoice) { double("Stripe::Invoice", id: "in_77", amount_paid: 15_000) }

    before do
      allow(Stripe::InvoiceItem).to receive(:create)
      allow(Stripe::Invoice).to receive(:create).and_return(invoice)
      allow(Stripe::Invoice).to receive(:finalize_invoice).and_return(invoice)
      allow(Stripe::Invoice).to receive(:pay).and_return(paid_invoice)
      allow(Stripe::Invoice).to receive(:void_invoice)
      allow(Stripe::Subscription).to receive(:create)
    end

    it "invoices the one-time price, finalizes and pays it, and returns the paid invoice" do
      expect(gateway.charge_one_time(order)).to eq(paid_invoice)

      expect(Stripe::InvoiceItem).to have_received(:create).with({ customer: "cus_77", invoice: "in_77", price: "price_test123" })
      expect(Stripe::Invoice).to have_received(:create).with(
        hash_including(customer: "cus_77", collection_method: "charge_automatically",
                       pending_invoice_items_behavior: "exclude", auto_advance: false,
                       metadata: { stagemgr_order_id: 77 })
      )
      expect(Stripe::Invoice).to have_received(:finalize_invoice).with("in_77")
      expect(Stripe::Invoice).to have_received(:pay).with("in_77")
      expect(Stripe::Subscription).not_to have_received(:create)
    end

    it "attaches the card as the customer's default payment method" do
      gateway.charge_one_time(order)

      expect(Stripe::PaymentMethod).to have_received(:attach).with("pm_77", { customer: "cus_77" })
    end

    it "voids the invoice and re-raises when the card is declined" do
      allow(Stripe::Invoice).to receive(:pay).and_raise(Stripe::CardError.new("Your card was declined.", nil))

      expect { gateway.charge_one_time(order) }.to raise_error(Stripe::CardError, /declined/)
      expect(Stripe::Invoice).to have_received(:void_invoice).with("in_77")
    end

    it "still reports the decline when voiding also fails" do
      allow(Stripe::Invoice).to receive(:pay).and_raise(Stripe::CardError.new("Your card was declined.", nil))
      allow(Stripe::Invoice).to receive(:void_invoice).and_raise(Stripe::InvalidRequestError.new("nope", nil))

      expect { gateway.charge_one_time(order) }.to raise_error(Stripe::CardError)
    end
  end

  # ---------------------------------------------------------------------------
  # #price_billing_period
  # ---------------------------------------------------------------------------
  describe "#price_billing_period" do
    it "returns the interval and count of a recurring price" do
      recurring = double("recurring", interval: "year", interval_count: 2)
      allow(Stripe::Price).to receive(:retrieve).with("price_year")
                                                .and_return(double("Stripe::Price", recurring: recurring))

      expect(gateway.price_billing_period("price_year")).to eq(interval: "year", interval_count: 2)
    end

    it "returns one_time for a price that does not recur" do
      allow(Stripe::Price).to receive(:retrieve).with("price_once")
                                                .and_return(double("Stripe::Price", recurring: nil))

      expect(gateway.price_billing_period("price_once")).to eq(interval: "one_time", interval_count: nil)
    end
  end

  # ---------------------------------------------------------------------------
  # Inherited ActiveMerchant methods
  # ---------------------------------------------------------------------------
  # ActiveMerchant's #purchase calls its own private helpers by name, so a
  # StripeGateway helper with the same name silently replaces them and breaks
  # every card sale (a one-argument create_payment_method did exactly that).
  describe "inherited ActiveMerchant methods" do
    it "are not shadowed by StripeGateway's own methods" do
      own = described_class.instance_methods(false) + described_class.private_instance_methods(false)
      parent = described_class.superclass
      inherited = parent.instance_methods + parent.private_instance_methods

      expect(own & inherited).to be_empty
    end
  end
end
