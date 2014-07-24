module Admin::FlexPassOffersHelper

  def flex_pass_restrictions(flex_pass_offer)
    unless flex_pass_offer.theater.blank? then
      if flex_pass_offer.exclude_theater then
          "All but #{flex_pass_offer.theater.name}"
      else
          "Only #{flex_pass_offer.theater.name}"
      end
    else
      ""
    end
  end

end