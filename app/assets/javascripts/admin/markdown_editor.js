// Markdown-enabled fields (app/inputs/markdown_input.rb): the rendered preview
// is the resting display; its header's toggle (or a click on the preview)
// opens a formatting toolbar and the textarea below it. Email fields may also
// have "Send sample email" in the header (SampleEmails). The toolbar only inserts markdown into the
// textarea; the preview is rendered by the server with the site's own
// Redcarpet renderer, so it matches the public page exactly.
(function() {
  var PREVIEW_DELAY_MS = 350;
  var EMPTY_PREVIEW = '<p class="markdown-editor__empty">Nothing here yet.</p>';

  var SENDING_LABEL = 'Sending…';

  function previewUrl() {
    var root = document.querySelector('meta[name="app-root-path"]');
    return (root ? root.content : '') + '/admin/markdown_preview';
  }

  function csrfToken() {
    var meta = document.querySelector('meta[name="csrf-token"]');
    return meta ? meta.content : '';
  }

  // Replace the selection through execCommand when the browser allows it, so
  // the change lands on the textarea's native undo stack (Cmd-Z still works).
  function replaceSelection(textarea, text, selectStart, selectEnd) {
    var start = textarea.selectionStart;
    textarea.focus();
    var usedNative = document.execCommand && document.execCommand('insertText', false, text);
    if (!usedNative) {
      textarea.setRangeText(text, start, textarea.selectionEnd, 'end');
      textarea.dispatchEvent(new Event('input', { bubbles: true }));
    }
    textarea.setSelectionRange(start + selectStart, start + selectEnd);
  }

  function wrap(textarea, marker, placeholder) {
    var selected = textarea.value.slice(textarea.selectionStart, textarea.selectionEnd);
    var inner = selected || placeholder;
    replaceSelection(textarea, marker + inner + marker, marker.length, marker.length + inner.length);
  }

  function link(textarea) {
    var selected = textarea.value.slice(textarea.selectionStart, textarea.selectionEnd);
    var label = selected || 'link text';
    var text = '[' + label + '](https://)';
    // Leave "https://" selected so the user can paste the address over it.
    var urlStart = label.length + 3;
    replaceSelection(textarea, text, urlStart, urlStart + 'https://'.length);
  }

  // Prefix every line touched by the selection (whole lines, not a fragment).
  function prefixLines(textarea, prefixFor) {
    var value = textarea.value;
    var lineStart = value.lastIndexOf('\n', textarea.selectionStart - 1) + 1;
    var lineEnd = value.indexOf('\n', textarea.selectionEnd);
    if (lineEnd === -1) lineEnd = value.length;
    textarea.setSelectionRange(lineStart, lineEnd);

    var lines = value.slice(lineStart, lineEnd).split('\n');
    var text = lines.map(function(line, i) { return prefixFor(i) + line; }).join('\n');
    replaceSelection(textarea, text, text.length, text.length);
  }

  var ACTIONS = {
    bold: function(t) { wrap(t, '**', 'bold text'); },
    italic: function(t) { wrap(t, '*', 'italic text'); },
    link: link,
    heading: function(t) { prefixLines(t, function() { return '### '; }); },
    bullets: function(t) { prefixLines(t, function() { return '- '; }); },
    numbers: function(t) { prefixLines(t, function(i) { return (i + 1) + '. '; }); }
  };

  var SHORTCUTS = { b: 'bold', i: 'italic', k: 'link' };

  function setup(editor) {
    var textarea = editor.querySelector('textarea');
    var previewToggle = editor.querySelector('.markdown-editor__toggle');
    var preview = editor.querySelector('.markdown-editor__preview');
    var editPanel = editor.querySelector('.markdown-editor__edit');
    var timer = null;
    var requestSeq = 0;

    function refreshPreview() {
      var text = textarea.value;
      if (!text.trim()) {
        requestSeq++;
        preview.innerHTML = EMPTY_PREVIEW;
        return;
      }
      var seq = ++requestSeq;
      var body = new FormData();
      body.append('text', text);
      body.append('flavor', editor.dataset.markdownFlavor || 'web');
      fetch(previewUrl(), {
        method: 'POST',
        headers: { 'X-CSRF-Token': csrfToken() },
        credentials: 'same-origin',
        body: body
      }).then(function(response) {
        if (!response.ok) throw new Error('Preview failed: HTTP ' + response.status);
        return response.text();
      }).then(function(html) {
        // Server-rendered from the user's own draft by the site renderer:
        // the same HTML the public page will show once saved.
        if (seq === requestSeq) preview.innerHTML = html;
      }).catch(function(error) {
        console.error(error);
        if (seq === requestSeq) {
          preview.innerHTML = '<p class="markdown-editor__error">Preview unavailable right now. Your text is not affected.</p>';
        }
      });
    }

    function schedulePreview() {
      clearTimeout(timer);
      timer = setTimeout(refreshPreview, PREVIEW_DELAY_MS);
    }

    function setOpen(isOpen) {
      editPanel.hidden = !isOpen;
      editor.classList.toggle('is-editing', isOpen);
      previewToggle.setAttribute('aria-expanded', String(isOpen));
      if (isOpen) textarea.focus();
    }

    // The server renders every editor open so the field still works without
    // JavaScript; collapse to the preview unless it should start open.
    if (editor.dataset.markdownStartOpen !== 'true') setOpen(false);

    previewToggle.addEventListener('click', function() {
      setOpen(editPanel.hidden);
    });

    // A mouse convenience: the toggle above is the keyboard-reachable control.
    preview.addEventListener('click', function(event) {
      // A link in the preview must not navigate away from an unsaved form.
      if (event.target.closest('a')) event.preventDefault();
      if (editPanel.hidden) setOpen(true);
    });

    editor.querySelector('[data-markdown-done]').addEventListener('click', function() {
      setOpen(false);
      previewToggle.focus();
    });

    editor.querySelectorAll('[data-markdown-action]').forEach(function(button) {
      button.addEventListener('click', function() {
        ACTIONS[button.dataset.markdownAction](textarea);
        schedulePreview();
      });
    });

    textarea.addEventListener('keydown', function(event) {
      if (event.key === 'Escape') {
        // Keep Escape from also closing a surrounding modal (and the draft).
        event.stopPropagation();
        setOpen(false);
        previewToggle.focus();
        return;
      }
      if (!(event.metaKey || event.ctrlKey) || event.altKey || event.shiftKey) return;
      var action = SHORTCUTS[event.key.toLowerCase()];
      if (!action) return;
      event.preventDefault();
      ACTIONS[action](textarea);
      schedulePreview();
    });

    // The first preview is rendered with the page; only edits hit the server.
    // Scripts that set the textarea's value directly (the email attendees
    // modal resets it) dispatch 'input' to refresh the preview.
    textarea.addEventListener('input', schedulePreview);
  }

  // The whole enclosing form, so the sample shows every unsaved edit.
  function sampleBody(form) {
    var body = form ? new FormData(form) : new FormData();
    // Rails would turn the POST into the edit form's PATCH, which isn't routed.
    body.delete('_method');
    // No email uses an upload (membership card artwork); don't send the files.
    var fileNames = [];
    body.forEach(function(value, name) {
      if (value instanceof File) fileNames.push(name);
    });
    fileNames.forEach(function(name) { body.delete(name); });
    return body;
  }

  function sendSample(button) {
    if (!window.confirm('Send a sample ' + button.dataset.emailName + ' to ' + button.dataset.email + '?')) return;

    var label = button.textContent;
    button.disabled = true;
    button.textContent = SENDING_LABEL;
    fetch(button.dataset.url, {
      method: 'POST',
      headers: { 'X-CSRF-Token': csrfToken(), 'Accept': 'application/json' },
      credentials: 'same-origin',
      body: sampleBody(button.closest('form'))
    }).then(function(response) {
      return response.json().catch(function() {
        throw new Error('HTTP ' + response.status);
      });
    }).then(function(data) {
      window.alert(data.success ? data.message : 'Error: ' + data.message);
    }).catch(function(error) {
      console.error(error);
      window.alert('Could not send the sample email. Please try again.');
    }).then(function() {
      button.disabled = false;
      button.textContent = label;
    });
  }

  document.addEventListener('click', function(event) {
    var button = event.target.closest('[data-markdown-sample]');
    if (!button) return;
    event.preventDefault();
    event.stopPropagation();
    sendSample(button);
  });

  document.addEventListener('DOMContentLoaded', function() {
    document.querySelectorAll('[data-markdown-editor]').forEach(setup);
  });
})();
