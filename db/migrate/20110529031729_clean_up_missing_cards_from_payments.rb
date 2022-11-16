class CleanUpMissingCardsFromPayments < ActiveRecord::Migration[4.2]
  def self.up
    execute "update payments set confirmation_code = 'unknown' where type = 'CreditCardPayment' and confirmation_code is null and amount < 0"
  end

  def self.down
  end
end
