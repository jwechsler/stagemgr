class VenueDatatable < AjaxDatatablesRails::Base

  def_delegator :@view, :raw
  def_delegator :@view, :link_to

  def initialize(params, opts={})
    super(params, opts)
    @view = opts[:view_context]
  end


  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns ||= {
      name: { source: 'Venue.name', cond: :like},

    }
  end


  def additional_data
    {
      actions: '',
    }
  end

  def data
    records.map do |venue|
      {
        name: link_to(venue.name, [:admin, venue]),
        actions: raw(allowed_actions(venue)),
        # example:
        # id: record.id,
        # name: record.name
      }
    end
  end

  private

  def get_raw_records
    Venue.all
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

  def current_user
    @current_user ||= options[:current_user]
  end

  def allowed_actions(record)
    actions = []
    actions << ("<li>" +link_to('Edit', [:edit, :admin, record], :id=>"edit_#{record.name.downcase.gsub(' ','_')}", :class=>'tiny button')+"</li>") if current_user.can?(:edit, record)
    actions << ("<li>" +link_to('Destroy', [:admin, record], :confirm => 'Are you sure?', :method => :delete, :class=>'tiny alert button') + "</li>") if current_user.can?(:destroy, record)
    '<ul class="button-group">' + actions.join(' ') + '</ul>'
  end

end
