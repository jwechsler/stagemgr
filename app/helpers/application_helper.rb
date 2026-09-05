# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  def html_comment(comment)
    raw("// #{comment}\n") if Rails.env.eql?('development')
  end

  def to_currency(val)
    number_to_currency(val, delimiter: ',', unit: '$', separator: '.', precision: 2)
  end

  def backend?
    controller.class.name.split('::').first == 'Admin'
  end

  # Order-entry surfaces that need the shared order-form JS
  # (orders_common.js, plus admin/orders_common.js in the admin scope).
  # Only pages on the application layout consult this — public order pages
  # use the Foundation site wrapper and get orders_common via a
  # content_for :js include in orders/_billing_form instead.
  def order_form_page?
    controller_name == 'orders' || controller_name.end_with?('_orders')
  end

  def admin?
    backend?
  end

  def markdown_renderer
    return unless controller.markdown.nil?

    controller.markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)
  end

  def display_markdown(markdown_text, trusted = false)
    return '' if markdown_text.nil?

    if trusted
      raw(Rails.configuration.x.trusted_markdown.render(markdown_text))
    else
      raw(Rails.configuration.x.markdown.render(markdown_text))
    end
  end

  def checkmark(value)
    if value
      raw fa_icon 'check'
    else
      ''
    end
  end

  # Facts about the house -- phone, address, social links, who signs the mail --
  # for the partials that need to name them. Memoized per view context, so the
  # Default theater row is looked up once a rendered document rather than once a
  # sentence. That is one lookup per page, and two for an email with both an
  # HTML and a text part, which is cheap enough not to want a longer-lived cache
  # that would go stale when the theater row is edited.
  # OrderMailer's Ruby code has its own private +house+ memo for the same object.
  def theater_info
    @theater_info ||= TheaterInfo.new
  end

  def mailing_list_link(production = nil)
    production.nil? || production.mailing_list_link.blank? ? Rails.configuration.x.server_config['mailing_list_link'] : production.mailing_list_link
  end

  def survey_link(production = nil)
    production.nil? || production.survey_link.blank? ? Rails.configuration.x.server_config['survey_link'] : production.survey_link
  end
end
