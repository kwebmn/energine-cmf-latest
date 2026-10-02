/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[Filters]{@link Filters}</li>
 *     <li>[Filter]{@link Filter}</li>
 *     <li>[Filter.QueryControls]{@link Filter.QueryControls}</li>
 *     <li>[Filter.Clause]{@link Filter.Clause}</li>
 *     <li>[Filter.ClauseSet]{@link Filter.ClauseSet}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 */

/**
 * Образец фильтра: разметка первого фильтра (.filter) копируется для каждого нового.
 *
 * @constructor
 * @param {Element} templateEl
 */
var FiltersFabric = class FiltersFabric {
    constructor(templateEl) {
        this.parentContainer = templateEl.parentElement.closest('.filters');
        this.template = templateEl.cloneNode(true);
        templateEl.remove();
    }

    create() {
        const element = this.template.cloneNode(true);
        this.parentContainer.appendChild(element);
        return new Filter(element);
    }
};

/**
 * Панель фильтров грида: один или несколько фильтров «поле — условие — значение», объединённых «и/или».
 *
 * @constructor
 * @param {GridManager} gridManager
 */
var Filters = class Filters {
    constructor(gridManager) {
        this.filters = [];
        this.active = false;
        this.fabric = null;
        this.gridManager = gridManager;
        this.element = gridManager.element.querySelector('.filters_block');
        if (!this.element) {
            return;
        }
        this.fabric = new FiltersFabric(this.element.querySelector('.filter'));
        this.add();
        const inner = this.element.querySelector('.filters_block_inner');
        // ссылка открывает и закрывает панель фильтров
        this.element.querySelector('.filter_toggle').addEventListener('click', (event) => {
            event.preventDefault();
            event.stopPropagation();
            if (inner.classList.contains('toggled')) {
                inner.style.height = '';
                inner.classList.remove('toggled');
            } else {
                inner.style.height = '0px';
                inner.classList.add('toggled');
            }
        });
        this.element.querySelector('.add_filter').addEventListener('click', (event) => {
            event.preventDefault();
            event.stopPropagation();
            this.add();
            Filters.resized();
        });
        this.element.querySelector('.f_apply').addEventListener('click', () => {
            if (this.use()) {
                this.gridManager.reload();
            }
        });
        this.element.querySelector('.f_reset').addEventListener('click', (event) => {
            event.preventDefault();
            event.stopPropagation();
            if (this.reset()) {
                this.gridManager.reload();
            }
        });
    }

    // размер панели изменился: гриды подгоняют свой (они слушают resize окна)
    static resized() {
        window.dispatchEvent(new Event('resize'));
    }

    add() {
        const filter = this.fabric.create();
        filter.onApply = () => {
            if (this.use()) {
                this.gridManager.reload();
            }
        };
        filter.onDelete = (f) => this.remove(f);
        this.filters.push(filter);
        if (this.filters.length == 1) {
            filter.element.querySelector('.operand_container').style.display = 'none';
            filter.element.querySelector('.remove_filter').disabled = true;
        } else {
            const operand = filter.element.querySelector('.filters_operand');
            if (getComputedStyle(operand).display === 'none') {
                operand.style.display = 'block';
            }
            this.element.querySelectorAll('.remove_filter').forEach((button) => {
                button.disabled = false;
            });
        }
    }

    remove(filter) {
        if (!filter) {
            return;
        }
        Filters.resized();
        filter.onDelete = null;
        const index = this.filters.indexOf(filter);
        if (index !== -1) {
            this.filters.splice(index, 1);
        }
        filter.reset();
        if (this.filters.length == 1) {
            this.filters[0].element.querySelector('.operand_container').style.display = 'none';
            this.filters[0].element.querySelector('.remove_filter').disabled = true;
        }
    }

    // все фильтры убираются, остаётся один пустой; false — сбрасывать нечего
    reset() {
        if (!this.active && this.filters.length <= 1) {
            return false;
        }
        while (this.filters.length) {
            this.filters[0].reset();
        }
        this.element.classList.remove('active');
        this.add();
        this.active = false;
        return true;
    }

    // непустой фильтр применяется, пустой сбрасывается; true — грид нужно перезагрузить (и после сброса: на экране
    // остались отфильтрованные строки)
    use() {
        if (!this.isEmpty()) {
            this.element.classList.add('active');
            this.active = true;
            return true;
        }
        return this.reset();
    }

    // строка запроса для грида; JSON кодируется — «+», «&» и «%» в значении доходят до сервера как есть
    getValue() {
        if (!this.active || this.isEmpty()) {
            return '';
        }
        const set = new Filter.ClauseSet();
        this.filters.forEach((filter) => set.add(filter.getValue()));
        return 'filter=' + encodeURIComponent(JSON.stringify(set)) + '&';
    }

    // пуст ли хоть один фильтр
    isEmpty() {
        return this.filters.some((filter) => filter.isEmpty());
    }
};

/**
 * Фильтр: поле, условие, значение (одно, период или дата); «−» убирает фильтр.
 *
 * @constructor
 * @param {Element} element
 */
var Filter = class Filter {
    constructor(element) {
        this.element = element;
        // обратные вызовы панели фильтров
        this.onApply = null;
        this.onDelete = null;
        this.inputs = new Filter.QueryControls(element.querySelectorAll('.f_query_container'), () => {
            if (this.onApply) {
                this.onApply();
            }
        });
        this.removeBtn = element.querySelector('.remove_filter');
        this.removeBtn.addEventListener('click', () => this.reset());
        this.condition = element.querySelector('.f_condition');
        // у условия — типы полей, для которых оно есть (data-types); без них условие есть для всех
        this.conditionOptions = [...this.condition.children];
        this.conditionTypes = new Map();
        this.conditionOptions.forEach((option) => {
            const types = option.getAttribute('data-types');
            if (types) {
                this.conditionTypes.set(option, types.split('|'));
                option.removeAttribute('data-types');
            }
        });
        this.fields = element.querySelector('.f_fields');
        this.fields.addEventListener('change', () => this.checkCondition());
        this.condition.addEventListener('change', (event) => this.switchInputs(event.target.value, this.fieldType()));
        this.checkCondition();
        this.operator = element.querySelector('.filters_operand');
    }

    fieldType() {
        const option = this.fields.options[this.fields.selectedIndex];
        return option ? option.getAttribute('type') : null;
    }

    // условия — для типа выбранного поля; поля значения — для условия; для дат — поля даты
    checkCondition() {
        const fieldType = this.fieldType();
        const isDate = (fieldType == 'datetime' || fieldType == 'date');
        this.conditionOptions.forEach((option) => {
            const types = this.conditionTypes.get(option);
            if (types) {
                if (types.includes(fieldType)) {
                    this.condition.appendChild(option);
                } else {
                    option.remove();
                }
            }
        });
        this.condition.selectedIndex = 0;
        this.switchInputs(this.condition.value, fieldType);
        this.disableInputField(isDate);
        this.inputs.showDateInputs(isDate);
        const first = this.inputs.inputs[0];
        if (getComputedStyle(first).display !== 'none') {
            first.focus();
        }
    }

    // логическое поле — без значения; «между» — два поля; иначе одно
    switchInputs(condition, type) {
        if (type == 'boolean') {
            this.inputs.hide();
        } else if (condition == 'between') {
            this.inputs.asPeriod();
        } else {
            this.inputs.asScalar();
        }
    }

    // для дат текстовые поля выключены и пусты (значение — в полях даты)
    disableInputField(disable) {
        if (disable) {
            this.inputs.inputs.forEach((input) => {
                input.disabled = true;
                input.value = '';
            });
        } else if (this.inputs.inputs[0].disabled) {
            this.inputs.inputs.forEach((input) => {
                input.disabled = false;
            });
        }
    }

    isEmpty() {
        return !(this.fieldType() == 'boolean' || this.inputs.hasValues());
    }

    // фильтр уходит со страницы и из панели
    reset() {
        this.element.remove();
        if (this.onDelete) {
            this.onDelete(this);
        }
    }

    getValue() {
        const field = this.fields.options[this.fields.selectedIndex];
        return this.inputs.getValues(new Filter.Clause(
            field.value,
            this.condition.options[this.condition.selectedIndex].value,
            field.getAttribute('type'),
            this.operator.offsetParent ? this.operator.options[this.operator.selectedIndex].value : null
        ));
    }
};

/**
 * Поля значения фильтра: по контейнеру на значение (второй — для периода), в каждом — текстовое поле и поле даты.
 *
 * @constructor
 * @param {NodeList} containers .f_query_container
 * @param {function} onApply Enter в непустом поле.
 */
Filter.QueryControls = class FilterQueryControls {
    constructor(containers, onApply) {
        this.containers = [...containers];
        this.isDate = false;
        this.containers[0].classList.remove('hidden');
        this.inputs = this.containers.map((container) => container.querySelector('input'));
        this.dpsInputs = this.inputs.map((input, n) => {
            const date = input.cloneNode(true);
            date.type = 'date';
            date.classList.add('hidden');
            this.containers[n].appendChild(date);
            return date;
        });
        this.all().forEach((input) => input.addEventListener('keydown', (event) => {
            if (event.key === 'Enter' && event.target.value !== '') {
                onApply();
            }
        }));
    }

    all() {
        return [...this.dpsInputs, ...this.inputs];
    }

    // поля значения видимых контейнеров: второй скрыт у одиночного условия, все — у логического поля
    current() {
        const inputs = this.isDate ? this.dpsInputs : this.inputs;
        return inputs.filter((input, n) => !this.containers[n].classList.contains('hidden'));
    }

    hasValues() {
        return this.current().some((input) => input.value);
    }

    getValues(clause) {
        this.current().forEach((input) => clause.setValue(String(input.value)));
        return clause;
    }

    asPeriod() {
        this.show();
        this.all().forEach((input) => input.classList.add('small'));
    }

    asScalar() {
        this.show();
        this.containers[1].classList.add('hidden');
        this.all().forEach((input) => input.classList.remove('small'));
    }

    show() {
        this.containers.forEach((container) => container.classList.remove('hidden'));
    }

    hide() {
        this.containers.forEach((container) => container.classList.add('hidden'));
    }

    showDateInputs(toShow) {
        this.isDate = toShow;
        this.inputs.forEach((input) => input.classList.toggle('hidden', toShow));
        this.dpsInputs.forEach((input) => input.classList.toggle('hidden', !toShow));
    }
};

/**
 * Условие фильтра для сервера: поле, условие, тип поля, «и/или» с предыдущим, значение (у периода — два).
 *
 * @constructor
 */
Filter.Clause = class FilterClause {
    constructor(fieldName, condition, type, operator) {
        this.field = fieldName;
        this.condition = condition;
        this.type = type;
        this.operator = (typeof operator !== 'undefined') ? operator : '';
    }

    setValue(value) {
        if (value) {
            if (this.type == 'phone') {
                value = value.replace(/\D/g, '');
            }
            if (this.value) {
                this.value = [this.value, value];
            } else {
                this.value = value;
            }
        }
        return this;
    }
};

/**
 * Набор условий фильтра (JSON для сервера: {"children": [...]}).
 *
 * @constructor
 */
Filter.ClauseSet = class FilterClauseSet {
    constructor(...clauses) {
        this.children = [];
        clauses.forEach((clause) => this.add(clause));
    }

    add(clause) {
        this.children.push(clause);
    }
};
