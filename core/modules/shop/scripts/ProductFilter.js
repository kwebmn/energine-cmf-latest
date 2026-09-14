ScriptLoader.load('scripts/jquery.nouislider.all.js');
Asset.css('jquery.nouislider.min.css');
Asset.css('shop.css');
var ProductFilter;
(function ($, window, document) {

    ProductFilter = function (el) {

        $('.range', document.id(el)).each(function (idx, el) {
            var el = $(el).prop('slide', null);

            // jQuery.data() keeps "1450.00" a string, noUiSlider needs numbers
            var num = function (name) {
                return parseFloat(el.data(name)) || 0;
            };
            el.noUiSlider({
                start: [num('start'), num('end')],
                connect: true,
                step: num('step') || 1,
                range: {
                    'min': [num('min')],
                    'max': [num('max')]
                }
            });

            el.Link('lower').to(jQuery('.lower', el));
            el.Link('upper').to(jQuery('.upper', el));
        });

    }
}(window.jQuery, window, document));