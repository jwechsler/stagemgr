# The public list of memberships on sale. Everything else about an offer --
# creating one, taking it off sale, its Stripe price -- lives under /admin;
# this exists so the calendar's "become a member" call-to-action has somewhere
# in the application to point, instead of a hand-maintained page on the
# marketing site.
class MembershipOffersController < ApplicationController
  layout Rails.configuration.x.server_config['ext_site_wrapper']

  def index
    @membership_offers = MembershipOffer.on_sale_to_public.order(:name)
  end
end
