class Admin::AutoCompleteController < Admin::ApplicationController
  respond_to :xml, :json

  def production_code
    find_options = {
      :conditions => ["LOWER(production_code) LIKE ? and status != 'Inactive'", '%'+params[:q].to_s.downcase + '%']
    }
    productions = Production.with_permissions_to(:read).where(["LOWER(production_code) LIKE ? and status != 'Inactive'", '%'+params[:q].to_s.downcase + '%'])
    render :inline => productions.map { |production| "#{production.production_code}|#{production.to_s}" }.join("\n")
  end

  def performance_code
    production = Production.find_by_production_code(params[:production_code])
    return [] if production.nil?
    performances = production.performances.search_by_code(params[:q])
    render :inline => performances.map { |performance| "#{performance.performance_code}|#{performance.to_s}" }.join("\n")
  end


  def ticket_class_code
    performance = Performance.find_by_performance_code(params[:performance_code])
    return [] if performance.nil?
    ticket_classes = performance.production.ticket_classes.search_by_code_and_performance_id(params[:q], performance.id)
    render :inline => ticket_classes.map { |ticket_class| "#{ticket_class.class_code}|#{ticket_class.to_s} (#{ticket_class.number_left(performance)} Tickets Left)|#{ticket_class.ticket_type}|#{ticket_class.ticket_price}" }.join("\n")
  end


end
