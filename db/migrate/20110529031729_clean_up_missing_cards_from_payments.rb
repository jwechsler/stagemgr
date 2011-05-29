class CleanUpMissingCardsFromPayments < ActiveRecord::Migration
  def self.up
    execute "update payments set confirmation_code = 'unknown' where type = 'CreditCardPayment' and confirmation_code is null and amount < 0"
  end

  def self.down
  end
end
