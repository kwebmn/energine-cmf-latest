/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[getDirsTree]{@link getDirsTree}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @requires DivManager
 *
 * @author Pavel Dubenko
 *
 * @version 1.1.0
 */

import {Energine} from 'Energine';
import {DivManager} from 'DivManager';
import {TreeView} from 'TreeView';

/**
 * Окно выбора папки для переноса файла или папки: хранилища и папки репозитория без переносимой папки и её
 * содержимого; выбор включает «Перенести».
 *
 * @augments DivManager
 *
 * @constructor
 * @param {Element|string} element The main holder element.
 */
export class getDirsTree extends DivManager {
    treeDataURL() {
        return this.singlePath + '/getDirs/';
    }

    /**
     * Дерево папок (родитель — upl_pid) без переносимой (move_id у #treeContainer) и её содержимого.
     *
     * @param {Object[]} nodes
     * @param {number|string} currentNodeID
     */
    buildTree(nodes, currentNodeID) {
        const treeInfo = {},
            moveFromId = document.getElementById('treeContainer').getAttribute('move_id');
        (nodes || []).forEach((node) => {
            if (node['upl_id'] == moveFromId) {
                return;
            }
            const pid = node['upl_pid'] || 'treeRoot';
            if (pid == moveFromId) {
                return;
            }
            (treeInfo[pid] = treeInfo[pid] || []).push(node);
        });

        const lambda = (nodeId, parentNode) => {
            (treeInfo[nodeId] || []).forEach((child) => {
                const icon = (child['tmpl_icon'])
                        ? Energine.base + child['tmpl_icon']
                        : Energine.base + 'templates/icons/divisions_list.icon.gif',
                    childId = child['upl_id'];
                const newNode = new TreeView.Node({
                    id: childId,
                    name: child['upl_title'],
                    data: {
                        'segment': child['upl_segment'],
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

    onSelectNode() {
        const btnSelect = this.toolbar.getControlById('saveDirsMove');
        if (btnSelect) {
            btnSelect.enable();
        }
    }

    // двойной щелчок ничего не делает
    go() {
    }

    /**
     * Перенести в выбранную папку; окно закрывается.
     */
    saveDirsMove() {
        const moveToId = this.tree.getSelectedNode().getId(),
            moveFromId = document.getElementById('treeContainer').getAttribute('move_id');
        Energine.request(
            this.singlePath + moveFromId + ',' + moveToId + '/getDirsMove/',
            'languageID=' + this.langId,
            () => this.close()
        );
    }
};
