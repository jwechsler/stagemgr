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
      # CHARACTERIZATION OF A BUG (stripe_gateway.rb:54-62): When processor_id is
      # present, the else branch runs `Stripe::Customer.retrieve(customer.processor_id)`.
      # The local variable `customer` is only assigned in the `if` branch (line 55),
      # so in this branch Ruby treats it as a defined-but-nil local (the lexical
      # assignment makes it a known local). Calling `nil.processor_id` therefore
      # raises NoMethodError. The intended receiver was almost certainly
      # `order.address.processor_id`.
      #
      # NoMethodError is a subclass of NameError, so the rescue on line 59
      # (rescue Stripe::InvalidRequestError) does NOT catch it; the error
      # propagates to the caller. We assert NoMethodError specifically because
      # that is the exact class raised.
      before do
        allow(fake_address).to receive(:processor_id).and_return("cus_existing")
      end

      it "raises NoMethodError from nil.processor_id (bug at stripe_gateway.rb:58)" do
        expect { gateway.create_subscription(fake_order) }
          .to raise_error(NoMethodError, /processor_id/)
      end

      it "does not reach the Stripe::InvalidRequestError rescue branch (line 60 is dead code)" do
        # If Stripe::Customer.retrieve were reachable here, this stub would make
        # the code follow the rescue path and call create_customer. It never is,
        # because nil.processor_id raises first — so retrieve is never invoked.
        allow(Stripe::Customer).to receive(:retrieve).and_raise(
          Stripe::InvalidRequestError.new("No such customer", "customer")
        )
        expect(Stripe::Customer).not_to receive(:retrieve)
        expect { gateway.create_subscription(fake_order) }.to raise_error(NoMethodError)
      end
    end
  end
end
