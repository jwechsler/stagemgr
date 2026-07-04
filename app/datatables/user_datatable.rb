class UserDatatable < DatatableBase
  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format

    @view_columns ||= {
      email: { source: 'User.email' },
      last_request: { source: 'User.last_request_at', searchable: false },
      logins: { source: 'User.login_count', searchable: false },
      failed_logins: { source: 'User.failed_login_count', searchable: false },
      status: { source: 'User.status' },
      privs: { searchable: false },
      actions: { searchable: false }
    }
  end

  def data
    records.map do |user|
      {
        id: user.decorate.id,
        email: user.decorate.email,
        last_request: user.decorate.last_request_at,
        logins: user.decorate.login_count,
        failed_logins: user.decorate.failed_login_count,
        status: user.decorate.status,
        privs: user.decorate.privs,
        actions: user.decorate.dt_actions,
        DT_RowID: user.id
      }
    end
  end

  private

  def get_raw_records
    User.all
  end

  # ==== These methods represent the basic operations to perform on records
  # and feel free to override them

  # def filter_records(records)
  # end

  def sort_records(records)
    records.order(:status, :email)
  end

  # def paginate_records(records)
  # end

  # ==== Insert 'presenter'-like methods below if necessary
end
