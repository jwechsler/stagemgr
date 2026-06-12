class SetExpirationDateForFlexPasses < ActiveRecord::Migration[4.2]
  def up
    FlexPass.where('expiration_date is null').each do |fp|
      fp.expiration_date = fp.created_at + fp.flex_pass_offer.months_till_expiration.months
      fp.active = fp.expiration_date > Time.now
      if fp.active
        Resque.enqueue_at(fp.created_at + fp.flex_pass_offer.months_till_expiration.months, ExpireFlexPass, fp.id)
      end
    end
  end

  def down; end
end
