class BackfillEndedAtOnClosedMemberships < ActiveRecord::Migration[6.1]
  # Canceled/Suspended memberships closed before Membership#stamp_ended_at_on_close
  # existed never got an ended_at, so anything treating NULL as "still open"
  # (membership usage report, admin memberships datatable) counts them as
  # active forever. Stamp their real coverage end: last membership payment
  # + 1 month (mirroring Membership#last_effective_date), falling back to the
  # record's last update for memberships that never had a payment.
  #
  # Status strings are literal on purpose — migrations shouldn't depend on
  # app constants (RecurringProfile::CANCELED/SUSPENDED).
  def up
    execute <<~SQL.squish
      UPDATE memberships m
      SET m.ended_at = COALESCE(
        (SELECT DATE(DATE_ADD(MAX(p.processed_on), INTERVAL 1 MONTH))
         FROM payments p
         WHERE p.membership_id = m.id AND p.type = 'MembershipPayment'),
        DATE(m.updated_at)
      )
      WHERE m.status IN ('Canceled', 'Suspended')
        AND m.ended_at IS NULL
    SQL
  end

  def down
    # Backfilled dates are indistinguishable from ones stamped at close time.
    raise ActiveRecord::IrreversibleMigration
  end
end
