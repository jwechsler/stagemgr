
# required custom attributes for MyEmma
require 'my_emma'
module MyEmma
  class Member
    attr_accessor :name_first, :name_last, :wildcard_1403237, :address, :city, :state, :postal_code
    custom_attributes :name_first, :name_last, :wildcard_1403237, :address, :city, :state, :postal_code

    def contact_frequency
      self.wildcard_1403237
    end

    def contact_frequency=(frequency)
      self.wildcard_1403237=frequency
    end
  end
end
