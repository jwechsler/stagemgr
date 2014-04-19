module ActiveRecord::Validations::ClassMethods
  DEFAULT_CREDIT_CARD_TYPES = {:visa => 'Visa', :master_card => 'MasterCard', :discover => 'Discover', :amex => 'American Express', :unknown => 'invalid' }
  
  #I don't think anyone doing the right thing will be validating more than one type and one card number per record.
  def validates_credit_card(card_number, card_type, options)
    with = options[:with] || DEFAULT_CREDIT_CARD_TYPES
    validates_each(card_number, options) do |record, attr_name, value|
      type = record.send(card_type)
      record.errors.add attr_name, "is not a valid #{type.humanize} card" unless passes_luhn?(value) and with[card_bin(value)] == type
    end
  end

  def validates_credit_card_if_new(card_number, card_type, options, confirmation_code)
    if confirmation_code.blank? 
      validates_credit_card(card_number, card_type, options)
    end
  end
  #example
  #   validates_credit_card_type :card_type, :against => :card_number, :with => DEFAULT_CREDIT_CARD_TYPES
  def validates_credit_card_type(card_type, options)
    with = options[:with] || DEFAULT_CREDIT_CARD_TYPES  #TODO: check that the required keys are in this hash.
    against = options[:against].to_sym

    validates_each(card_type) do |record, attr_name, value|
      card_number = record.send against
      type = card_bin(card_number)
      record.errors.add attr_name, " is #{value.humanize} but it looks more like a #{with[type].humanize} card." if value != with[type]
    end
  end

  def validates_credit_card_number(*attr_names)
    validates_each(attr_names) do |record, attr_name, value|
      record.errors.add attr_name, 'is not a valid credit card number.' unless passes_luhn?(value)
    end
  end

  private 

  def passes_luhn?(number)
    #Luhn check from http://blog.internautdesign.com/2007/4/18/ruby-luhn-check-aka-mod-10-formula
    odd = true
    number.to_s.gsub(/\D/,'').reverse.split('').map(&:to_i).collect { |d|
      d *= 2 if odd = !odd
      d > 9 ? d - 9 : d
    }.sum % 10 == 0
  end

  def passes_bin?(type, number)
    type == card_bin(number)
  end

  def card_bin(card_number)
    if card_number =~ /^4/ and [13,16].include?(card_number.size)
      :visa
    elsif card_number =~ /^5[1-5]/ and card_number.size == 16
      :master_card
    elsif card_number =~ /^34|37/ and card_number.size == 15
      :amex
    elsif card_number =~ /^6011|65/ and card_number.size == 16
      :discover
    #can't find enough info on these...
    #elsif card_number =~ /^36/ and card_number.size == 16
    #  :diners
    else
      :unknown
    end
  end

end
