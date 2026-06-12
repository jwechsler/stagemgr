class PaymentDecorator < ApplicationDecorator
  include ActionView::Helpers::NumberHelper
  include ActionView::Helpers::UrlHelper

  def processed_on
    object.processed_on.strftime("%m/%d/%Y %H:%M")
  end

  def display_name
    object.display_name
  end

  def amount
    object.amount
  end

  def payment_info
    object.payment_info
  end
  
  def confirmation_code
    object.confirmation_code
  end

  def note
    if PaymentProcessing.external_type(object.transaction_id).eql?('unknown') then
      "#{object.note}"
    else
      link = link_to PaymentProcessing.external_type(object.transaction_id), PaymentProcessing.external_url(object.transaction_id)
      "#{object.note} for #{link}".html_safe
    end
  end

end
