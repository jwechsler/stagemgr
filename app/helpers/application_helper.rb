# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper

  def to_currency(val)
    number_to_currency(val,:delimiter => ",", :unit => "$",:separator => ".", :precision => 2)
  end

  def backend?
    controller.class.name.split("::").first == "Admin"
  end

  def admin?
    self.backend?
  end

  def markdown_renderer
    if controller.markdown.nil?
      controller.markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)
    end

  end

  def order_status_severity_class(status)
    case status
    when Order::FULFILLED
      "success"
    when Order::REFUNDED
      "alert"
    when Order::CANCELED
      "alert"
    when Order::HOLD
      "alert"
    when Order::PROCESSING
      "alert"
    else
      "secondary"
    end
  end

  def display_markdown(markdown_text, trusted = false)
    if trusted
      raw($TRUSTED_MARKDOWN.render(markdown_text))
    else
      raw($MARKDOWN.render(markdown_text))
    end
  end

  def checkmark(value)
    if value
      raw fa_icon 'check'
    else
      ''
    end
  end

  def mailing_list_link(production = nil)
    (production.nil? || production.mailing_list_link.blank?) ? $SERVER_CONFIG['mailing_list_link'] : production.mailing_list_link
  end

  def survey_link(production = nil)
    (production.nil? || production.survey_link.blank?) ? $SERVER_CONFIG['survey_link'] : production.survey_link
  end

end

