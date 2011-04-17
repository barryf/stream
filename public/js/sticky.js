// sticky fixed nav
(function($) {
  $.fn.extend({
    sticky: function() {
      var header = $(this),
          origTop = header.offset().top,
          content = header.add("#home");

      $(window).scroll(function(e) {
        if ($(this).scrollTop() > origTop) {
          content.addClass("sticky");
        } else if ($(this).scrollTop() < origTop) {
          content.removeClass("sticky");
        }
      });
    }
  });
  $(function() {
    $('#types').sticky();
  });
}(jQuery));