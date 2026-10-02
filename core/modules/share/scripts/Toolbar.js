/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[Toolbar]{@link Toolbar}</li>
 *     <li>[Toolbar.Control]{@link Toolbar.Control}</li>
 *     <li>[Toolbar.Button]{@link Toolbar.Button}</li>
 *     <li>[Toolbar.File]{@link Toolbar.File}</li>
 *     <li>[Toolbar.Switcher]{@link Toolbar.Switcher}</li>
 *     <li>[Toolbar.Separator]{@link Toolbar.Separator}</li>
 *     <li>[Toolbar.Select]{@link Toolbar.Select}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @requires Energine
 *
 * @author Pavel Dubenko, Valerii Zinchenko
 *
 * @version 1.1.0
 */

import {Energine} from 'Energine';

/**
 * Панель кнопок: ul.toolbar с кнопками li. Действие кнопки — метод объекта, к которому панель привязана (bindTo).
 *
 * @constructor
 * @param {string} toolbarName Имя панели: класс ul и начало id кнопок со значками.
 * @param {Object} [props] Свойства панели (например, noSideFrame у панели страницы).
 */
export class Toolbar {
    constructor(toolbarName, props) {
        Energine.loadCSS('toolbar.css');
        this.name = toolbarName;
        this.boundTo = null;
        this.controls = [];
        this.element = document.createElement('ul');
        this.element.classList.add('toolbar', 'clearfix');
        if (this.name) {
            this.element.classList.add(this.name);
        }
        this.properties = (props && typeof props === 'object') ? props : {};
    }

    // панель прикреплена к верху окна (панель страницы)
    dock() {
        this.element.classList.add('docked_toolbar');
    }

    getElement() {
        return this.element;
    }

    bindTo(object) {
        this.boundTo = object;
    }

    /**
     * Добавить кнопки: готовые (Toolbar.Control) или описания {type, id, onclick, …} — по описанию создаётся
     * Toolbar[Тип], onclick становится действием. Остальное пропускается.
     */
    appendControl(...controls) {
        controls.forEach((control) => {
            if (control && control.type && control.id) {
                const type = control.type.charAt(0).toUpperCase() + control.type.slice(1);
                control.action = control.onclick;
                delete control.onclick;
                control = new Toolbar[type](control);
            }
            if (control instanceof Toolbar.Control) {
                control.toolbar = this;
                control.build();
                if (control.element) {
                    this.element.appendChild(control.element);
                }
                this.controls.push(control);
            }
        });
    }

    getControlById(id) {
        return this.controls.find((control) => control.properties.id == id) || null;
    }

    // без id — все кнопки, кроме «Закрыть»
    disableControls(...ids) {
        if (!ids.length) {
            this.controls.forEach((control) => {
                if (control.properties.id != 'close') {
                    control.disable();
                }
            });
            return;
        }
        ids.forEach((id) => {
            const control = this.getControlById(id);
            if (control) {
                control.disable();
            }
        });
    }

    // без id — все кнопки; выключенные в описании остаются выключенными (enable(true) включает и их)
    enableControls(...ids) {
        const controls = ids.length ? ids.map((id) => this.getControlById(id)).filter(Boolean) : this.controls;
        controls.forEach((control) => control.enable());
    }

    callAction(action, data) {
        if (this.boundTo && typeof this.boundTo[action] === 'function') {
            this.boundTo[action](data);
        }
    }
};

/**
 * Кнопка панели — основа: свойства id, icon, title, tooltip, action, disabled, class.
 *
 * @constructor
 * @param {Object} [properties]
 */
Toolbar.Control = class ToolbarControl {
    constructor(properties) {
        this.toolbar = null;
        this.element = null;
        this.properties = Object.assign({id: '', icon: '', title: '', tooltip: '', action: '', disabled: false}, properties);
        if (this.properties.disabled) {
            this.properties.isDisabled = !!this.properties.disabled;
            this.properties.isInitiallyDisabled = this.properties.isDisabled;
        }
    }

    // кнопка-значок: картинка фоном, подпись — в подсказке
    buildAsIcon(icon) {
        this.element.classList.add('icon', 'unselectable');
        this.element.id = this.toolbar.name + this.properties.id;
        this.element.title = this.properties.title + (this.properties.tooltip ? ' (' + this.properties.tooltip + ')' : '');
        this.element.style.userSelect = 'none';
        this.element.style.backgroundImage = 'url(' + Energine.base + icon + ')';
    }

    build() {
        if (!this.toolbar || !this.properties.id) {
            return;
        }
        this.element = document.createElement('li');
        this.element.setAttribute('unselectable', 'on');
        if (this.properties.icon) {
            this.buildAsIcon(this.properties.icon);
        } else {
            this.element.title = this.properties.tooltip;
            this.element.appendChild(document.createTextNode(this.properties.title));
        }
        if (this.properties.isDisabled) {
            this.disable();
        }
    }

    disable() {
        this.properties.isDisabled = true;
        this.element.classList.add('disabled');
        this.element.style.opacity = '0.25';
    }

    // выключенная в описании включается только с force
    enable(force) {
        if (force) {
            this.properties.isInitiallyDisabled = false;
        }
        if (!this.properties.isInitiallyDisabled) {
            this.properties.isDisabled = false;
            this.element.classList.remove('disabled');
            this.element.style.opacity = '1';
        }
    }

    disabled() {
        return this.properties.isDisabled;
    }
};

/**
 * Кнопка: класс <id>_btn, подсветка при наведении, щелчок — действие (с событием щелчка).
 *
 * @constructor
 * @param {Object} [properties]
 */
Toolbar.Button = class ToolbarButton extends Toolbar.Control {
    build() {
        super.build();
        if (!this.element) {
            return;
        }
        this.element.classList.add(this.properties.id + '_btn');
        if (this.properties.class) {
            this.element.classList.add(...String(this.properties.class).split(/\s+/).filter(Boolean));
        }
        this.element.addEventListener('mouseover', () => {
            if (!this.properties.isDisabled) {
                this.element.classList.add('highlighted');
            }
        });
        this.element.addEventListener('mouseout', () => this.element.classList.remove('highlighted'));
        this.element.addEventListener('click', (event) => this.callAction(event));
        // нажатие мыши не уводит фокус из поля формы и не выделяет текст
        this.element.addEventListener('mousedown', (event) => {
            event.preventDefault();
            event.stopPropagation();
        });
    }

    // выключить по признаку (например, при выборе нескольких строк грида) …
    DisableAndSetProperty(property) {
        if (!this.properties.isDisabled) {
            this.properties[property] = true;
            this.properties.isDisabled = true;
            this.element.classList.add('disabled');
            this.element.style.opacity = '0.25';
        }
    }

    // … и включить, только если выключена по этому признаку
    EnableByProperty(property) {
        if (this.properties[property] === true) {
            this.properties[property] = false;
            this.properties.isDisabled = false;
            this.element.classList.remove('disabled');
            this.element.style.opacity = '1';
        }
    }

    callAction(data) {
        if (!this.properties.isDisabled) {
            this.toolbar.callAction(this.properties.action, data);
        }
    }
};

/**
 * Кнопка выбора файла: открывает выбор файла, действие получает прочитанный файл (FileReader).
 *
 * @constructor
 * @param {Object} [properties]
 */
Toolbar.File = class ToolbarFile extends Toolbar.Button {
    build() {
        super.build();
        if (!this.element) {
            return;
        }
        const input = document.createElement('input');
        input.type = 'file';
        input.id = this.properties.id;
        input.addEventListener('change', (event) => {
            const file = event.target.files[0];
            if (!file) {
                return;
            }
            const reader = new FileReader();
            reader.onload = (e) => {
                if (!this.properties.isDisabled) {
                    this.toolbar.callAction(this.properties.action, e.target);
                }
            };
            reader.readAsDataURL(file);
        });
        this.element.appendChild(input);
    }

    callAction() {
        this.element.querySelector('input[type=file]').click();
    }
};

/**
 * Кнопка-переключатель: state — нажата ли, aicon — значок нажатой. Действие срабатывает до смены состояния.
 *
 * @constructor
 * @param {Object} [properties]
 */
Toolbar.Switcher = class ToolbarSwitcher extends Toolbar.Button {
    constructor(properties) {
        super(properties);
        this.properties.state = this.properties.state ? !!parseInt(this.properties.state, 10) : false;
    }

    build() {
        super.build();
        if (!this.element) {
            return;
        }
        const toggle = () => {
            if (this.properties.state) {
                if (this.properties.aicon) {
                    this.buildAsIcon(this.properties.aicon);
                } else {
                    this.element.classList.add('pressed');
                }
            } else if (this.properties.icon) {
                this.buildAsIcon(this.properties.icon);
            } else {
                this.element.classList.remove('pressed');
            }
        };
        // обработчик действия кнопки добавлен раньше — состояние меняется после действия
        this.element.addEventListener('click', () => {
            if (!this.properties.isDisabled) {
                this.properties.state = !this.properties.state;
                toggle();
            }
        });
        toggle();
    }

    getState() {
        return this.properties.state;
    }
};

/**
 * Разделитель кнопок; не выключается.
 *
 * @constructor
 * @param {Object} [properties]
 */
Toolbar.Separator = class ToolbarSeparator extends Toolbar.Control {
    build() {
        super.build();
        if (this.element) {
            this.element.classList.add('separator');
        }
    }

    disable() {
    }
};

/**
 * Выпадающий список: подпись и select; смена — действие с самим списком.
 *
 * @constructor
 * @param {Object} properties Свойства (id, title, action; options и initialValue — вместо следующих параметров).
 * @param {Object} [options] Значения: {значение: текст}.
 * @param {string} [initialValue] Выбранное значение.
 */
Toolbar.Select = class ToolbarSelect extends Toolbar.Control {
    constructor(properties, options, initialValue) {
        super();
        properties = properties || {};
        this.properties = Object.assign({id: null, title: '', tooltip: '', action: null, disabled: false}, properties);
        this.options = options || properties.options || {};
        this.initial = initialValue || properties.initialValue || false;
        this.select = null;
    }

    build() {
        if (!this.toolbar || !this.properties.id) {
            return;
        }
        this.element = document.createElement('li');
        this.element.setAttribute('unselectable', 'on');
        this.element.classList.add('select');
        if (this.properties.title) {
            const label = document.createElement('span');
            label.className = 'label';
            label.textContent = this.properties.title;
            this.element.appendChild(label);
        }
        this.select = document.createElement('select');
        this.select.addEventListener('change', () => this.toolbar.callAction(this.properties.action, this));
        this.element.appendChild(this.select);
        if (this.properties.isDisabled) {
            this.disable();
        }
        Object.keys(this.options).forEach((key) => {
            const option = document.createElement('option');
            option.value = key;
            option.textContent = this.options[key];
            if (key == this.initial) {
                option.selected = true;
            }
            this.select.appendChild(option);
        });
    }

    disable() {
        if (!this.properties.isDisabled) {
            this.properties.isDisabled = true;
            this.select.disabled = true;
        }
    }

    enable() {
        if (this.properties.isDisabled) {
            this.properties.isDisabled = false;
            this.select.disabled = false;
        }
    }

    getValue() {
        const selected = [...this.select.selectedOptions];
        return selected.length ? selected[selected.length - 1].value : null;
    }

    setSelected(itemId) {
        if (this.options[itemId] && this.select) {
            const option = [...this.select.options].find((o) => o.value === String(itemId));
            if (option) {
                option.selected = true;
            }
        }
    }
};
