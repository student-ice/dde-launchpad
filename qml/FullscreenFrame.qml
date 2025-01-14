// SPDX-FileCopyrightText: 2023 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

//import QtCore
import QtQml.Models 2.15
import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.15
import org.deepin.dtk 1.0
import org.deepin.dtk.style 1.0 as DS

import org.deepin.launchpad 1.0
import org.deepin.launchpad.models 1.0

Control {
    id: baseLayer
    visible: true
    anchors.fill: parent
    focus: true
    objectName: "FullscreenFrame-BaseLayer"

    // leftPadding: (DesktopIntegration.dockPosition === Qt.LeftArrow ? DesktopIntegration.dockGeometry.width : 0)
    // rightPadding: (DesktopIntegration.dockPosition === Qt.RightArrow ? DesktopIntegration.dockGeometry.width : 0)
    // topPadding: (DesktopIntegration.dockPosition === Qt.UpArrow ? DesktopIntegration.dockGeometry.height : 0) + 20
    // bottomPadding: (DesktopIntegration.dockPosition === Qt.UpArrow ? DesktopIntegration.dockGeometry.height : 0) + 20
    bottomPadding: 20

    property Palette textColor: appTextColor
    palette.windowText: ColorSelector.textColor

    // ----------- Drag and Drop related functions START -----------
    Label {
        property string currentlyDraggedId

        id: dndItem
        visible: DebugHelper.qtDebugEnabled
        text: "DnD DEBUG"

        Drag.onActiveChanged: {
            if (Drag.active) {
                text = "Dragging " + currentlyDraggedId
            } else {
                currentlyDraggedId = ""
            }
        }
    }

    function dropOnItem(dragId, dropId, op) {
        dndItem.text = "drag " + dragId + " onto " + dropId + " with " + op
        MultipageProxyModel.commitDndOperation(dragId, dropId, op)
    }

    function dropOnPage(dragId, dropFolderId, pageNumber) {
        dndItem.text = "drag " + dragId + " into " + dropFolderId + " at page " + pageNumber
        MultipageProxyModel.commitDndOperation(dragId, dropFolderId, MultipageProxyModel.DndJoin, pageNumber)
    }
    // ----------- Drag and Drop related functions  END  -----------

    Timer {
        id: flipPageDelay
        interval: 400
        repeat: false
    }

    background: Image {
        source: DesktopIntegration.backgroundUrl

        Rectangle {
            anchors.fill: parent
            color: folderGridViewPopup.visible ? Qt.rgba(0, 0, 0, 0.6) : Qt.rgba(0, 0, 0, 0.5)

            MouseArea {
                anchors.fill: parent
                scrollGestureEnabled: false
                onClicked: {
                    if (!DebugHelper.avoidHideWindow) {
                        LauncherController.visible = false
                    }
                }
                // TODO: this might not be the correct way to handle wheel
                onWheel: {
                    if (flipPageDelay.running) return
                    let xDelta = wheel.angleDelta.x / 8
                    let yDelta = wheel.angleDelta.y / 8
                    let toPage = 0; // -1 prev, +1 next, 0 don't change
                    if (yDelta !== 0) {
                        toPage = (yDelta > 0) ? -1 : 1
                    } else if (xDelta !== 0) {
                        toPage = (xDelta > 0) ? 1 : -1
                    }
                    if (toPage < 0) {
                        flipPageDelay.start()
                        if (!searchEdit.focus) { // reset keyboard focus when using mouse to flip page, but keep searchEdit focus
                            baseLayer.focus = true
                        }
                        pages.decrementCurrentIndex()
                    } else if (toPage > 0) {
                        flipPageDelay.start()
                        if (!searchEdit.focus) { // reset keyboard focus when using mouse to flip page, but keep searchEdit focus
                            baseLayer.focus = true
                        }
                        pages.incrementCurrentIndex()
                    }
                }
            }
        }
    }

    contentItem: ColumnLayout {

        Control {
            Layout.fillWidth: true
            Layout.fillHeight: false

            leftPadding: 20
            rightPadding: 20
            topPadding: 10

            contentItem: Rectangle {
                id: fullscreenHeader
                implicitHeight: exitFullscreenBtn.height
                color: "transparent"

                ToolButton {
                    id: exitFullscreenBtn

                    visible: (DesktopIntegration.environmentVariable("DDE_CURRENT_COMPOSITOR") !== "TreeLand")

                    Accessible.name: "Exit fullscreen"

                    anchors.right: fullscreenHeader.right

                    ColorSelector.family: Palette.CrystalColor

                    icon.name: "launcher_exit_fullscreen"
                    onClicked: {
                        LauncherController.currentFrame = "WindowedFrame"
                    }
                }

                PageIndicator {
                    id: indicator

                    anchors.horizontalCenter: parent.horizontalCenter
        //            visible: pages.visible
                    count: searchResultGridViewContainer.visible ? 1 : pages.count
                    currentIndex: searchResultGridViewContainer.visible ? 1 : pages.currentIndex
                    interactive: true
                    delegate: Rectangle {
                        width: DS.Style.pageIndicator.width
                        height: width

                        radius: width / 2
                        color: indicator.enabled ? "white" : "gray"

                        opacity: index === indicator.currentIndex ? 1 : pressed ? 0.7 : 0.40

                        OutsideBoxBorder {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Qt.rgba(0, 0, 0, 0.2)
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            DropArea {
                property int pageIntent: 0
                property int horizontalPadding: searchResultGridViewContainer.cellWidth
                anchors.fill: parent
                onEntered: {
                    if (folderGridViewPopup.opened) {
                        folderGridViewPopup.close()
                    }
                }
                onPositionChanged: {
                    if (drag.x < horizontalPadding) {
                        pageIntent = -1
                    } else if (drag.x > (width - searchResultGridViewContainer.cellWidth)) {
                        pageIntent = 1
                    }
                }
                onDropped: {
                    if (pageIntent === 0) {
                        // drop into current page
                        let dragId = drop.getDataAsString("text/x-dde-launcher-dnd-desktopId")
                        dropOnPage(dragId, "internal/folders/0", pages.currentIndex)
                    }
                    pageIntent = 0
                }
                onExited: {
                    pageIntent = 0
                }
                onPageIntentChanged: {
                    if (pageIntent != 0) {
                        dndMovePageTimer.restart()
                    } else {
                        dndMovePageTimer.stop()
                    }
                }

                Timer {
                    id: dndMovePageTimer
                    interval: 1000
                    onTriggered: {
                        if (parent.pageIntent > 0) {
                            pages.incrementCurrentIndex()
                        } else if (parent.pageIntent < 0) {
                            pages.decrementCurrentIndex()
                        }
                    }
                }
            }

            SwipeView {
                id: pages

                anchors.fill: parent
                visible: searchEdit.text === ""

                currentIndex: indicator.currentIndex

                // To ensure toplevelRepeater's model (page count) updated correctly
                // Caution! Don't put it directly under a Repeater{}, that will prevent Connections from working
                Connections {
                    target: MultipageProxyModel
                    function onRowsInserted() {
                        toplevelRepeater.pageCount = MultipageProxyModel.pageCount(0)
                    }
                    function onRowsRemoved() {
                        toplevelRepeater.pageCount = MultipageProxyModel.pageCount(0)
                    }

                    function onTopLevelPageCountChanged() {
                        toplevelRepeater.pageCount = MultipageProxyModel.pageCount(0)
                    }
                }

                Repeater {
                    id: toplevelRepeater
                    property int pageCount: MultipageProxyModel.pageCount(0)
                    model: pageCount

                    Loader {
                        active: SwipeView.isCurrentItem || SwipeView.isNextItem || SwipeView.isPreviousItem
                        id: gridViewLoader
                        objectName: "Main GridView Loader"

                        sourceComponent: Rectangle {
                            color: "transparent"

                            property var grids: gridViewContainer

                            MultipageSortFilterProxyModel {
                                id: proxyModel
                                sourceModel: MultipageProxyModel
                                pageId: modelData
                                folderId: 0
                            }

                            GridViewContainer {
                                id: gridViewContainer
                                anchors.fill: parent
                                rows: 4
                                columns: 7
                                paddingColumns: 1
                                model: proxyModel
                                padding: 10
                                interactive: false
                                focus: true
                                opacity: folderGridViewPopup.visible ? 0.4 : 1
                                activeGridViewFocusOnTab: gridViewLoader.SwipeView.isCurrentItem
                                itemMove: Transition { NumberAnimation { properties: "x,y"; duration: 250 } }
                                delegate: DropArea {
                                    Keys.forwardTo: [iconItemDelegate]

                                    width: gridViewContainer.cellWidth
                                    height: gridViewContainer.cellHeight
                                    onEntered: {
                                        if (folderGridViewPopup.opened) {
                                            folderGridViewPopup.close()
                                        }
                                    }
                                    onDropped: {
                                        let dragId = drop.getDataAsString("text/x-dde-launcher-dnd-desktopId")
                                        let op = 0
                                        let sideOpPadding = width / 4
                                        if (drop.x < sideOpPadding) {
                                            op = -1
                                        } else if (drop.x > (width - sideOpPadding)) {
                                            op = 1
                                        }
                                        dropOnItem(dragId, model.desktopId, op)
                                    }

                                    IconItemDelegate {
                                        id: iconItemDelegate
                                        anchors.fill: parent
                                        dndEnabled: true
                                        Drag.mimeData: {
                                            "text/x-dde-launcher-dnd-desktopId": model.desktopId
                                        }
                                        visible: dndItem.currentlyDraggedId !== model.desktopId
                                        iconSource: iconName
                                        icons: folderIcons
                                        padding: 5
                                        onItemClicked: {
                                            launchApp(desktopId)
                                        }
                                        onFolderClicked: {
                                            let idStr = model.desktopId
                                            let idNum = Number(idStr.replace("internal/folders/", ""))
                                            folderLoader.currentFolderId = idNum
                                            folderGridViewPopup.open()
                                            folderLoader.folderName = model.display.startsWith("internal/category/") ? getCategoryName(model.display.substring(18)) : model.display
                                            console.log("open folder id:" + idNum)
                                        }
                                        onMenuTriggered: {
                                            showContextMenu(this, model, folderIcons, false, true)
                                        }
                                    }
                                }
                            }
                        }

                        // Since SwipeView will catch the mouse click event so we need to also do it here...
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (!DebugHelper.avoidHideWindow) {
                                    LauncherController.visible = false
                                }
                            }
                        }
                    }
                }
            }

            DelegateModel {
                id: delegateSearchResultModel
                model: SearchFilterProxyModel
                delegate: IconItemDelegate {
                    iconSource: iconName
                    width: searchResultGridViewContainer.cellWidth
                    height: searchResultGridViewContainer.cellHeight
                    padding: 5
                    onItemClicked: {
                        launchApp(desktopId)
                    }
                    onMenuTriggered: {
                        showContextMenu(this, model, false, false, true)
                    }
                }
            }

            GridViewContainer {
                id: searchResultGridViewContainer

                anchors.fill: parent
                visible: searchEdit.text !== ""
                activeFocusOnTab: visible && gridViewFocus
                focus: true

                rows: 4
                columns: 7
                paddingColumns: 1
                placeholderIcon: "search_no_result"
                placeholderText: qsTranslate("WindowedFrame", "No search results")
                placeholderIconSize: 256
                model: delegateSearchResultModel
                padding: 10
                interactive: false
            }
        }


        SearchEdit {
            id: searchEdit

            Layout.alignment: Qt.AlignHCenter
            implicitWidth: (parent.width / 2) > 280 ? 280 : (parent.width / 2)

            placeholder: qsTranslate("WindowedFrame", "Search")
            onTextChanged: {
//            console.log(text)
                SearchFilterProxyModel.setFilterRegularExpression(text)
            }
        }
    }

    Popup {
        id: folderGridViewPopup

        focus: true
//        visible: true

        property int cs: searchResultGridViewContainer.cellHeight
//        anchors.centerIn: parent // seems dtkdeclarative's Popup doesn't have anchors.centerIn

        width: cs * 4 + 20 /* padding */
        height: cs * 3 + 130 /* title height*/
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2

        modal: true

        onAboutToHide: {
            // reset folder view
            folderLoader.currentFolderId = -1
        }

        Loader {
            id: folderLoader

            property string folderName: "Sample Text"
            property int currentFolderId: -1

            active: currentFolderId !== -1
            anchors.fill: parent

            sourceComponent: Control {
                // Ensure drop won't fallthough the Popup.
                background: DropArea {
                    anchors.fill: parent
                    onDropped: {
                        let dragId = drop.getDataAsString("text/x-dde-launcher-dnd-desktopId")
                        dropOnPage(dragId, "internal/folders/" + folderLoader.currentFolderId, folderPagesView.currentIndex)
                    }
                }

                contentItem: ColumnLayout {
                    spacing: 5
                    anchors.fill: parent

                    Item {
                        Layout.preferredHeight: 5
                    }

                    SystemPalette { id: folderTextPalette }
                    TextInput {
                        Layout.fillWidth: true

                        font: DTK.fontManager.t3
                        horizontalAlignment: Text.AlignHCenter
                        text: folderLoader.folderName
                        color: folderTextPalette.text
                        onEditingFinished: {
                            MultipageProxyModel.updateFolderName(folderLoader.currentFolderId, text);
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: "transparent"

                        SwipeView {
                            id: folderPagesView
                            clip: true

                            anchors.fill: parent

                            currentIndex: folderPageIndicator.currentIndex

                            Repeater {
                                model: MultipageProxyModel.pageCount(folderLoader.currentFolderId) // FIXME: should be a property?

                                Loader {
                                    active: SwipeView.isCurrentItem || SwipeView.isNextItem || SwipeView.isPreviousItem
                                    id: folderGridViewLoader
                                    objectName: "Folder GridView Loader"

                                    sourceComponent: Rectangle {
                                        anchors.fill: parent
                                        color: "transparent"

                                        MultipageSortFilterProxyModel {
                                            id: folderProxyModel
                                            sourceModel: MultipageProxyModel
                                            pageId: modelData
                                            folderId: folderLoader.currentFolderId
                                        }

                                        GridViewContainer {
                                            id: folderGridViewContainer
                                            anchors.fill: parent
                                            rows: 3
                                            columns: 4
                                            model: folderProxyModel
                                            padding: 10
                                            interactive: false
                                            focus: true
                                            activeGridViewFocusOnTab: folderGridViewLoader.SwipeView.isCurrentItem
                                            itemMove: Transition { NumberAnimation { properties: "x,y"; duration: 250 } }
                                            delegate: DropArea {
                                                width: folderGridViewContainer.cellWidth
                                                height: folderGridViewContainer.cellHeight
                                                onDropped: {
                                                    let dragId = drop.getDataAsString("text/x-dde-launcher-dnd-desktopId")
                                                    let op = 0
                                                    let sideOpPadding = width / 4
                                                    if (drop.x < sideOpPadding) {
                                                        op = -1
                                                    } else if (drop.x > (width - sideOpPadding)) {
                                                        op = 1
                                                    }
                                                    dropOnItem(dragId, model.desktopId, op)
                                                }

                                                IconItemDelegate {
                                                    anchors.fill: parent
                                                    dndEnabled: true
                                                    Drag.mimeData: {
                                                        "text/x-dde-launcher-dnd-desktopId": model.desktopId
                                                    }
                                                    visible: dndItem.currentlyDraggedId !== model.desktopId
                                                    iconSource: iconName

                                                    padding: 5
                                                    onItemClicked: {
                                                        launchApp(desktopId)
                                                    }
                                                    onMenuTriggered: {
                                                        showContextMenu(this, model, false, false, true)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    PageIndicator {
                        Layout.alignment: Qt.AlignHCenter

                        id: folderPageIndicator

                        count: folderPagesView.count
                        currentIndex: folderPagesView.currentIndex
                        interactive: true
                    }
                }
            }
        }
        background: InWindowBlur {
            id: blur
            implicitWidth: DS.Style.popup.width
            implicitHeight: DS.Style.popup.height
            radius: DS.Style.popup.radius
            offscreen: true
            ItemViewport {
                anchors.fill: parent
                fixed: true
                sourceItem: blur.content
                radius: DS.Style.popup.radius
                hideSource: false
            }

            Rectangle {
                anchors.fill: parent
                radius: DS.Style.popup.radius
                color: Qt.rgba(255.0, 255.0, 255.0, 0.15)
            }
        }
    }

    Keys.onPressed: {
        if (searchEdit.focus === false && !searchEdit.text && (event.text && !"\t ".includes(event.text))) {
            searchEdit.focus = true
            searchEdit.text = event.text
        }
    }

    Keys.onEscapePressed: {
        if (!DebugHelper.avoidHideWindow) {
            LauncherController.visible = false;
        }
    }

    Connections {
        target: LauncherController
        function onVisibleChanged() {
            // only do these clean-up steps on launcher get hide
            if (LauncherController.visible) return
            // clear searchEdit text
            searchEdit.text = ""
            // close folder popup
            if (folderGridViewPopup.visible) folderGridViewPopup.close()
            // reset(remove) keyboard focus
            baseLayer.focus = true
            // reset page to the first page
            pages.setCurrentIndex(0)
        }
    }
}
