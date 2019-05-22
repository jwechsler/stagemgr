# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ :name => 'Chicago' }, { :name => 'Copenhagen' }])
#   Major.create(:name => 'Daley', :city => cities.first)

user        = User.create!({
      :email                 => 'admin@yoursite.com',
      :password              => 'betterpassword',
      :password_confirmation => 'betterpassword',
      :is_administrator      => true})

theater     = Theater.create!({
  :name                      =>'Theater 1',
  :theater_class             =>Theater::THEATER_CLASSES.first,
  :status                    =>Theater::THEATER_STATUSES.first})

venue       = Venue.create!({
  :name                      =>'Venue 1',
  :ordinal_sort              => 1
})

