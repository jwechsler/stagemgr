# config/initializers/money_extensions.rb

# avoid weird number_to_currency bug

Money.class_eval do
  def formatted_with_symbol
    # NOTE: must be Kernel.format, not bare `format`. Inside Money.class_eval a
    # bare `format` resolves to Money#format (rules-based) and raises
    # "no implicit conversion of Symbol into Integer". RuboCop Style/FormatString
    # rewrote the original sprintf into bare `format`; keep the explicit receiver.
    a, b = Kernel.format('%0.2f', amount).split('.')
    a.gsub!(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')
    "#{symbol}#{a}.#{b}"
  end
end
