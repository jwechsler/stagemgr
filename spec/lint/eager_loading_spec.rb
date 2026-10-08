require 'rails_helper'

# Production boots with eager_load, and STI parents build their type
# conditions from the subclasses loaded so far. If app/models falls out of
# eager loading again, CurrencyPayment.where(...) silently stops matching
# cash, check and card payments until something loads those classes.
RSpec.describe 'Eager loading' do
  before(:all) { Rails.application.eager_load! }

  it 'loads every model under app/models' do
    defined = Rails.root.glob('app/models/**/*.rb')
                   .reject { |file| file.to_s.include?('/concerns/') }
                   .map { |file| file.basename('.rb').to_s.camelize }
    still_lazy = defined.select { |name| Object.autoload?(name) }

    expect(still_lazy).to be_empty
  end

  it 'gives STI parents every subclass' do
    expect(CurrencyPayment.where(id: 0).to_sql).to include("'CashPayment'", "'CheckPayment'", "'CreditCardPayment'")
    expect(PassPayment.where(id: 0).to_sql).to include("'FlexPassPayment'", "'MembershipPayment'")
  end
end
