# View helpers for atomic Foundation 6 components.
#
# Breadcrumb / callout / modal are extracted as partials under
# app/views/shared/components/. Button and label are atomic inline
# patterns where a partial would be more verbose than the markup it
# replaces, so they are helper methods instead. Centralizing the class
# strings here means the eventual CSS-framework migration touches this
# one file rather than every view.
module UiComponentsHelper
  # Foundation button rendered as a link.
  #
  #   ui_button "Save", save_path
  #   ui_button "Back", path, variant: :secondary, size: :small
  #
  # Any extra options (data:, id:, method:, title:, ...) pass straight
  # through to link_to. Pass a block for non-text content (icons, markup).
  def ui_button(name = nil, path = "#", variant: nil, size: nil, class: nil, **options, &block)
    extra   = binding.local_variable_get(:class)
    classes = ["button", size, variant, extra].compact.join(" ")
    if block
      link_to(path, class: classes, **options, &block)
    else
      link_to(name, path, class: classes, **options)
    end
  end

  # Foundation label (a small status badge).
  #
  #   ui_label "Sold Out", variant: :alert
  #   ui_label "Private", variant: :secondary, class: "float-right"
  #   ui_label "VIP", variant: :info, title: "Very important patron"
  #
  # variant: nil omits the variant class entirely (for custom-styled labels).
  def ui_label(text, variant: :secondary, class: nil, **options)
    extra   = binding.local_variable_get(:class)
    classes = ["label", variant, extra].compact.join(" ")
    content_tag(:span, text, class: classes, **options)
  end
end
