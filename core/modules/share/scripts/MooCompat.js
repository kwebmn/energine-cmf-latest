/**
 * @file Мост к MooTools для скриптов, которые на ней ещё написаны (админка): каждый объявляет MooCompat первой
 * зависимостью, и документ подключает MooTools и этот файл раньше них. Здесь — то, что нужно только рядом
 * с MooTools.
 */

/**
 * Array.from у MooTools 1.5 не понимает итерируемые объекты — Set, Map, итераторы заворачивает в массив
 * из одного элемента — и не принимает функцию-отображение. Современные библиотеки (Jodit) рассчитывают
 * на стандартное поведение: для них оно такое, для остальных вызовов (код на MooTools) — прежнее.
 */
(function () {
    var mooFrom = Array.from;
    Array.from = function (item, mapFn, thisArg) {
        var result, i, it, step;
        if (item != null && typeof item !== 'string' && typeof item.length !== 'number'
            && typeof item[Symbol.iterator] === 'function') {
            result = [];
            for (it = item[Symbol.iterator](), step = it.next(); !step.done; step = it.next()) {
                result.push(step.value);
            }
        } else if (typeof mapFn === 'function' && item != null && typeof item !== 'function'
            && typeof item.length === 'number') {
            result = [];
            for (i = 0; i < item.length; i++) {
                result.push(item[i]);
            }
        } else {
            result = mooFrom(item);
        }
        return (typeof mapFn === 'function') ? result.map(mapFn, thisArg) : result;
    };
})();

/**
 * Токен против подделки запросов (Csrf на сервере): каждый запрос Request MooTools несёт его в заголовке.
 * Energine.csrf задаёт страница (document.xslt).
 */
(function () {
    var send = Request.prototype.send;
    Request.prototype.send = function () {
        if (Energine.csrf) {
            this.setHeader('X-CSRF-Token', Energine.csrf);
        }
        return send.apply(this, arguments);
    };
})();
