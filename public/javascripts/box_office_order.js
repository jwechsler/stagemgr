var add_autocomplete = function(){
jQuery(function($){//on document ready
  //autocomplete
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
      width: 400
    }).result(function(event, item) {
	  input.parents('tr').children('td').children('input.autocomplete_tccode').val('');
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
    });
  });
});
}

add_autocomplete()