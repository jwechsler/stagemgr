# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  def to_currency(val)
    number_to_currency(val,:delimiter => ",", :unit => "$",:separator => ".", :precision => 2)
  end

end

