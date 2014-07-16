//= require application
//= require admin/orders_common
//= require cocoon

// setup dataTable with standard active switch selector. Call from ready state
function setupActiveSwitchOnDataTable(table_selector, status_column_idx) {
  $("div.toolbar-buttons").html('<a style="margin-right:6px; width:10em;" id="active-switch" href="#" class="tiny button right" >Active</a>');
    var settings = $(table_selector).dataTable().fnSettings();
    var activeSwitch = $('#active-switch');
    var table = $(table_selector).DataTable();
    table.columns(status_column_idx).search('^Active$');

    if ((typeof settings.aoPreSearchCols[status_column_idx] != 'undefined') && settings.aoPreSearchCols[status_column_idx].sSearch.length>0) {
      activeSwitch.text('Show Active')
    } else {
      activeSwitch.text('Show All')
    }
    activeSwitch.prop('checked',true);
    activeSwitch.on('click', function () {
      cSearch = settings.aoPreSearchCols[status_column_idx].sSearch
      if (cSearch.length==0) {
        find_text = "^Active$";
        $(this).text('Show All')
      } else {
        find_text = ""
        $(this).text('Show Active')
      }
      table.column(status_column_idx)
        .search( find_text , true, false )
        .draw();

    });
}

