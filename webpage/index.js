
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

/**
 * Generate a Table of Contents.
 */
$(function() {

  $('#toc-button').hover(function() { $('#toc').show('fast') })
  $('#toc').hover(function() {}, function() { $('#toc').hide() })

  var get_indent = function(level) {
    var s = '';
    for (var i = 1; i < level; i++) { s += '&nbsp;&nbsp;' }
    return $('<span>' + s + '</span>');
  }

  var links = $('<div>')
  $('h1,h2,h3,h4,h5,h6').each(function(i, elt) {
    level = elt.tagName.substr(1) * 1
    get_indent(level).appendTo(links);
    $('<a>').attr('href', '#' + elt.id).text($(elt).text()).click(function() {
      $('#toc').hide()
    }).appendTo(links);
    $('<br>').appendTo(links);
  });
  links.appendTo($('#toc-links'))
})
