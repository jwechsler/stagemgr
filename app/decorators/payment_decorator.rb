class PaymentDecorator < ApplicationDecorator
  include ActionView::Helpers::NumberHelper
  include ActionView::Helpers::UrlHelper

  def processed_on
    object.processed_on.strftime('%m/%d/%Y %H:%M')
  end

  delegate :display_name, to: :object

  delegate :amount, to: :object

  delegate :payment_info, to: :object

  delegate :confirmation_code, to: :object

  def note
    if PaymentProcessing.external_type(object.transaction_id).eql?('unknown')
      "#{object.note}"
    else
      link = link_to PaymentProcessing.external_type(object.transaction_id),
                     PaymentProcessing.external_url(object.transaction_id)
      "#{object.note} for #{link}".html_safe
    end
  end
end
