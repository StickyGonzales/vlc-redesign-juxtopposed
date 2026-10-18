/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
// redesign: Settings > Extensions ("Extensions & Scripts", video 18:26-18:47, Figma "Settings - extensions"); rows: P8-18, P8-19, P8-20.
// The list holds VLC's add-ons, everything installable (extensions, skins, playlist parsers,
// service discovery, interfaces, art fetchers), from VLC's add-ons manager (AddonsModel, the
// model of the old "Addons Manager" tab): the installed ones, or VLC's online catalog after
// "Find more extensions" (the button then reads "Show installed"). "Add" installs the selected
// add-on of the catalog; with none selected it reads an add-on package (.vlp) from the computer,
// as the old dialog did with a dropped package (also accepted here), whose add-ons can then be
// installed. VLC's plugins (internal functions, not meant to be edited by users) move
// under Advanced Options. Wording: the video's (Decision 11; Figma says "Add-ons").
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Dialogs
import VLC.Network

SettingsPage {
    id: root

    // false: the installed add-ons; true: VLC's online catalog (and read packages) as well
    property bool _catalog: false
    // a repository or a package is being read
    property bool _gathering: false
    // a message about the last package the user tried to add
    property string _notice: ""
    // the list has its count for the current search (the model resets on every keystroke)
    property bool _countKnown: true

    // the selection follows its add-on when the list reloads (rows move, states change)
    property int _selectedRow: -1
    property string _selectedKey: ""
    // the roles of the selected add-on (name, state, manageable, ...)
    property var _selected: null

    // add-ons whose install was asked for and has not started yet (VLC's installer queue):
    // asking again would remove them once installed
    property var _installRequested: ({})

    readonly property bool _installPending: !!_selected && !!_installRequested[_selectedKey]
    // VLC's installer has no installer for these kinds (addons_manager: EINVAL): Add would do
    // nothing and stay usable
    // Cone has no skins interface (Decision 63): a skin add-on would install for nothing
    readonly property bool _unsupportedType: !!_selected
                                             && ([ServicesDiscoveryModel.TYPE_UNKNOWN, ServicesDiscoveryModel.TYPE_PLUGIN,
                                                  ServicesDiscoveryModel.TYPE_OTHER].map(Number).indexOf(Number(_selected.type)) >= 0
                                                 || (Brand.isPublic && Number(_selected.type) === Number(ServicesDiscoveryModel.TYPE_SKIN2)))
    readonly property bool _canInstall: !!_selected && _selected.state === ServicesDiscoveryModel.STATE_NOTINSTALLED
                                        && !_installPending && !_unsupportedType
    readonly property bool _canRemove: !!_selected && _selected.state === ServicesDiscoveryModel.STATE_INSTALLED
                                       && !!_selected.manageable

    readonly property string _emptyText: {
        if (_gathering)
            return qsTr("Looking for add-ons...")
        if (_notice !== "")
            return _notice
        if (addons.loading || !_countKnown)
            return ""
        if (searchField.text !== "")
            return qsTr("No add-on matches \"%1\"").arg(searchField.text)
        // public profile (brand layer): the catalog is VideoLAN's, named without VLC's name
        if (_catalog)
            return Brand.isPublic ? qsTr("No add-ons found. The online add-on catalog needs an internet connection.")
                                  : qsTr("No add-ons found. VLC's add-on catalog needs an internet connection.")
        return Brand.isPublic ? qsTr("No add-ons installed. Find more extensions to browse the online add-on catalog.")
                              : qsTr("No add-ons installed. Find more extensions to browse VLC's add-on catalog.")
    }

    function _keyOf(data) {
        return [data.name, data.version, data.type].join("\n")
    }

    function _select(row) {
        if (row < 0 || row >= addons.count) {
            _clearSelection()
            return
        }
        _selectedRow = row
        _selected = addons.getDataAt(row)
        // a row not loaded yet (the list loads 100 at a time) gets its key once it is
        _selectedKey = _selected.name === undefined ? "" : _keyOf(_selected)
        list.positionViewAtIndex(row, ListView.Contain)
    }

    function _clearSelection() {
        _selectedRow = -1
        _selectedKey = ""
        _selected = null
    }

    function _forgetStartedInstalls() {
        const pending = Object.keys(_installRequested)
        if (pending.length === 0)
            return
        const left = {}
        for (const key of pending) {
            for (let i = 0; i < addons.count; ++i) {
                const data = addons.getDataAt(i)
                if (_keyOf(data) === key) {
                    if (data.state === ServicesDiscoveryModel.STATE_NOTINSTALLED)
                        left[key] = true
                    break
                }
            }
        }
        _installRequested = left
    }

    function _refreshSelection() {
        _forgetStartedInstalls()
        if (_selectedKey === "") {
            if (_selectedRow >= 0 && _selectedRow < addons.count) {
                _selected = addons.getDataAt(_selectedRow)
                if (_selected.name !== undefined)
                    _selectedKey = _keyOf(_selected)
            }
            return
        }
        let row = _selectedRow
        if (row < 0 || row >= addons.count || _keyOf(addons.getDataAt(row)) !== _selectedKey) {
            row = -1
            for (let i = 0; i < addons.count; ++i) {
                if (_keyOf(addons.getDataAt(i)) === _selectedKey) {
                    row = i
                    break
                }
            }
        }
        if (row < 0) {
            _clearSelection()
            return
        }
        _selectedRow = row
        _selected = addons.getDataAt(row)
    }

    function _showCatalog(show) {
        _notice = ""
        _catalog = show
        // fetched each time: a catalog that failed (offline) can be fetched again, and VLC
        // merges what it already has
        if (!show || _gathering)
            return
        _gathering = true
        addons.loadFromDefaultRepository()
    }

    function _loadPackage(url) {
        _notice = ""
        _catalog = true
        _gathering = true
        addons.loadFromExternalRepository(url)
    }

    // an add-on package (.vlp) from the computer: VLC's add-ons manager reads it as a repository
    function _addPackage() {
        _notice = ""
        const path = SettingsCatalog.pickFile(qsTr("Add an add-on package (.vlp)"), "", false,
                                              Brand.isPublic ? qsTr("Add-on packages (*.vlp)")
                                                             : qsTr("VLC add-on packages (*.vlp)"))
        if (path === "")
            return
        if (!_isPackageName(path))
            return
        _loadPackage(_fileUrl(path))
    }

    // VLC reads a package only when its name ends in ".vlp", in lower case (vorepository.c)
    function _isPackageName(path) {
        if (/\.vlp$/.test(path))
            return true
        _notice = /\.vlp$/i.test(path)
                ? qsTr("%1 reads add-on packages whose name ends in \".vlp\" in lower case: rename \"%2\".").arg(Brand.shortName).arg(path)
                : (Brand.isPublic ? qsTr("\"%1\" is not an add-on package (.vlp).")
                                  : qsTr("\"%1\" is not a VLC add-on package (.vlp).")).arg(path)
        return false
    }

    function _fileUrl(path) {
        const encoded = path.replace(/\\/g, "/").split("/")
                            .map((part) => encodeURIComponent(part).replace(/%3A/gi, ":"))
                            .join("/")
        return (encoded.startsWith("/") ? "file://" : "file:///") + encoded
    }

    function _detail(type, version, author, state, manageable) {
        const parts = [addons.getLabelForType(type)]
        if (version)
            parts.push(version)
        if (author)
            parts.push(qsTr("by %1").arg(author))
        switch (state) {
        case ServicesDiscoveryModel.STATE_INSTALLING:
            parts.push(qsTr("Installing..."))
            break
        case ServicesDiscoveryModel.STATE_UNINSTALLING:
            parts.push(qsTr("Removing..."))
            break
        case ServicesDiscoveryModel.STATE_INSTALLED:
            if (!manageable)
                parts.push(qsTr("installed manually"))
            else if (_catalog)
                parts.push(qsTr("Installed"))
            break
        }
        return parts.join(" · ")
    }

    ServicesDiscoveryModel {
        id: addons

        ctx: MainCtx
        stateFilter: root._catalog ? ServicesDiscoveryModel.STATE_NONE : ServicesDiscoveryModel.STATE_INSTALLED
        searchPattern: searchField.text

        // every state change of an add-on reloads the list (a lost row update included)
        onLoadingChanged: {
            if (!loading)
                root._gathering = false
            root._refreshSelection()
        }
        onCountChanged: {
            root._countKnown = true
            root._refreshSelection()
        }
        onSearchPatternChanged: root._countKnown = false
    }

    // install and remove progress changes the rows in place
    Connections {
        target: addons

        function onDataChanged() {
            root._refreshSelection()
        }
    }

    SettingsSection {
        title: qsTr("Extensions")
        keywords: qsTr("add-ons addons extensions skins scripts playlist parsers service discovery interfaces art fetchers install remove")

        // Figma "Frame 86": 194 high, BG/B2, 2 px BG/A4 stroke, radius 6, padding 12,8
        Rectangle {
            id: box

            Layout.fillWidth: true
            Layout.preferredHeight: VLCStyle.dp(194)
            radius: VLCStyle.rd_radius_normal
            color: VLCStyle.palette.rdBgB2
            border.width: VLCStyle.dp(2)
            // accent only for keyboard focus, like the Rd text fields
            border.color: (list.activeFocus && !list.byMouse) ? VLCStyle.palette.rdAccentMain
                                                               : VLCStyle.palette.rdBgA4

            ListView {
                id: list

                // focus came from a click on a row: no keyboard focus frame
                property bool byMouse: false

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: statusText.visible ? statusText.top : parent.bottom
                anchors.leftMargin: VLCStyle.dp(8)
                anchors.rightMargin: VLCStyle.dp(8)
                anchors.topMargin: VLCStyle.dp(6)
                anchors.bottomMargin: VLCStyle.dp(6)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                activeFocusOnTab: true
                keyNavigationEnabled: false

                model: addons

                Accessible.role: Accessible.List
                Accessible.name: qsTr("Extensions")

                T.ScrollBar.vertical: Widgets.ScrollBarExt {
                    colorContext.palette: VLCStyle.palette
                }

                onActiveFocusChanged: {
                    if (!activeFocus)
                        byMouse = false
                }

                // arrows move the selection; Enter or Space selects the first add-on
                Keys.onPressed: (event) => {
                    let row = root._selectedRow
                    const page = Math.max(1, Math.floor(height / VLCStyle.rd_rowHeight) - 1)
                    switch (event.key) {
                    case Qt.Key_Up: row = row < 0 ? 0 : row - 1; break
                    case Qt.Key_Down: row = row + 1; break
                    case Qt.Key_PageUp: row = row - page; break
                    case Qt.Key_PageDown: row = row < 0 ? page : row + page; break
                    case Qt.Key_Home: row = 0; break
                    case Qt.Key_End: row = count - 1; break
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                    case Qt.Key_Space: row = Math.max(0, row); break
                    default: return
                    }
                    event.accepted = true
                    byMouse = false
                    if (count > 0)
                        root._select(Math.max(0, Math.min(count - 1, row)))
                }

                delegate: Widgets.RdListRow {
                    id: row

                    required property int index
                    required property var model

                    detail: root._detail(model.type, model.version, model.author, model.state, !!model.manageable)

                    width: ListView.view.width
                    focusPolicy: Qt.NoFocus
                    title: model.name ?? ""
                    selected: index === root._selectedRow
                    Accessible.description: [detail, model.summary ?? ""].filter((t) => t !== "").join(". ")

                    onClicked: {
                        list.byMouse = true
                        list.forceActiveFocus(Qt.MouseFocusReason)
                        root._select(index)
                    }

                    contentItem: RowLayout {
                        spacing: VLCStyle.dp(10)

                        Text {
                            Layout.fillWidth: true
                            Layout.leftMargin: VLCStyle.dp(4)
                            text: row.title
                            elide: Text.ElideRight
                            font.family: VLCStyle.rd_fontFamily
                            font.pixelSize: VLCStyle.rd_fontSize_label
                            color: (row.selected || row.hovered) ? row.rdPalette.rdFg2 : row.rdPalette.rdFgA1
                        }

                        Text {
                            Layout.maximumWidth: Math.round(row.width / 2)
                            Layout.rightMargin: VLCStyle.dp(4)
                            text: row.detail
                            elide: Text.ElideRight
                            font.family: VLCStyle.rd_fontFamily
                            font.pixelSize: VLCStyle.rd_fontSize_label
                            color: row.rdPalette.rdFgA3
                        }
                    }
                }
            }

            // reading the catalog or a package while add-ons are listed, or a message
            Text {
                id: statusText

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: VLCStyle.dp(12)
                anchors.rightMargin: VLCStyle.dp(12)
                anchors.bottomMargin: VLCStyle.dp(8)
                visible: list.count > 0 && text !== ""
                text: root._notice !== "" ? root._notice : (root._gathering ? qsTr("Looking for add-ons...") : "")
                elide: Text.ElideRight
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_toggle
                color: VLCStyle.palette.rdFgA4
            }

            Text {
                anchors.centerIn: parent
                width: parent.width - 2 * VLCStyle.dp(24)
                visible: list.count === 0
                text: root._emptyText
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_label
                color: VLCStyle.palette.rdFgA3
            }

            // a package dropped on the list, as in the old Addons Manager
            DropArea {
                anchors.fill: parent

                onEntered: (drag) => {
                    drag.accepted = !root._gathering && drag.hasUrls && drag.urls.length === 1
                                    && /^file:.*\.vlp$/i.test(String(drag.urls[0]))
                }
                onDropped: (drop) => {
                    drop.accept(Qt.CopyAction)
                    root._notice = ""
                    if (root._isPackageName(decodeURIComponent(String(drop.urls[0]))))
                        root._loadPackage(drop.urls[0])
                }
            }
        }

        // Figma "Frame 156": search field 210x36 on the left, buttons 185 / 100 / 100 on the right
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: VLCStyle.dp(6)
            Layout.bottomMargin: VLCStyle.dp(11)
            spacing: VLCStyle.dp(10)

            Widgets.RdTextField {
                id: searchField

                Layout.preferredWidth: VLCStyle.dp(210)
                Layout.minimumWidth: VLCStyle.dp(120)
                Layout.preferredHeight: VLCStyle.dp(36)
                placeholderText: qsTr("Search")
                Accessible.name: qsTr("Search add-ons")
            }

            Item {
                Layout.fillWidth: true
            }

            Widgets.RdButton {
                style: Widgets.RdButton.Style.Plain
                leftPadding: VLCStyle.dp(20)
                rightPadding: VLCStyle.dp(20)
                text: root._catalog ? qsTr("Show installed") : qsTr("Find more extensions")
                enabled: root._catalog || !root._gathering
                Accessible.description: root._catalog ? qsTr("List the installed add-ons only")
                                                      : Brand.isPublic ? qsTr("Browse the online add-on catalog")
                                                                       : qsTr("Browse VLC's online add-on catalog")
                onClicked: root._showCatalog(!root._catalog)
            }

            Widgets.RdButton {
                style: Widgets.RdButton.Style.Plain
                text: qsTr("Add")
                enabled: !root._installPending && (root._canInstall || !root._gathering)
                Accessible.description: root._canInstall ? qsTr("Install \"%1\"").arg(root._selected.name)
                                                         : qsTr("Add an add-on package (.vlp) from this computer")
                onClicked: {
                    if (root._installPending)
                        return
                    if (root._unsupportedType && root._selected.state === ServicesDiscoveryModel.STATE_NOTINSTALLED) {
                        root._notice = qsTr("%1 cannot install \"%2\": it has no installer for this kind of add-on.").arg(Brand.shortName)
                                           .arg(root._selected.name)
                        return
                    }
                    if (!root._canInstall) {
                        root._addPackage()
                        return
                    }
                    // VLC's install request removes an add-on that is installed or being
                    // installed: act on the live state of the row, not the remembered one
                    const live = addons.getDataAt(root._selectedRow)
                    if (root._keyOf(live) === root._selectedKey
                            && live.state === ServicesDiscoveryModel.STATE_NOTINSTALLED) {
                        const requested = Object.assign({}, root._installRequested)
                        requested[root._selectedKey] = true
                        root._installRequested = requested
                        addons.installService(root._selectedRow)
                    }
                    root._refreshSelection()
                }
            }

            Widgets.RdButton {
                style: Widgets.RdButton.Style.Plain
                text: qsTr("Remove")
                enabled: root._canRemove
                Accessible.description: root._canRemove ? qsTr("Uninstall \"%1\"").arg(root._selected.name) : ""
                onClicked: {
                    const name = root._selected.name
                    if (!DialogsProvider.questionDialog(qsTr("Remove \"%1\"?").arg(name), qsTr("Remove add-on")))
                        return
                    // the list may have changed while the question was open
                    root._refreshSelection()
                    if (root._canRemove && root._selected.name === name)
                        addons.removeService(root._selectedRow)
                }
            }
        }

        SettingsOption {
            option: "qt-autoload-extensions"
            text: qsTr("Load extensions on startup")
        }
    }

    advanced: [
        SettingsPluginList { },

        SettingsMoreOptions {
            category: "extensions"
        }
    ]
}
