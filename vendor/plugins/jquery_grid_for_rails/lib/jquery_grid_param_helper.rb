module JqueryGridParamHelper
  protected

  def update_pagination_state_with_params!(*restraining_models)
    pagination_state = previous_pagination_state(restraining_models.first)
    limit = (params[:rows] || pagination_state[:limit] || 25).to_i
    offset = params[:page] ? ((params[:page].to_i - 1)*limit) : (( pagination_state[:offset] || 0).to_i)
    pagination_state.merge!({
            :sort_field => (params[:sidx] || pagination_state[:sort_field] || "#{restraining_models.first.table_name}.id").sub(/(\A[^\[]*)\[([^\]]*)\]/,'\2'), # fields may be passed as "object[attr]"
            :sort_direction => (params[:sord] || pagination_state[:sort_direction]).to_s.upcase,
            :offset => offset,
            :limit => limit
    })
    # allow only valid sort_fields matching column names of the given model ...
    valid_model = restraining_models.detect do |restraining_model|
      model_klass = (restraining_model.is_a?(Class) || restraining_model.nil? ? restraining_model : restraining_model.to_s.classify.constantize)
      model_klass.column_names.map{|name|["#{model_klass.table_name}.#{name}",name]}.flatten.include?(pagination_state[:sort_field])
    end
    if valid_model
      pagination_state[:sort_field]="#{valid_model.table_name}.#{pagination_state[:sort_field]}" unless pagination_state[:sort_field] =~ /^#{valid_model.table_name}\./
    else
      pagination_state.delete(:sort_field)
      pagination_state.delete(:sort_direction)
    end
    # ... and valid sort_directions
    pagination_state.delete(:sort_direction) unless %w(ASC DESC).include?(pagination_state[:sort_direction])

    save_pagination_state(pagination_state, restraining_models.first)
  end

  def will_paginate_options_from_pagination_state(pagination_state)
    will_paginate_options = { 
      :page => (pagination_state[:offset] / pagination_state[:limit])+1, 
      :per_page => pagination_state[:limit]
    }
    will_paginate_options.merge!(
            :order => "#{pagination_state[:sort_field]} #{pagination_state[:sort_direction]}"
    ) unless pagination_state[:sort_field].blank?

    will_paginate_options
  end

  def options_from_search(*restraining_models)
    returning options = {} do
      if params["_search".to_sym]
        sub_expressions = []
        values = {}
        restraining_models.each do |restraining_model|
          model_klass = (restraining_model.is_a?(Class) || restraining_model.nil? ? restraining_model : restraining_model.to_s.classify.constantize)
          model_klass.columns_hash.each do |attribute_name, column|
            if value = params[attribute_name.to_sym]
              key = "#{model_klass.table_name}.#{attribute_name}"
              value_placeholder = ":#{attribute_name}"

              #ix adds case insensitive searching
              #sub_expressions << "REGEXP_LIKE(#{key}, #{value_placeholder}, 'i')"
              sub_expressions << "#{key} like '%' || #{value_placeholder} || '%'"
              values[attribute_name.to_sym] = value
            end
          end
        end
        unless sub_expressions.empty?
          query = sub_expressions.join(" AND ")
          logger.debug "Query #{query.inspect}"
          options.merge!(:conditions => [query, values])
        end
      end
    end
  end

  private

  # get pagination state from session
  def previous_pagination_state(model_klass = nil)
    session["#{model_klass.to_s.tableize.tr('/','_') if model_klass}_pagination_state"] || {}
  end

  # save pagination state to session
  def save_pagination_state(pagination_state, model_klass = nil)
    session["#{model_klass.to_s.tableize.tr('/','_') if model_klass}_pagination_state"] = pagination_state
  end

end
