/**
 * Подгружает блок связанных товаров после отрисовки страницы.
 * Компонент в состоянии init отдаёт только пустой контейнер с адресом,
 * по которому лежит само содержимое (состояние main, URL .../show/).
 */
var AltRelatedGoodsList = new Class({
    initialize: function (el) {
        this.element = $(el);
        var url = this.element.getProperty('data-load-url');
        if (!url) {
            return;
        }
        Asset.css('shop.css');
        this.element.set('load', {method: 'get'});
        this.element.load(url + '?html');
    }
});
