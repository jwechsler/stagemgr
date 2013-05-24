class Admin::AutoCompleteController < Admin::ApplicationController
  respond_to :xml, :json

  def production_code
    find_options = {
      :conditions => ["LOWER(production_code) LIKE ? and status != 'Inactive'", '%'+params[:q].to_s.downcase + '%']
    }
    productions = Production.with_permissions_to(:read).where(["LOWER(production_code) LIKE ? and status != 'Inactive'", '%'+params[:q].to_s.downcase + '%'])
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
          :number_left=>performance.number_of_tickets_left}
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

  def address
    val = params[:q].gsub(Address::SEARCHABLE_REGEXP,'').upcase
    addresses = Address.where("search_name like :search_expr and id in (select address_id from orders)", {:search_expr=>'%' + val + '%'}).limit(10).order(
        'last_name', 'first_name', 'id');
    if addresses.nil?
      render :json=>Array.new
    else
      render :json => addresses.map { |a|
        member_code = a.current_membership.member_code if a.is_current_member?
        tags = current_user.allowed_tags(a.address_tags).map {|t| r = t.tag_label
          r += " (#{t.tag_value})" unless t.tag_value.blank?
          r}.join(", ")
        { :address_id => a.id,
          :full_name => a.full_name,
          :email => a.email,
          :line1=>a.line1,
          :line2=>a.line2,
          :city=>a.city,
          :state=>a.state,
          :zipcode=>a.zipcode,
          :phone=>a.phone,
          :member_code=>member_code,
          :tags=>tags
        }

      }
    end
  end

end
