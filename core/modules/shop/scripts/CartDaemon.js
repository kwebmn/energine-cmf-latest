var CartDaemon = new Class({
    initialize: function (el) {
        this.el = $(el);
        this.afterLoad = null;

        this.request = new Request.HTML({
            'method': 'get',
            'onSuccess': function (tree, elements, html) {
                // the answer is the cart/wishlist; its data-count is the new number for the informer
                var counter = this.el.getElement('.count'), body = this.el.getElement('.body'),
                    list = elements.filter(function (element) {
                        return element.hasAttribute && element.hasAttribute('data-count');
                    })[0];
                if (counter && list) {
                    counter.set('text', list.getAttribute('data-count') || '0');
                }
                if (body) {
                    body.set('html', html);
                }
                if (this.afterLoad) {
                    this.afterLoad();
                }
            }.bind(this)
        });
    },
    add: function(event, productID){
        event = new DOMEvent(event);
        event.stop();

        this.request.send({url:this.el.getProperty('data-add-url').replace('[productID]', productID)});
    },
    load: function(func){
        this.afterLoad = func;
        this.request.send({url:this.el.getProperty('data-load-url')});
    }
});