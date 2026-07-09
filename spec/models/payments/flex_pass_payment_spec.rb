require 'rails_helper'

RSpec.describe FlexPassPayment, type: :model do
  include_context 'auto-fulfilling print service'

  # A unique ticket class code per offer keeps the :ticket_class factory's
  # unscoped find_or_create_by(class_code:) from colliding with the 'PASS'
  # class (price 6.0) that the production factory creates — reusing that row
  # trips prevent_price_changes_after_sales once redemptions exist.
  def pass_with(**offer_attrs)
    @offer_sequence = (@offer_sequence || 0) + 1
    offer = FactoryBot.create(:flex_pass_offer,
                              use_ticket_class_code: "FPT#{@offer_sequence}",
                              **offer_attrs)
    FactoryBot.create(:flex_pass_order, flex_pass_offer: offer).flex_pass
  end

  # Redeems tickets against the pass; the :paid_with_flex_pass trait creates the
  # FlexPassPayment inside after(:create), so cap violations surface as
  # ActiveRecord::RecordInvalid raised from the order factory itself.
  def redeem(pass, performance, tickets: 1)
    count_trait = tickets == 2 ? :for_a_pair_of_tickets : :for_a_single_ticket
    FactoryBot.create(:ticket_order, count_trait, :paid_with_flex_pass,
                      performance: performance, flex_pass_code: pass.code)
  end

  # The factory's performance_time sequence ignores its counter, and
  # Performance#clean_values rounds times down to 15-minute blocks — stagger
  # by full blocks so same-production performances stay unique.
  def performance_of(production)
    @performance_offset = (@performance_offset || 0) + 1
    FactoryBot.create(:general_admission, production: production,
                      performance_time: Time.now + (@performance_offset * 15).minutes)
  end

  describe 'maximum_uses_per_production cap' do
    let(:production) { FactoryBot.create(:production) }

    it 'allows redemptions up to the cap in a single order' do
      pass = pass_with(maximum_uses_per_production: 2)
      expect { redeem(pass, performance_of(production), tickets: 2) }.not_to raise_error
    end

    it 'rejects a single order that exceeds the cap' do
      pass = pass_with(maximum_uses_per_production: 1)
      expect { redeem(pass, performance_of(production), tickets: 2) }
        .to raise_error(ActiveRecord::RecordInvalid, %r{ticket\(s\)/production})
    end

    it 'accumulates redemptions across orders at different performances of one production' do
      pass = pass_with(maximum_uses_per_production: 1)
      redeem(pass, performance_of(production))
      expect { redeem(pass, performance_of(production)) }
        .to raise_error(ActiveRecord::RecordInvalid, %r{ticket\(s\)/production})
    end

    it 'ignores redemptions on refunded orders' do
      pass = pass_with(maximum_uses_per_production: 1)
      first_order = redeem(pass, performance_of(production))
      first_order.update_column(:status, Order::REFUNDED)
      expect { redeem(pass, performance_of(production)) }.not_to raise_error
    end

    it 'ignores redemptions on other productions' do
      pass = pass_with(maximum_uses_per_production: 1)
      redeem(pass, performance_of(FactoryBot.create(:production)))
      expect { redeem(pass, performance_of(production)) }.not_to raise_error
    end

    it 'treats a nil cap as unlimited' do
      pass = pass_with(maximum_uses_per_production: nil)
      redeem(pass, performance_of(production), tickets: 2)
      expect { redeem(pass, performance_of(production), tickets: 2) }.not_to raise_error
    end

    it 'treats a zero cap as unlimited' do
      pass = pass_with(maximum_uses_per_production: 0)
      redeem(pass, performance_of(production), tickets: 2)
      expect { redeem(pass, performance_of(production), tickets: 2) }.not_to raise_error
    end
  end

  describe 'maximum_uses_per_performance cap' do
    let(:production) { FactoryBot.create(:production) }
    let(:performance) { performance_of(production) }

    it 'allows a redemption within the cap' do
      pass = pass_with(maximum_uses_per_performance: 1)
      expect { redeem(pass, performance) }.not_to raise_error
    end

    it 'rejects a second order on the same performance once the cap is reached' do
      pass = pass_with(maximum_uses_per_performance: 1)
      redeem(pass, performance)
      expect { redeem(pass, performance) }
        .to raise_error(ActiveRecord::RecordInvalid, %r{ticket\(s\)/performance})
    end

    it 'allows the same pass at a different performance of the same production' do
      pass = pass_with(maximum_uses_per_performance: 1)
      redeem(pass, performance)
      expect { redeem(pass, performance_of(production)) }.not_to raise_error
    end

    it 'rejects a single order that exceeds the cap' do
      pass = pass_with(maximum_uses_per_performance: 1)
      expect { redeem(pass, performance, tickets: 2) }
        .to raise_error(ActiveRecord::RecordInvalid, %r{ticket\(s\)/performance})
    end

    it 'treats a nil cap as unlimited' do
      pass = pass_with(maximum_uses_per_performance: nil)
      expect { redeem(pass, performance, tickets: 2) }.not_to raise_error
    end

    it 'treats a zero cap as unlimited' do
      pass = pass_with(maximum_uses_per_performance: 0)
      expect { redeem(pass, performance, tickets: 2) }.not_to raise_error
    end
  end

  describe 'per-performance and per-production caps together' do
    let(:production) { FactoryBot.create(:production) }

    it 'allows one ticket at each performance until the production cap is reached' do
      pass = pass_with(maximum_uses_per_performance: 1, maximum_uses_per_production: 2)
      redeem(pass, performance_of(production))
      redeem(pass, performance_of(production))
      expect { redeem(pass, performance_of(production)) }
        .to raise_error(ActiveRecord::RecordInvalid, %r{ticket\(s\)/production})
    end

    it 'rejects two tickets at one performance even when the production cap allows them' do
      pass = pass_with(maximum_uses_per_performance: 1, maximum_uses_per_production: 2)
      expect { redeem(pass, performance_of(production), tickets: 2) }
        .to raise_error(ActiveRecord::RecordInvalid, %r{ticket\(s\)/performance})
    end
  end
end
