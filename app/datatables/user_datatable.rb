class UserDatatable < AjaxDatatablesRails::Base
  extend Forwardable

  def_delegator :@view, :link_to
  def_delegator :@view, :raw

  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format

    @view_columns ||= {
      email: { source: 'User.email' },
      last_request: { source: 'User.last_request_at', :searchable=>false },
      logins: { source: 'User.login_count', :searchable=>false },
      failed_logins: { source: 'User.failed_login_count', :searchable=>false },
      status: { source: 'User.status' },
    }
  end

  def additional_data
    {
      privs: '',
      actions: '',
    }
  end


  def data
    records.map do |user|
      {
        id: user.id,
        email: link_to(user.email, [:admin, user], :class=>"#{'strike' if user.inactive?}"),
        last_request: user.last_request_at.to_s,
        logins: user.login_count,
        failed_logins: user.failed_login_count,
        status: user.status,
        privs: raw(priv_labels(user)),
        actions: link_to('Edit', [:edit,:admin,user], :class=>'tiny button'),
        DT_RowID: user.id,
     }
    end
  end


  def priv_labels(user)
    labels = []
    labels << '<span class="success label">Administrator</span>' if user.is_administrator?
    labels << '<span class="success label">Box Office</span>' if user.is_box_office_user?
    user.theaters.each do |t|
      labels << "<span class=\"label secondary\">#{t}</span>"
    end
    labels.join(' ')
  end

  def initialize(params, opts={})
    super(params, opts)
    @view = opts[:view_context]
  end


  private

  def get_raw_records
    users = User.all
    users
  end

  def current_user
    @current_user ||= options[:current_user]
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
