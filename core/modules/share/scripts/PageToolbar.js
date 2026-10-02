/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[PageToolbar]{@link PageToolbar}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @requires Toolbar
 * @requires ModalBox
 *
 * @author Pavel Dubenko
 *
 * @version 1.1.0
 */

import {Energine} from 'Energine';
import {Toolbar} from 'Toolbar';
import {ModalBox} from 'ModalBox';

/**
 * Панель страницы у администратора на сайте: прикреплена сверху, страница — в основной рамке, сбоку — панель разделов
 * (iframe). Действия кнопок — методы панели: режим правки и окна админки.
 *
 * @constructor
 * @param {string} componentPath Адрес компонента панели (…/single/adminPanel/).
 * @param {number} documentId id страницы.
 * @param {string} toolbarName
 * @param {Object[]} [controlsDesc] Описания кнопок {type, id, title, onclick, …}.
 * @param {Object} [props] Свойства панели (noSideFrame — без боковой панели).
 */
export class PageToolbar extends Toolbar {
    constructor(componentPath, documentId, toolbarName, controlsDesc, props) {
        super(toolbarName, props);
        Energine.loadCSS('pagetoolbar.css');
        this.componentPath = componentPath;
        this.documentId = documentId;
        this.dock();
        this.bindTo(this);
        if (controlsDesc) {
            controlsDesc.forEach((control) => this.appendControl(control));
        }
        this.setupLayout();
    }

    // верхняя рамка с панелью и значком, основная рамка со страницей, боковая панель
    setupLayout() {
        const html = document.documentElement;
        html.classList.add('e-has-topframe1');

        // содержимое страницы, кроме затемнений, переходит в основную рамку
        const currentBody = [...document.body.children]
            .filter((element) => element.tagName.toLowerCase() === 'svg' || !element.classList.contains('e-overlay'));
        const mainFrame = document.createElement('div');
        mainFrame.className = 'e-mainframe';
        const topFrame = document.createElement('div');
        topFrame.className = 'e-topframe';
        document.body.append(topFrame, mainFrame);
        mainFrame.append(...currentBody);
        topFrame.appendChild(this.element);

        const gear = document.createElement('img');
        gear.src = Energine['static'] + (Energine.debug ? 'images/toolbar/nrgnptbdbg.png' : 'images/toolbar/nrgnptb.png');
        gear.className = 'pagetb_logo';
        topFrame.prepend(gear);

        if (!this.properties.noSideFrame) {
            if (Energine.readCookie('sidebar') == 1) {
                html.classList.add('e-has-sideframe');
            }
            const sidebarFrame = document.createElement('div');
            sidebarFrame.className = 'e-sideframe';
            const sidebarFrameContent = document.createElement('div');
            sidebarFrameContent.className = 'e-sideframe-content';
            const sidebarFrameBorder = document.createElement('div');
            sidebarFrameBorder.className = 'e-sideframe-border';
            document.body.appendChild(sidebarFrame);
            sidebarFrame.append(sidebarFrameContent, sidebarFrameBorder);
            const iframe = document.createElement('iframe');
            iframe.src = this.componentPath + 'show/';
            iframe.frameBorder = '0';
            sidebarFrameContent.appendChild(iframe);
            gear.addEventListener('click', () => this.toggleSidebar());
        }
    }

    // Действия кнопок

    // режим правки: включить — страница приходит заново формой (editMode=1), выключить — перезагрузкой
    editMode() {
        const control = this.getControlById('editMode');
        if (control && control.getState() == 0) {
            this._reloadWindowInEditMode();
        } else {
            window.location = window.location;
        }
    }

    add() {
        ModalBox.open({url: this.componentPath + 'add/' + this.documentId});
    }

    edit() {
        ModalBox.open({url: this.componentPath + this.documentId + '/edit'});
    }

    // боковая панель: открыть или закрыть и запомнить это в cookie на 30 дней (домен — главного сайта, если адрес
    // сайта на нём)
    toggleSidebar() {
        const html = document.documentElement;
        html.classList.toggle('e-has-sideframe');
        const base = new URL(Energine.base, document.baseURI);
        const root = new URL(Energine.root || Energine.base, document.baseURI);
        const url = base.hostname.includes(root.hostname) ? root : base;
        Energine.writeCookie('sidebar', html.classList.contains('e-has-sideframe') ? 1 : 0,
            {domain: '.' + url.hostname, path: url.pathname.replace(/[^/]*$/, ''), days: 30});
    }

    showTmplEditor() {
        ModalBox.open({url: this.componentPath + 'template'});
    }

    showTransEditor() {
        ModalBox.open({url: this.componentPath + 'translation'});
    }

    showUserEditor() {
        ModalBox.open({url: this.componentPath + 'user'});
    }

    showRoleEditor() {
        ModalBox.open({url: this.componentPath + 'role'});
    }

    showLangEditor() {
        ModalBox.open({url: this.componentPath + 'languages'});
    }

    showFileRepository() {
        ModalBox.open({url: this.componentPath + 'file-library'});
    }

    showSiteSettings() {
        ModalBox.open({url: this.componentPath + 'site-settings/'});
    }

    // вход в режим правки: та же страница формой POST editMode=1 с токеном
    _reloadWindowInEditMode() {
        const form = document.createElement('form');
        form.style.display = 'none';
        form.action = '';
        form.method = 'post';
        const input = document.createElement('input');
        input.type = 'hidden';
        input.name = 'editMode';
        input.value = '1';
        form.append(input, Energine.csrfInput());
        document.body.appendChild(form);
        form.submit();
    }
};
