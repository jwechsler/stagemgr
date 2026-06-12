# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ :name => 'Chicago' }, { :name => 'Copenhagen' }])
#   Major.create(:name => 'Daley', :city => cities.first)

user                    = User.new
user.email              = 'admin@yourtheater.com'
user.is_administrator   = true
user.is_box_office_user = false
user.password           = 'changeme'
user.save!

Theater.create!({
                  name: 'Theater 1',
                  theater_class: Theater::THEATER_CLASSES.first,
                  status: Theater::THEATER_STATUSES.first
                })

Venue.create!({
                name: 'Venue 1',
                ordinal_sort: 1
              })

CashPaymentType.create(display_name: 'Cash', allow_for_public: false, allow_for_box_office: true)
CreditCardPaymentType.create(display_name: 'Credit Card', allow_for_public: true, allow_for_box_office: true)
MembershipPaymentType.create(display_name: 'Membership', allow_for_public: true, allow_for_box_office: true)
FlexPassPaymentType.create(display_name: 'FlexPass', allow_for_public: true, allow_for_box_office: true)
