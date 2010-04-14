function formatCurrency(num) {
  num = num.toString().replace(/\$|\,/g,'');
  if(isNaN(num))
    num = "0";
  sign = (num == (num = Math.abs(num)));
  num = Math.floor(num*100+0.50000000001);
  cents = num%100;
  num = Math.floor(num/100).toString();
  if(cents<10)
    cents = "0" + cents;
  for (var i = 0; i < Math.floor((num.length-(1+i))/3); i++)
    num = num.substring(0,num.length-(4*i+3))+','+
  num.substring(num.length-(4*i+3));
  return (((sign)?'':'-') + '$' + num + '.' + cents);
}

function recalculate_all_row_totals(){
  jQuery('input.autocomplete_tccode').each(function(){
	var ticket_class_code_input = jQuery(this);
	ticket_class_code_input.val('');
    var my_tr=ticket_class_code_input.parents('tr');
    recalculate_row_total(my_tr);
  });	  
}

function recalculate_row_total(row){
  tds = row.children('td');
  production_code = jQuery('#order_production_code').val();
  performance_code_input = jQuery('#order_performance_code');
  ticket_class_code_input = tds.children('input.autocomplete_tccode');
  ticket_class_code = '';
  line_price=0;
  if(production_code.length < 1){
    performance_code_input.val('');
    ticket_class_code_input.val('');
  }else{
    performance_code = performance_code_input.val();
    if(performance_code.length < 1){
      ticket_class_code_input.val('');
    }
    ticket_class_code = tds.children('input.autocomplete_tccode').val();
  }
  if(ticket_class_code.length<1){
    row.removeAttr('price');
    row.removeAttr('ticket_type');
  }else{
    price_override_input = tds.children('input.price_override');
    if(row.attr('ticket_type')!='Donation'){
      price_override_input.attr('disabled','disabled');
      price_override_input.val('');
    }else{
      price_override_input.removeAttr('disabled');
    }
    ticket_count = tds.children('input.ticket_count').val();
    ticket_price = tds.children('input.price_override').val() || row.attr('price');
    line_price = 1*ticket_count*ticket_price;
  }
  row.children('td.total').text(formatCurrency(line_price));
}
function add_autocomplete(){
jQuery(function($){
  //clear bindings so we don't add multiple event handlers
  $('#order_production_code').unbind();
  $('#order_performance_code').unbind();
  $('input.autocomplete_tccode,input.ticket_count,input.price_override').each(function(){
    var input=$(this);
    input.unbind();
  });
  //autocomplete
  var input=$('#order_production_code');
  input.autocomplete(input.attr('autocomplete_url'),{
	  cacheLength:0,
      matchContains:1,//also match inside of strings when caching
      mustMatch:1,//allow only values from the list
      removeInitialValue:0,//when first applying $.autocomplete
      formatItem: function(row, i, max) {
        return "" + row[0] + " -- " + row[1];
      },
      width: 400
    }).result(function(event, item) {
      recalculate_all_row_totals();
      $('#order_performance_code').val('');
	});
  var input=$('#order_performance_code');
  input.autocomplete(input.attr('autocomplete_url'),{
	  cacheLength:0,
      matchContains:1,//also match inside of strings when caching
      mustMatch:1,//allow only values from the list
      removeInitialValue:0,//when first applying $.autocomplete
      formatItem: function(row, i, max) {
        return "" + row[0] + " -- " + row[1];
      },
      extraParams:{production_code:function(){ return $('#order_production_code').val() }},
      width: 400
    }).result(function(event, item) {
      $('input.autocomplete_tccode').each(function(){$(this).val('')});
      recalculate_all_row_totals();
	});
  $('input.autocomplete_tccode').each(function(){
    var input = $(this);
    input.autocomplete(input.attr('autocomplete_url'),{
      cacheLength:0,
      matchContains:1,//also match inside of strings when caching
      mustMatch:1,//allow only values from the list
      removeInitialValue:0,//when first applying $.autocomplete
      formatItem: function(row, i, max) {
        return "" + row[0] + " -- " + row[1];
      },
      extraParams:{performance_code:function(){ return $('#order_performance_code').val() }},
      width: 400
    }).result(function(event, data, formatted) {
      if(data){
        my_tr = input.parents('tr');
        my_tr.attr('price',data[3]);
        my_tr.attr('ticket_type',data[2]);
      }
      recalculate_row_total(my_tr);
    });
  });
  $('input.ticket_count,input.price_override').each(function(){
    input = $(this);
    input.change(function(){recalculate_row_total(input.parents('tr'))});
  });
});
}

add_autocomplete();