require 'rails_helper'

# Pins which validators actually run for email checks. `email: true` and
# `not_email: true` are resolved by constant lookup from the model, so a stray
# top-level EmailValidator or NotEmailValidator can silently take over (or be
# silently ignored). Address resolves to validates_formatting_of's validator;
# Order to the EmailValidatable concern's.
RSpec.describe 'email validation' do
  describe Address do
    it 'uses the validates_formatting_of email validator' do
      expect(described_class.validators_on(:email).map(&:class))
        .to eq([ValidatesFormattingOf::Validations::EmailValidator])
    end

    it 'accepts a plain address and a blank one' do
      ['patron@example.com', '', nil].each do |email|
        address = described_class.new(full_name: 'Pat Patron', email: email)
        address.valid?
        expect(address.errors[:email]).to be_empty, "expected #{email.inspect} to be accepted"
      end
    end

    it 'rejects malformed addresses' do
      ['no-at-sign', 'bad@@example.com', 'user@localhost', 'spaced @example.com',
       'Name <patron@example.com>'].each do |email|
        address = described_class.new(full_name: 'Pat Patron', email: email)
        address.valid?
        expect(address.errors[:email]).to include('is not a valid email'), "expected #{email.inspect} to be rejected"
      end
    end
  end

  describe Order do
    it 'uses the EmailValidatable not-email validator for hold_under' do
      expect(described_class.validators_on(:hold_under).map(&:class))
        .to eq([EmailValidatable::NotEmailValidator])
    end

    it 'rejects an email address as a hold name and accepts a plain name' do
      order = described_class.new(hold_under: 'patron@example.com')
      order.valid?
      expect(order.errors[:hold_under]).to include('is an email')

      order.hold_under = 'Box Office'
      order.valid?
      expect(order.errors[:hold_under]).to be_empty
    end
  end
end
