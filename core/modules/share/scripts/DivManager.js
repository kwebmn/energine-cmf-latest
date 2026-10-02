/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[DivManager]{@link DivManager}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @requires TabPane
 * @requires Toolbar
 * @requires ModalBox
 * @requires TreeView
 *
 * @author Pavel Dubenko
 *
 * @version 1.1.0
 */

// TODO: DivManager class is very similar to the TreeView class! I think, one of them must be merged to another and remove the overloaded functionality. - wait for tests

import {Energine} from 'Energine';
import {TabPane} from 'TabPane';
import {ModalBox} from 'ModalBox';
import {TreeView} from 'TreeView';

/**
 * Структура сайта: дерево разделов с панелью — добавить, править, удалить, переставить, выбрать (в окне), перейти на
 * страницу раздела (двойной щелчок).
 *
 * @constructor
 * @param {Element|string} element Элемент компонента (или его id).
 */
export class DivManager {
    constructor(element) {
        /**
         * Toolbar.
         * @type {Toolbar}
         */
        this.toolbar = null;
        this.treeRoot = null;
        this.setup(element);
    }

    /**
     * Настройка: вкладки, дерево в #treeContainer, загрузка разделов; на странице панель подгоняется под окно.
     *
     * @param {Element|string} element
     */
    setup(element) {
        Energine.loadCSS('div.css');
        this.element = DivManager.element(element);
        this.tabPane = new TabPane(this.element);
        this.langId = this.element.getAttribute('lang_id');
        this.tree = new TreeView(DivManager.treeList(), {dblClick: () => this.go()});
        this.singlePath = this.element.getAttribute('single_template');
        this.loadTree();

        /* вешаем пересчет размеров формы на ресайз окна */
        if (!document.querySelector('.e-singlemode-layout')) {
            window.addEventListener('resize', () => this.fitTreeFormSize());
        }
    }

    /**
     * Панель — внизу; «Добавить», «Выбрать», «Закрыть», «Править» включены сразу, остальные — по выбору раздела.
     *
     * @param {Toolbar} toolbar
     */
    attachToolbar(toolbar) {
        const toolbarContainer = this.element.querySelector('.e-pane-b-toolbar');
        this.toolbar = toolbar;
        (toolbarContainer || this.element).appendChild(this.toolbar.element);
        this.toolbar.disableControls();
        ['add', 'select', 'close', 'edit'].forEach((btnID) => {
            const btn = this.toolbar.getControlById(btnID);
            if (btn) {
                btn.enable();
            }
        });
        toolbar.bindTo(this);
    }

    /**
     * Адрес данных дерева.
     *
     * @returns {string}
     */
    treeDataURL() {
        return this.singlePath + 'get-data/';
    }

    /**
     * Загрузить разделы и построить дерево; на странице панель подгоняется под окно и прокручивается в видимую часть.
     */
    loadTree() {
        Energine.request(
            this.treeDataURL(),
            'languageID=' + this.langId,
            (response) => {
                this.buildTree(response.data, (response.current) ? response.current : null);
                /* растягиваем всю форму до высоты видимого окна */
                if (!document.querySelector('.e-singlemode-layout')) {
                    this.pane = this.element;
                    this.paneContent = this.pane.querySelector('.e-pane-item');
                    this.treeContainer = this.pane.querySelector('.e-divtree-select');
                    this.minPaneHeight = 300;
                    this.fitTreeFormSize();
                    this.pane.scrollIntoView({block: 'start'});
                }
            }
        );
    }

    /**
     * Дерево из списка разделов (родитель — smap_pid); пустой список — пустое дерево.
     *
     * @param {Object[]} nodes
     * @param {number|string} currentNodeID
     */
    buildTree(nodes, currentNodeID) {
        const treeInfo = {};
        (nodes || []).forEach((node) => {
            const pid = node['smap_pid'] || 'treeRoot';
            (treeInfo[pid] = treeInfo[pid] || []).push(node);
        });

        const lambda = (nodeId, parentNode) => {
            (treeInfo[nodeId] || []).forEach((child) => {
                const icon = (child['tmpl_icon'])
                        ? Energine.base + child['tmpl_icon']
                        : Energine.base + 'templates/icons/empty.icon.gif',
                    childId = child['smap_id'];
                const newNode = new TreeView.Node({
                    id: childId,
                    name: child['smap_name'],
                    data: {
                        'segment': child['smap_segment'],
                        'class': ((childId == currentNodeID) ? ' current' : ''),
                        'icon': icon
                    }
                }, this.tree);
                newNode.setData(child);
                newNode.on('select', (node) => this.onSelectNode(node));
                parentNode.appendNode(newNode);
                if (treeInfo[childId]) {
                    lambda(childId, newNode);
                }
            });
        };

        lambda('treeRoot', this.tree);
        this.showCurrent(currentNodeID);
    }

    /**
     * Текущий раздел выбран и раскрыт, иначе раскрыты все.
     *
     * @param {number|string} currentNodeID
     */
    showCurrent(currentNodeID) {
        this.tree.setupCssClasses();
        this.tree.expandToNode(currentNodeID);
        const current = this.tree.getNodeById(currentNodeID);
        if (current) {
            current.select();
            current.expand();
        } else {
            this.tree.expandAllNodes();
        }
    }

    /**
     * Панель на странице — по дереву, но не выше окна (и не ниже 300px).
     */
    fitTreeFormSize() {
        if (!this.pane) {
            return;
        }
        const windowHeight = document.documentElement.clientHeight - 10,
            treeContainerHeight = this.treeContainer.getBoundingClientRect().height,
            paneOthersHeight = this.pane.getBoundingClientRect().height - this.paneContent.getBoundingClientRect().height + 22;

        if (windowHeight > this.minPaneHeight) {
            const treePane = treeContainerHeight + paneOthersHeight;
            this.pane.style.height = Math.round((treePane > windowHeight) ? windowHeight : treePane) + 'px';
        } else {
            this.pane.style.height = this.minPaneHeight + 'px';
        }
    }

    reload() {
        this.tree.empty();
        this.loadTree();
    }

    // Actions:

    /**
     * Окно добавления раздела в выбранный; ответ окна: add — ещё раз, go — переход на новую страницу, иначе — дерево
     * заново.
     */
    add() {
        const nodeId = this.tree.getSelectedNode().getId();
        ModalBox.open({
            url: this.singlePath + 'add/' + nodeId + '/',
            onClose: (returnValue) => {
                if (returnValue) {
                    switch (returnValue.afterClose) {
                        case 'add':
                            this.add();
                            break;
                        case 'go':
                            window.top.location.href = Energine.base + returnValue.url;
                            break;
                        default:
                            this.reload();
                    }
                }
            },
            extraData: this.tree.getSelectedNode()
        });
    }

    /**
     * Окно правки раздела; после него — имя и место узла с сервера.
     */
    edit() {
        const nodeId = this.tree.getSelectedNode().getId();
        ModalBox.open({
            url: this.singlePath + nodeId + '/edit',
            onClose: () => this.refreshNode(),
            extraData: this.tree.getSelectedNode()
        });
    }

    del() {
        const MSG_CONFIRM_DELETE = Energine.translations.get('MSG_CONFIRM_DELETE') ||
            'Do you really want to delete record?';
        if (!confirm(MSG_CONFIRM_DELETE)) {
            return;
        }
        const nodeId = this.tree.getSelectedNode().getId();
        Energine.request(this.singlePath + nodeId + '/delete/', '', () => this.reload());
    }

    /**
     * Ответ на «вверх»/«вниз»: узел переставляется по направлению из ответа.
     *
     * @param {Object} response {result, dir}
     */
    changeOrder(response) {
        if (!response.result) {
            return;
        }
        this.tree.getSelectedNode()[(response.dir == '<') ? 'moveUp' : 'moveDown']();
    }

    up() {
        const nodeId = this.tree.getSelectedNode().getId();
        Energine.request(this.singlePath + nodeId + '/up', '', (response) => this.changeOrder(response));
    }

    down() {
        const nodeId = this.tree.getSelectedNode().getId();
        Energine.request(this.singlePath + nodeId + '/down', '', (response) => this.changeOrder(response));
    }

    select() {
        ModalBox.setReturnValue(this.tree.getSelectedNode().getData());
        ModalBox.close();
    }

    close() {
        ModalBox.close();
    }

    /**
     * Перейти на страницу выбранного раздела — в верхнем окне.
     */
    go() {
        const nodeData = this.tree.getSelectedNode().getData();
        if (nodeData.smap_segment || !nodeData.smap_pid) {
            window.top.document.location = Energine.base + nodeData.smap_segment;
        }
    }

    // End actions

    /**
     * Выбран раздел: у раздела включены все кнопки, у корня — только «Закрыть», «Добавить», «Править», «Выбрать».
     *
     * @param {TreeView.Node} node
     */
    onSelectNode(node) {
        if (!this.toolbar) {
            return;
        }
        const data = node.getData(),
            buttons = [this.toolbar.getControlById('close')];
        if ((data != undefined) && data.smap_pid) {
            this.toolbar.enableControls();
        } else {
            this.toolbar.disableControls();
            buttons.push(
                this.toolbar.getControlById('add'),
                this.toolbar.getControlById('edit'),
                this.toolbar.getControlById('select')
            );
        }
        buttons.forEach((btn) => {
            if (btn) {
                btn.enable();
            }
        });
    }

    /**
     * Имя и место выбранного узла — с сервера (после окна правки).
     */
    refreshNode() {
        const nodeId = this.tree.getSelectedNode().getId();
        Energine.request(
            this.singlePath + 'get-node-data',
            'languageID=' + this.langId + '&id=' + nodeId,
            (response) => {
                if (response.data.smap_pid == null) {
                    response.data.smap_pid = '';
                }
                const smapPid = response.data.smap_pid,
                    currentNode = this.tree.getSelectedNode();
                if (smapPid != currentNode.getData().smap_pid) {
                    const parentNode = (smapPid) ? this.tree.getNodeById(smapPid) : this.treeRoot;
                    this.tree.expandToNode(parentNode);
                    currentNode.injectInside(parentNode);
                }
                // сервер отдаёт только имя, родителя и порядок — остальные данные узла (сегмент и др.) остаются
                currentNode.setData(Object.assign({}, currentNode.getData(), response.data));
                currentNode.setName(response.data.smap_name);
            }
        );
    }

    /**
     * Элемент по id или сам элемент.
     *
     * @param {Element|string} element
     * @returns {Element}
     */
    static element(element) {
        return (typeof element === 'string') ? document.getElementById(element) : element;
    }

    /**
     * Список дерева (ul#divTree.treeview) в #treeContainer.
     *
     * @returns {Element}
     */
    static treeList() {
        const list = document.createElement('ul');
        list.id = 'divTree';
        list.classList.add('treeview');
        document.getElementById('treeContainer').appendChild(list);
        return list;
    }
};
