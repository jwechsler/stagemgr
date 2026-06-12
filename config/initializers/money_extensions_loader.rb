# config/initializers/money_extensions.rb

# avoid weird number_to_currency bug

Money.class_eval do
  def formatted_with_symbol
    a, b = sprintf("%0.2f", amount).split('.')
    a.gsub!(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')
    "#{symbol}#{a}.#{b}"
  end
end
