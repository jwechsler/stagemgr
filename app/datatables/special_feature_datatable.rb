class SpecialFeatureDatatable < DatatableBase
  extend Forwardable
  include ActionView::Helpers::NumberHelper

  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns ||= {
      name: { source: 'SpecialFeature.short_name' },
      description: { source: 'SpecialFeature.description' },
      status: { source: 'SpecialFeature.status' },
    }
  end

  def additional_data
    {
      actions: ''
    }
  end


  def data
    records.map do |record|
      {
        id: record.id,
        name: link_to(record.short_name, [:admin, record]),
        description: raw($MARKDOWN.render(record.description)),
        status: raw("<span class=\"label\">#{record.status}</span>"),
        actions:
          (current_user.can?(:edit, record) ? link_to('Edit', [:edit, :admin, record], :id=>"edit_#{record.short_name.downcase.gsub(' ','_')}", :class=>'tiny button') + " " : "") +
          (current_user.can?(:destroy, record) ? link_to('Destroy', [:admin, record], :confirm => 'Are you sure?', :method => :delete, :class=>'tiny alert button') : ""),
        DT_RowID: record.id,
     }
    end
  end

  private

  def get_raw_records
    special_features = SpecialFeature.all.order(:short_name)
  end

  # ==== These methods represent the basic operations to perform on records
  # and feel free to override them

  # def filter_records(records)
  # end

  # def sort_records(records)
  # end

  # def paginate_records(records)
  # end

  # ==== Insert 'presenter'-like methods below if necessary


end
