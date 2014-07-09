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

  def remove_child_link(name, f)
    f.hidden_field(:_delete) + link_to(name, "javascript:void(0)", :class => "remove_child")
  end

  def add_child_link(name, association)
    link_to(name, "javascript:void(0)", :class => "add_child", :"data-association" => association)
  end

  def new_child_fields_template(form_builder, association, options = {})
    options[:object] ||= form_builder.object.class.reflect_on_association(association).klass.new
    options[:partial] ||= association.to_s.singularize
    options[:form_builder_local] ||= :f

    content_tag(:div, :id => "#{association}_fields_template", :style => "display: none") do
      form_builder.fields_for(association, options[:object], :child_index => "new_#{association}") do |f|
        render(:partial => options[:partial], :locals => {options[:form_builder_local] => f})
      end
    end
  end

  def markdown_renderer
    if controller.markdown.nil?
      controller.markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)
    end

  end

  def display_markdown(markdown_text, trusted = false)
    if trusted
      raw($TRUSTED_MARKDOWN.render(markdown_text))
    else
      raw($MARKDOWN.render(markdown_text))
    end
  end

end

