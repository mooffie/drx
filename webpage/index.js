
/**
 * Colorize Ruby comments and strings.
 */
$(function() {
  $('pre').each(function(i, elt) {
    var html = $(elt).html()
    html = html.replace(/(#[^\r\n]*|'[^']*'|"[^"]*")/g, function(str) {             // '
      var cls = (str.charAt(0) == '#') ? 'comment' : 'string'
      return '<span class="' + cls + '">' + str + '</span>'
    });
    $(elt).html(html)
  });
})
