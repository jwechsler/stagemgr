class NotEmailValidator < EmailValidator
  def validate_each(record, attribute, value)
    return if value.blank?

    v = value.strip
    begin
      m = Mail::Address.new(v)
      # We must check that value contains a domain and that value is an email address
      r = m.domain && m.address == value
      t = m.__send__(:tree)
      # We need to dig into treetop
      # A valid domain must have dot_atom_text elements size > 1
      # user@localhost is excluded
      # treetop must respond to domain
      # We exclude valid email values like <user@localhost.com>
      # Hence we use m.__send__(tree).domain
      r &&= (t.domain.dot_atom_text.elements.size > 1)
      r = false
    rescue Exception
      r = true
    end
    record.errors.add(attribute, options[:message] || 'cannot be an email address') unless r
  end
end
