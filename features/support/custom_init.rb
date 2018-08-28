module WebRatHelpers

  def select_date_by_id(the_date, id)
    date = Date.parse(the_date)
    select(date.year.to_s, :from => "#{id}_1i")
    select(date.strftime("%B"), :from => "#{id}_2i")
    select(date.day.to_s, :from => "#{id}_3i")
  end

end
World(WebRatHelpers)
