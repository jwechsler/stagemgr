//= require_this
// setup dataTable with standard active switch selector. Call from ready state
function setupActiveSwitchOnDataTable(table_selector, status_column_idx) {
  $("div.toolbar-buttons").html('<a style="margin-right:6px; width:10em;" id="active-switch" href="#" class="tiny button right" >Active</a>');
    var settings = $(table_selector).dataTable().fnSettings();
    var activeSwitch = $('#active-switch');
    var table = $(table_selector).DataTable();

    if ((typeof settings.aoPreSearchCols[status_column_idx] == 'undefined') ||settings.aoPreSearchCols[status_column_idx].sSearch.length==0) {
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


//
setInterval("refresh_window();",28805000);

function refresh_window(){
  window.location = location.href;
};


function confirmSubmit(prompt, val) {
  if (confirm(prompt)) {
    $('.submit-button').prop('disabled', true);
    $('#submit_action').val(val);
    $('.simple_form').submit();
    return true;
    // @todo disable button with processing instructions
  } else {
    return false;
  };
};

function submitForm(val) {
  $('#submit_action').val(val);
  $('#admin_ticket_order_form').submit();
};

// Email Attendees Modal Handlers
$(document).ready(function() {
  console.log('Admin application JS loaded');

  // Get the app root path from meta tag
  var appRootPath = $('meta[name="app-root-path"]').attr('content') || '';

  // Foundation will auto-initialize elements with data-reveal attribute
  // No need to manually initialize

  // Fix Foundation disabling buttons - force enable Cancel and Close buttons when modal opens
  $(document).on('open.zf.reveal', '#email-attendees-modal', function() {
    $('#email-attendees-modal button.secondary').prop('disabled', false);
    $('#email-attendees-modal .close-button').prop('disabled', false);
  });

  // Open modal and fetch recipient count
  $(document).on('click', '.email-attendees-btn', function(e) {
    e.preventDefault();
    console.log('Email attendees button clicked');

    var performanceId = $(this).data('performance-id');
    var performanceCode = $(this).data('performance-code');
    var theaterId = $(this).data('theater-id');
    var productionId = $(this).data('production-id');
    var productionName = $(this).data('production-name');
    var performanceDate = $(this).data('performance-date');

    console.log('Performance ID:', performanceId, 'Theater ID:', theaterId, 'Production ID:', productionId);

    // Store IDs in hidden fields
    $('#broadcast-performance-id').val(performanceId);
    $('#broadcast-theater-id').val(theaterId);
    $('#broadcast-production-id').val(productionId);

    // Pre-fill subject with production name and date
    $('#broadcast-subject').val('Important update regarding ' + productionName + ' on ' + performanceDate);

    // Reset form
    $('#broadcast-body').val('');
    $('#broadcast-from-address').val('');

    // Disable send button while loading
    $('#confirm-broadcast').prop('disabled', true);
    $('#recipient-count').text('Loading...').removeClass('success alert').addClass('secondary');

    // Fetch recipient count
    var url = appRootPath + '/admin/theaters/' + theaterId + '/productions/' + productionId + '/performances/' + performanceId + '/email_attendees_form';
    console.log('Fetching recipient count from:', url);

    $.ajax({
      url: url,
      method: 'GET',
      success: function(data) {
        console.log('Recipient count response:', data);
        var count = data.recipient_count;
        $('#recipient-count').text(count).removeClass('secondary');
        $('#send-button-count').text(count);

        if (count > 0) {
          $('#recipient-count').addClass('success');
          $('#confirm-broadcast').prop('disabled', false);
        } else {
          $('#recipient-count').addClass('alert');
          $('#confirm-broadcast').prop('disabled', true);
        }
      },
      error: function(xhr, status, error) {
        console.error('Error loading recipient count:', status, error, xhr.responseText);
        $('#recipient-count').text('Error loading').removeClass('secondary').addClass('alert');
        $('#confirm-broadcast').prop('disabled', true);
        alert('Error loading recipient count. Please try again.');
      }
    });

    // Open modal
    $('#email-attendees-modal').foundation('open');
  });

  // Send broadcast
  $(document).on('click', '#confirm-broadcast', function(e) {
    e.preventDefault();

    // Validate form first
    var subject = $('#broadcast-subject').val().trim();
    var fromAddress = $('#broadcast-from-address').val();
    var body = $('#broadcast-body').val().trim();

    if (!subject || !fromAddress || !body) {
      alert('Please fill in all required fields.');
      return;
    }

    var recipientCount = $('#recipient-count').text();

    if (!confirm('Are you sure you want to send this email to ' + recipientCount + ' recipients?')) {
      return;
    }

    // Disable button to prevent double-submission
    $(this).prop('disabled', true).text('Sending...');

    var performanceId = $('#broadcast-performance-id').val();
    var theaterId = $('#broadcast-theater-id').val();
    var productionId = $('#broadcast-production-id').val();

    var appRootPath = $('meta[name="app-root-path"]').attr('content') || '';
    var url = appRootPath + '/admin/theaters/' + theaterId + '/productions/' + productionId + '/performances/' + performanceId + '/send_broadcast';

    $.ajax({
      url: url,
      method: 'POST',
      data: {
        subject: subject,
        from_address: fromAddress,
        body: body
      },
      success: function(data) {
        if (data.success) {
          alert(data.message);
          $('#email-attendees-modal').foundation('close');
          // Reset form
          $('#email-attendees-form')[0].reset();
        } else {
          alert('Error: ' + data.message);
        }
        $('#confirm-broadcast').prop('disabled', false).text('Send Email to ' + recipientCount + ' Recipients');
      },
      error: function(xhr) {
        var message = 'Error sending broadcast. Please try again.';
        if (xhr.responseJSON && xhr.responseJSON.message) {
          message = 'Error: ' + xhr.responseJSON.message;
        }
        alert(message);
        $('#confirm-broadcast').prop('disabled', false).text('Send Email to ' + recipientCount + ' Recipients');
      }
    });
  });
});

// Allocation sync status polling — auto-clears banner when background job finishes
$(document).ready(function() {
  var $banner = $('#allocation-status-banner');
  if ($banner.length === 0) return;

  var statusUrl = $banner.data('status-url');
  if (!statusUrl || $banner.hasClass('hide')) return;

  var pollInterval = setInterval(function() {
    $.ajax({
      url: statusUrl,
      method: 'GET',
      dataType: 'json',
      success: function(data) {
        if (!data.syncing) {
          $banner.addClass('hide');
          clearInterval(pollInterval);
        }
      }
    });
  }, 5000);
});
