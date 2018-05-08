class Admin::AutoCompleteController < Admin::ApplicationController
  respond_to :xml, :json

  def production_code
    productions = Production.with_permissions_to(:read).where(["LOWER(production_code) LIKE ? and status != 'Inactive'", '%'+params[:q].to_s.downcase + '%'])
    render :json => productions.map { |production|
      {:code=>production.production_code, :name=>production.name, :theater=>production.theater.name} }
  end

  def any_production_code
    productions = Production.with_permissions_to(:read).where(["LOWER(production_code) LIKE ?", params[:q].to_s.downcase + '%'])
    render :json => productions.map { |production|
      {:code=>production.production_code, :name=>production.name, :theater=>production.theater.name} }
  end


  def performance_code
    production = Production.find_by_production_code(params[:production_code])
    if production.nil?
      render :json=>Array.new
    else
      performances = production.performances.search_by_code(params[:q])
      render :json => performances.map { |performance|
        {:code=>performance.performance_code, :name=>performance.to_s,
          :fdate=>performance.performance_date.to_formatted_s(:show_date),
          :ftime=>performance.performance_time.to_formatted_s(:hour_min),
          :number_left=>performance.number_of_seats_left}
      }
    end
  end


  def ticket_class_code
    performance = Performance.find_by_performance_code(params[:performance_code])
    if performance.nil?
      render :json => Array.new
    else
      ticket_classes = performance.production.ticket_classes.search_by_code_and_performance_id(params[:q], performance.id)
      render :json => ticket_classes.select { |tc| !tc.software_managed }.map { |ticket_class|
        { :code=>ticket_class.class_code,
          :name=>"#{ticket_class.to_s } (#{ticket_class.number_left(performance)} Tickets Left)",
          :ticket_type=>ticket_class.ticket_type,
          :ticket_price=>ticket_class.ticket_price,
        }
      }
    end
  end

end
