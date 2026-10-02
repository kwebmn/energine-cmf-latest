/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[TreeView]{@link TreeView}</li>
 *     <li>[TreeView.Node]{@link TreeView.Node}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @author Pavel Dubenko
 *
 * @version 1.1.0
 */

/**
 * Дерево разделов: ul с узлами li > a; у папки — вложенный ul. Двойной щелчок по названию — options.dblClick.
 *
 * @constructor
 * @param {Element|string} element
 * @param {Object} [options]
 * @param {function} [options.dblClick] Двойной щелчок по названию узла.
 */
var TreeView = class TreeView {
    constructor(element, options) {
        Energine.loadCSS('treeview.css');
        this.element = (typeof element === 'string') ? document.getElementById(element) : element;
        this.options = Object.assign({}, options);
        this.selectedNode = null;
        this.nodes = [];
    }

    // узел верхнего уровня
    adopt(node) {
        this.nodes.push(node);
        this.element.appendChild(node.element);
    }

    empty() {
        this.nodes.length = 0;
        this.element.replaceChildren();
    }

    // folder — у узла есть вложенные, last — последний среди соседей
    setupCssClasses() {
        this.element.querySelectorAll('li').forEach((item) => {
            const node = item.treeNode;
            item.classList.toggle('folder', !!(node && node.childs && node.childs.childNodes.length));
            item.classList.toggle('last', !item.nextElementSibling);
        });
    }

    getSelectedNode() {
        return this.selectedNode;
    }

    getNodeById(id) {
        return this.nodes.find((node) => node.id == id) || null;
    }

    // раскрыть все папки на пути к узлу (узел или его id)
    expandToNode(nodeId) {
        const parents = [];
        let node = (nodeId instanceof TreeView.Node) ? nodeId : this.getNodeById(nodeId);
        while (node && (node = TreeView.Node.parentOf(node))) {
            parents.push(node);
        }
        parents.reverse().forEach((parent) => parent.expand());
    }

    expandAllNodes() {
        this.nodes.forEach((node) => node.expand());
    }

    // щелчок по строке узла: значок слева от папки (8×8 у верха строки) раскрывает и сворачивает её
    nodeToggleListener(event, node) {
        event.preventDefault();
        event.stopPropagation();
        if (event.target !== node.element) {
            return;
        }
        const rect = node.element.getBoundingClientRect();
        const x = event.clientX - rect.left;
        const y = event.clientY - rect.top;
        if (x < 0 || x > 8 || y < 4 || y > 12) {
            return;
        }
        node.toggle();
    }

    // щелчок по названию: узел выбирается (по ссылке не переходим — это делает двойной щелчок владельца дерева)
    nodeSelectListener(event, node) {
        event.preventDefault();
        event.stopPropagation();
        node.select();
    }
};

/**
 * Узел дерева: li > a (название — ссылка на страницу) и, у папки, ul с вложенными узлами. События узла —
 * addEvent('select', обработчик): обработчик получает узел.
 *
 * @constructor
 * @param {Object|Element} nodeInfo Описание {id, name, data: {segment, icon, class}} или готовый li.
 * @param {TreeView} tree
 */
TreeView.Node = class TreeViewNode {
    constructor(nodeInfo, tree) {
        this.tree = tree;
        this.events = {};
        this.selected = false;
        this.id = null;
        this.data = null;
        if (nodeInfo && nodeInfo.nodeType === 1) {
            this.element = nodeInfo;
            this.element.querySelector('a').setAttribute('href', Energine.base + Energine.lang + '/');
            this.id = this.element.getAttribute('id');
        } else {
            this.element = document.createElement('li');
            const link = document.createElement('a');
            link.setAttribute('href', Energine.base + Energine.lang + '/' + nodeInfo.data.segment);
            link.textContent = nodeInfo.name;
            this.element.appendChild(link);
            this.id = nodeInfo.id;
            this.data = nodeInfo.data;
            this.setIcon(nodeInfo.data.icon);
        }
        this.element.treeNode = this;
        const anchor = this.element.querySelector('a');
        if (nodeInfo.data && nodeInfo.data['class']) {
            anchor.classList.add(...String(nodeInfo.data['class']).split(/\s+/).filter(Boolean));
        }
        this.childs = this.element.querySelector('ul');
        this.opened = this.element.classList.contains('opened');
        this.element.addEventListener('click', (event) => this.tree.nodeToggleListener(event, this));
        if (typeof this.tree.options.dblClick === 'function') {
            anchor.addEventListener('dblclick', this.tree.options.dblClick);
        }
        anchor.addEventListener('click', (event) => this.tree.nodeSelectListener(event, this));
    }

    addEvent(type, handler) {
        (this.events[type] = this.events[type] || []).push(handler);
        return this;
    }

    emit(type) {
        (this.events[type] || []).forEach((handler) => handler.call(this, this));
        return this;
    }

    static of(element) {
        return (element && element.treeNode) || null;
    }

    // вложенный узел — в конец папки (новая папка свёрнута)
    adopt(node) {
        if (!(node instanceof TreeView.Node)) {
            return;
        }
        if (!this.childs) {
            this.childs = document.createElement('ul');
            this.childs.classList.add('hidden');
            this.element.appendChild(this.childs);
        }
        this.childs.appendChild(node.element);
        this.tree.nodes.push(node);
    }

    // этот узел — перед другим, на его уровне
    injectBefore(node) {
        if (!(node instanceof TreeView.Node)) {
            return;
        }
        node.element.before(this.element);
    }

    // этот узел — первым в папку другого узла; папка раскрывается
    injectInside(parentNode) {
        if (!(parentNode instanceof TreeView.Node)) {
            return;
        }
        if (!parentNode.childs) {
            parentNode.childs = document.createElement('ul');
            parentNode.childs.classList.add('hidden');
            parentNode.element.appendChild(parentNode.childs);
        }
        parentNode.childs.prepend(this.element);
        parentNode.expand();
        this.tree.setupCssClasses();
    }

    removeChilds() {
        if (!this.childs) {
            return;
        }
        [...this.childs.children].forEach((child) => {
            if (child.treeNode) {
                child.treeNode.remove();
            }
        });
    }

    getPrevious() {
        return TreeView.Node.of(this.element.previousElementSibling);
    }

    getNext() {
        return TreeView.Node.of(this.element.nextElementSibling);
    }

    // родитель узла: li / ul / li
    static parentOf(node) {
        const list = node.element.parentElement;
        return TreeView.Node.of(list && list.parentElement);
    }

    getParent() {
        return TreeView.Node.parentOf(this);
    }

    getParents() {
        const result = [];
        for (let node = TreeView.Node.parentOf(this); node; node = TreeView.Node.parentOf(node)) {
            result.push(node);
        }
        return result;
    }

    isParentOf(node) {
        return [...this.element.querySelectorAll('li')].some((item) => item.treeNode === node);
    }

    // поменять местами с соседом
    swap(node) {
        if (!(node instanceof TreeView.Node) || this.isParentOf(node) || node.isParentOf(this)) {
            return;
        }
        const next = this.getNext();
        if (next) {
            if (next === node) {
                node.swap(this);
            } else {
                this.injectBefore(node);
                node.injectBefore(next);
            }
        } else {
            // этот узел — последний: он встаёт на место соседа, сосед — в конец
            this.injectBefore(node);
            this.element.parentElement.appendChild(node.element);
        }
        this.tree.setupCssClasses();
    }

    moveUp() {
        this.swap(this.getPrevious());
    }

    moveDown() {
        this.swap(this.getNext());
    }

    // узел уходит со страницы и из списка дерева
    remove() {
        this.removeChilds();
        this.element.remove();
        const index = this.tree.nodes.indexOf(this);
        if (index !== -1) {
            this.tree.nodes.splice(index, 1);
        }
        this.tree.setupCssClasses();
    }

    toggle() {
        if (this.childs && this.childs.childNodes.length) {
            this.element.classList.toggle('opened');
            this.opened = this.element.classList.contains('opened');
            this.childs.classList.toggle('hidden');
        }
    }

    expand() {
        if (!this.opened) {
            this.toggle();
        }
    }

    collapse() {
        if (this.opened) {
            this.toggle();
        }
    }

    // выбор узла; повторный выбор выбранного сообщает о выборе ещё раз — как прежде
    select() {
        if (this === this.tree.selectedNode) {
            this.emit('select');
        }
        if (this.tree.selectedNode) {
            this.tree.selectedNode.unselect();
        }
        this.tree.selectedNode = this;
        this.element.classList.add('selected');
        this.selected = true;
        this.emit('select');
    }

    unselect() {
        this.element.classList.remove('selected');
        this.selected = false;
    }

    getId() {
        return this.id;
    }

    // название — текстом
    setName(name) {
        this.element.querySelector('a').textContent = name;
    }

    setData(data) {
        this.data = data;
    }

    setIcon(icon) {
        const link = this.element.querySelector('a');
        link.style.backgroundImage = 'url(' + icon + ')';
        link.style.backgroundPosition = '1px 1px';
        link.style.backgroundRepeat = 'no-repeat';
    }

    getData() {
        return this.data;
    }
};
