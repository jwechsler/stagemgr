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

function recalc_row(row){
  tds = row.children('td');
  production_code = tds.children('input.autocomplete_tccode').val();
  performance_code = tds.children('input.autocomplete_tccode').val();
  ticket_class_code = tds.children('input.autocomplete_tccode').val();
  if(production_code.length<1 || performance_code.length<1 || ticket_class_code.length<1){
    row.removeAttr('price');
    row.removeAttr('ticket_type');
  }
  price_override_input = tds.children('input.price_override');
  if(row.attr('ticket_type')!='Donation'){
    price_override_input.attr('disabled','disabled');
    price_override_input.val('');
  }else{
    price_override_input.removeAttr('disabled');
  }
  ticket_count = tds.children('input.ticket_count').val();
  ticket_price = tds.children('input.price_override').val() || row.attr('price')
  row.children('td.total').text(formatCurrency(1*ticket_count*ticket_price));
}
function add_autocomplete(){
jQuery(function($){
  //autocomplete
  $('input.autocomplete_prcode').each(function(){
    var input = $(this);
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
	  my_tr = input.parents('tr');
      my_tr.children('td').children('input.autocomplete_pcode').val('');
      recalc_row(my_tr);
	});
  });
  $('input.autocomplete_pcode').each(function(){
    var input = $(this);
    input.autocomplete(input.attr('autocomplete_url'),{
	  cacheLength:0,
      matchContains:1,//also match inside of strings when caching
      mustMatch:1,//allow only values from the list
      removeInitialValue:0,//when first applying $.autocomplete
      formatItem: function(row, i, max) {
        return "" + row[0] + " -- " + row[1];
      },
      extraParams:{production_code:function(){ return input.parents('tr').children('td').children('input.autocomplete_prcode').val() }},
      width: 400
    }).result(function(event, item) {
	  my_tr = input.parents('tr');
      my_tr.children('td').children('input.autocomplete_tccode').val('');
	});
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
      extraParams:{performance_code:function(){ return input.parents('tr').children('td').children('input.autocomplete_pcode').val() }},
      width: 400
    }).result(function(event, data, formatted) {
	  if(data){
		my_tr = input.parents('tr');
		 my_tr.attr('price',data[3]);
		 my_tr.attr('ticket_type',data[2]);
	  }
	});
  });
  //recalculate line on any change
  $('input.autocomplete_prcode,input.autocomplete_pcode,input.autocomplete_tccode,input.ticket_count,input.price_override').each(function(){var input=$(this); input.change(function(){recalc_row(input.parents('tr'))})});
});
}

add_autocomplete();