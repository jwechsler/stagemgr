module Hexagile
  module JqueryGridForRails
    def jquery_grid(id, options={})
      yaml = ERB.new(File.open("#{RAILS_ROOT}/config/jquery_grid/#{id}.yml.erb", 'r').read).result(controller.send(:binding))
      grid_data = YAML::load(yaml)
      options=grid_data.merge(options)

      jqgrid(options[:title]||id.to_s,id.to_s,options.delete(:url),options.delete(:columns),options)
    end

    def gen_columns(columns)
      col_names = '['
      col_model = '['
      columns.each do |c|
        raise "index is required for all columns -- #{c.inspect}" unless c[:index]
        c[:label] ||= c[:index].humanize
        c[:name] ||= c[:index]
        col_names << "'#{c.delete(:label)}',"
        col_model << "{%s}," % (c.map{|a,b|"#{a.to_s}: #{b.to_json}"} * ', ')
      end
      col_names.chop! << "]"
      col_model.chop! << "]"
      [col_names, col_model]
    end
    
    def jqgrid(title, id, action, columns = [], options = {})
      options.reject!{|key,value|value.nil?}
      # Default options
      options =
        {
          :rows_per_page       => '25',
          :sort_column         => '',
          :sort_order          => 'asc',
          :height              => "'auto'",
          :gridview            => 'false',
          :error_handler       => 'null',
          :inline_edit_handler => 'null',
          :add                 => 'false',
          :delete              => 'false',
          :search              => 'false',
          :edit                => 'false',
          :inline_edit         => 'false',
          :autowidth           => 'false',
          :rownumbers          => 'false',
          :cell_edit           => 'false',
          :cell_url            => ''
        }.merge(options)

      # Stringify options values
      options.inject({}) do |options, (key, value)|
        options[key] = (key != :subgrid) ? value.to_s : value
        options
      end

      options[:error_handler_return_value] = (options[:error_handler] == 'null') ? 'true;' : options[:error_handler]
      edit_button = (options[:edit] == 'true' && options[:inline_edit] == 'false' && options[:cell_edit] == 'false').to_s

      # Generate columns data
      col_names, col_model = gen_columns(columns)

      # Enable filtering (by default)
      search = ""
      filter_toolbar = ""
      if options[:search] == 'true'
        search = %Q/.navButtonAdd("##{id}_pager",{caption:"",title:"Toggle Search Toolbar", buttonicon :'ui-icon-search', onClickButton:function(){ mygrid[0].toggleToolbar() } })/
        filter_toolbar = "mygrid.filterToolbar();"
        filter_toolbar << "mygrid[0].toggleToolbar()"
      end

      # Enable multi-selection (checkboxes)
      multiselect = "multiselect: false,"
      if options[:multi_selection]
        multiselect = "multiselect: true,"
        multihandler = %Q/
          jQuery("##{id}_select_button").click( function() {
            var s; s = jQuery("##{id}").getGridParam('selarrrow');
            #{options[:selection_handler]}(s);
            return false;
          });/
      end

      # Enable master-details
      masterdetails = ""
      if options[:master_details]
        masterdetails = %Q/
          onSelectRow: function(ids) {
            if(ids == null) {
              ids=0;
              if(jQuery("##{id}_details").getGridParam('records') >0 )
              {
                jQuery("##{id}_details").setGridParam({url:"#{options[:details_url]}?q=1&id="+ids,page:1})
                .setCaption("#{options[:details_caption]}: "+ids)
                .trigger('reloadGrid');
              }
            }
            else
            {
              jQuery("##{id}_details").setGridParam({url:"#{options[:details_url]}?q=1&id="+ids,page:1})
              .setCaption("#{options[:details_caption]} : "+ids)
              .trigger('reloadGrid');
            }
          },/
      end

      # Enable selection link, button
      # The javascript function created by the user (options[:selection_handler]) will be called with the selected row id as a parameter
      selection_link = ""
      if options[:direct_selection].blank? && options[:selection_handler].present? && options[:multi_selection].blank?
        selection_link = %Q/
        jQuery("##{id}_select_button").click( function(){
          var id = jQuery("##{id}").getGridParam('selrow');
          if (id) {
            #{options[:selection_handler]}(id);
          } else {
            alert("Please select a row");
          }
          return false;
        });/
      end

      # Enable direct selection (when a row in the table is clicked)
      # The javascript function created by the user (options[:selection_handler]) will be called with the selected row id as a parameter
      direct_link = ""
      if options[:direct_selection] && options[:selection_handler].present? && options[:multi_selection].blank?
        direct_link = %Q/
        onSelectRow: function(id){
          if(id){
            #{options[:selection_handler]}(id);
          }
        },/
      end

      cell_selection_link = ""
      if options[:direct_selection].blank? && options[:cell_edit] != 'true' && options[:cell_select_handler].present?
        cell_selection_link = %Q/
        onCellSelect:  function(rowid, iCol, cellcontent){
          if (rowid && iCol && cellcontent) {
            #{options[:cell_select_handler]}(rowid, iCol, cellcontent);
          }
        },/
      end

      # Enable grid_loaded callback
      # When data are loaded into the grid, call the Javascript function options[:grid_loaded] (defined by the user)
      grid_loaded = ""
      if options[:grid_loaded].present?
        grid_loaded = %Q/
        loadComplete: function(){
          #{options[:grid_loaded]}();
        },
        /
      end

      # Enable inline editing
      # When a row is selected, all fields are transformed to input types
      editable = ""
      if options[:edit] && options[:inline_edit] == 'true' && options[:cell_edit] == 'false'
        editable = %Q/
        onSelectRow: function(id){
          if(id && id!==lastsel){
            jQuery('##{id}').restoreRow(lastsel);
            jQuery('##{id}').editRow(id, true, #{options[:inline_edit_handler]}, #{options[:error_handler]});
            lastsel=id;
          }
        },/
      end

      # Enable subgrids
      subgrid = ""
      subgrid_enabled = "subGrid:false,"

      if options[:subgrid].present?

        subgrid_enabled = "subGrid:true,"

        options[:subgrid] =
          {
            :rows_per_page => '10',
            :sort_column   => 'id',
            :sort_order    => 'asc',
            :add           => 'false',
            :edit          => 'false',
            :delete        => 'false',
            :search        => 'false'
          }.merge(options[:subgrid])

        # Stringify options values
        options[:subgrid].inject({}) do |suboptions, (key, value)|
          suboptions[key] = value.to_s
          suboptions
        end

        subgrid_inline_edit = ""
        if options[:subgrid][:inline_edit] == true
          options[:subgrid][:edit] = 'false'
          subgrid_inline_edit = %Q/
          onSelectRow: function(id){
            if(id && id!==lastsel){
              jQuery('#'+subgrid_table_id).restoreRow(lastsel);
              jQuery('#'+subgrid_table_id).editRow(id,true);
              lastsel=id;
            }
          },
          /
        end

        if options[:subgrid][:direct_selection] && options[:subgrid][:selection_handler].present?
          subgrid_direct_link = %Q/
          onSelectRow: function(id){
            if(id){
              #{options[:subgrid][:selection_handler]}(id);
            }
          },
          /
        end

        sub_col_names, sub_col_model = gen_columns(options[:subgrid][:columns])

        subgrid = %Q(
        subGridRowExpanded: function(subgrid_id, row_id) {
        		var subgrid_table_id, pager_id;
        		subgrid_table_id = subgrid_id+"_t";
        		pager_id = "p_"+subgrid_table_id;
        		$("#"+subgrid_id).html("<table id='"+subgrid_table_id+"' class='scroll'></table><div id='"+pager_id+"' class='scroll'></div>");
        		jQuery("#"+subgrid_table_id).jqGrid({
        			url:"#{options[:subgrid][:url]}?q=2&id="+row_id,
              editurl:'#{options[:subgrid][:edit_url]}?parent_id='+row_id,
        			colNames: #{sub_col_names},
        			colModel: #{sub_col_model},
        		   	rowNum:#{options[:subgrid][:rows_per_page]},
        		   	pager: pager_id,
        		   	imgpath: '/images/themes/lightness/images',
        		   	sortname: '#{options[:subgrid][:sort_column]}',
        		    sortorder: '#{options[:subgrid][:sort_order]}',
                viewrecords: true,
                toolbar : [true,"top"],
        		    #{subgrid_inline_edit}
        		    #{subgrid_direct_link}
        		    height: '100%'
        		})
        		.navGrid("#"+pager_id,{edit:#{options[:subgrid][:edit]},add:#{options[:subgrid][:add]},del:#{options[:subgrid][:delete]},search:false})
        		.navButtonAdd("#"+pager_id,{caption:"Search",title:"Toggle Search",buttonimg:'/images/jqgrid/search.png',
            	onClickButton:function(){
            		if(jQuery("#t_"+subgrid_table_id).css("display")=="none") {
            			jQuery("#t_"+subgrid_table_id).css("display","");
            		} else {
            			jQuery("#t_"+subgrid_table_id).css("display","none");
            		}
            	}
            });
            jQuery("#t_"+subgrid_table_id).height(25).hide().filterGrid(""+subgrid_table_id,{gridModel:true,gridToolbar:true});
        	},
        	subGridRowColapsed: function(subgrid_id, row_id) {
        	},
        )
      end

      # Generate required Javascript & html to create the jqgrid
      %Q(
        <script type="text/javascript">
        var lastsel;
        jQuery(document).ready(function(){
        var mygrid = jQuery("##{id}").jqGrid({
            url:'#{action}#{action.include?('?') ? '&' : '?'}',
            xmlReader: { 
              root: "rows", 
              row: "row", 
              page: "rows>currentpage", 
              total: "rows>totalpages", 
              records : "rows>totalrecords", 
              repeatitems: true, 
              cell: "cell", 
              id: "[id]"
            },
            editurl:'#{options[:edit_url]}',
            colNames:#{col_names},
            colModel:#{col_model},
            pager: '##{id}_pager',
            rowNum:#{options[:rows_per_page]},
            rowList:[10,25,50,100],
            imgpath: '/images/themes/lightness/images',
            sortname: '#{options[:sort_column]}',
            viewrecords: true,
            height: #{options[:height]},
            sortorder: '#{options[:sort_order]}',
            gridview: #{options[:gridview]},
            scrollrows: true,
            autowidth: #{options[:autowidth]},
            rownumbers: #{options[:rownumbers]},
            cellEdit: #{options[:cell_edit]},
            cellurl: '#{options[:cell_url]}',
            #{multiselect}
            #{masterdetails}
            #{grid_loaded}
            #{direct_link}
            #{cell_selection_link}
            #{editable}
            #{subgrid_enabled}
            #{subgrid}
            caption: "#{title}"
        })
        .navGrid('##{id}_pager',
        {edit:#{edit_button},add:#{options[:add]},del:#{options[:delete]},search:false,refresh:true},
        {afterSubmit:function(r,data){return #{options[:error_handler_return_value]}(r,data,'edit');}},
        {afterSubmit:function(r,data){return #{options[:error_handler_return_value]}(r,data,'add');}},
        {afterSubmit:function(r,data){return #{options[:error_handler_return_value]}(r,data,'delete');}})
        #{search}
        #{multihandler}
        #{selection_link}
        #{filter_toolbar}
        });
        </script>
        <table id="#{id}" class="scroll" cellpadding="0" cellspacing="0"></table>
        <div id="#{id}_pager" class="scroll" style="text-align:center; width: 992px"></div>
      )
    end

    def include_jquery_grid_javascript
      javascript_include_tag('jqGrid/i18n/grid.locale-en', 'jqGrid/jquery.jqGrid.min')
    end
    
    def include_jquery_grid_css
      stylesheet_link_tag('cupertino/jquery-ui-1.7.2.custom','jqGrid/ui.jqgrid.css')
    end
    
    def update_pagination_state_with_params!(restraining_model = nil)
      model_klass = (restraining_model.is_a?(Class) || restraining_model.nil? ? restraining_model : restraining_model.to_s.classify.constantize)
      pagination_state = previous_pagination_state(model_klass)
      per_page = params[:rows] || pagination_state[:per_page] || 25
      page = params[:page] || pagination_state[:page] || 1
      order = if !params[:sidx].nil? && !params[:sidx].empty? && !params[:sord].nil? && !params[:sord].empty?
        "#{params[:sidx].sub(/(\A[^\[]*)\[([^\]]*)\]/,'\2')} #{params[:sord]}"
      elsif pagination_state[:order]
        pagination_state[:order]
      else
        "#{restraining_model.table_name}.id ASC"
      end
      pagination_state.merge!({
              :page => page,
              :per_page => per_page,
              :order => order
      })
      save_pagination_state(pagination_state, model_klass)
    end

    def options_from_pagination_state(pagination_state)
      find_options = { :page => pagination_state[:page],
                       :per_page  => pagination_state[:per_page] }
      find_options.merge!(
              :order => "#{pagination_state[:sort_field]} #{pagination_state[:sort_direction]}"
      ) unless pagination_state[:sort_field].blank?

      find_options
    end

    def options_from_search(restraining_model = nil)
      returning options = {} do
        model_klass = (restraining_model.is_a?(Class) || restraining_model.nil? ? restraining_model : restraining_model.to_s.classify.constantize)
        sub_expressions = []
        values = {}
        if params["_search".to_sym]
          model_klass.columns_hash.each do |attribute_name, column|
            if value = params[attribute_name.to_sym]
              key = "#{column.table_name}.#{attribute_name}"
              value_placeholder = ":#{attribute_name}"

              #ix adds case insensitive searching
              sub_expressions << "REGEXP_LIKE(#{key}, #{value_placeholder}, 'i')"
              values[attribute_name.to_sym] = value
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
end
