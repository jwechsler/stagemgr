module CurrencyUtils
  def self.float_to_currency_decimal(value)
    case value
    when Float
      BigDecimal(value.to_s).round(2)
    when BigDecimal
      value.round(2)
    when Integer
      BigDecimal(value).round(2)
    else
      raise ArgumentError, 'Value must be a Float, BigDecimal, or Integer'
    end
  end
end
