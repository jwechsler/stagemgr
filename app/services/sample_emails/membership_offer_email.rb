module SampleEmails
  # Membership offer form, Confirmation Email Text. Built in memory and never
  # saved: saving a Membership enqueues a MyEmma list sync
  # (Membership#enqueue_myemma_list_sync) that no rollback could undo.
  class MembershipOfferEmail < Base
    self.email_name = 'membership confirmation email'

    SAMPLE_MEMBER_CODE = 'TW-SAMPLE'.freeze

    def self.authorized?(ability, _context)
      ability.can?(:update, MembershipOffer)
    end

    def deliver!
      OrderMailer.membership_confirmation(sample_order).deliver_now
    end

    private

    def sample_order
      address = Address.new(full_name: 'Sample Member', email: recipient)
      # MembershipOrder builds its line item, and the line item its membership,
      # on initialize.
      order = MembershipOrder.new(address: address, status: Order::PROCESSED)
      order.membership_line_item.assign_attributes(membership_offer: draft_offer, address: address)
      order.membership.assign_attributes(membership_offer: draft_offer, address: address,
                                         member_code: SAMPLE_MEMBER_CODE, status: Membership::ACTIVE)
      order
    end

    def draft_offer
      @draft_offer ||= begin
        draft = params.require(:membership_offer).permit(:name, :email_html)
        MembershipOffer.new(name: draft[:name].presence || 'Sample Membership', email_html: draft[:email_html])
      end
    end
  end
end
