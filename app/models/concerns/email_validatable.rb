require 'mail'

module EmailValidatable
  extend ActiveSupport::Concern

  class EmailValidator < ActiveModel::EachValidator
    def validate_each(record, attribute, value)
      return true if value.blank?

      begin
        a = Mail::Address.new(value)
      rescue Mail::Field::ParseError
        record.errors.add(attribute, options[:message] || "is not an email")
      end
    end
  end

  class NotEmailValidator < ActiveModel::EachValidator
    def validate_each(record, attribute, value)
      return true if value.blank?

      begin
        a = Mail::Address.new(value)
        record.errors.add(attribute, options[:message] || "is an email")
      rescue Mail::Field::ParseError
        true
      end
    end
  end
end
