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

  def mailing_list_link(production = nil)
    production.nil? || production.mailing_list_link.blank? ? Rails.configuration.x.server_config['mailing_list_link'] : production.mailing_list_link
  end

  def survey_link(production = nil)
    production.nil? || production.survey_link.blank? ? Rails.configuration.x.server_config['survey_link'] : production.survey_link
  end
end
