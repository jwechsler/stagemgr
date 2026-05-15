$(document).on('ready turbolinks:load', function () {
  document.querySelectorAll('input[data-tagify]').forEach(function (input) {
    if (input.dataset.tagifyInitialized) return;
    input.dataset.tagifyInitialized = '1';

    var tagify = new Tagify(input, {
      whitelist: [],
      dropdown: {
        enabled: 1,
        maxItems: 20,
        closeOnSelect: false,
        highlightFirst: true
      },
      originalInputValueFormat: function (values) {
        return values.map(function (item) { return item.value; }).join(',');
      },
      editTags: 1
    });

    var url = input.dataset.tagifyUrl;
    if (!url) return;

    var controller;
    tagify.on('input', function (e) {
      var term = e.detail.value || '';
      tagify.whitelist = null;
      if (controller) controller.abort();
      controller = new AbortController();
      tagify.loading(true).dropdown.hide();
      fetch(url + '?term=' + encodeURIComponent(term), { signal: controller.signal })
        .then(function (r) { return r.json(); })
        .then(function (names) {
          tagify.whitelist = names;
          tagify.loading(false).dropdown.show(term);
        })
        .catch(function () { tagify.loading(false); });
    });
  });
});
