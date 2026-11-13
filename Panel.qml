import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Click-to-configure popup for the memento widget. Two fields, written
// straight back into this widget's shell.json entry through the same
// updateEntryInline path the stock clock uses for its own settings, so what
// the panel shows and what the config stores never drift apart.
Panel {
  id: root

  moduleName: "lookiyam.memento"
  ipcTarget: "lookiyam.memento.panel"

  property var hostWidget: null
  property var anchorItem: null

  // The bar keys its open-popup coordination off this, so it has to be the
  // widget in the bar rather than the panel hanging off it.
  readonly property var barIdentity: hostWidget || root

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  property date now: clock.date
  readonly property var today: ({
    year: now.getFullYear(),
    month: now.getMonth(),
    day: now.getDate()
  })

  readonly property var birthYear: setting("birthYear", 0)
  readonly property var birthDate: setting("birthDate", "")
  readonly property var lifeExpectancy: setting("lifeExpectancy", 0)

  readonly property int daysLeft: Model.daysRemaining(today, birthYear, birthDate, lifeExpectancy)
  readonly property int percent: Model.percentLived(today, birthYear, birthDate, lifeExpectancy)

  // What the BORN field shows and accepts: the exact date when one is set,
  // otherwise the bare year. One field for both precisions beats two fields
  // where the second silently overrides the first.
  readonly property string bornValue: {
    var exact = Model.parseBirthDate(birthDate, today.year)
    if (exact) return String(birthDate).replace(/^\s+|\s+$/g, "")
    var year = Model.parseBirthYear(birthYear, today.year)
    return year > 0 ? String(year) : ""
  }

  // Same file and same pick as the boot notification's quote.
  readonly property string quote: Model.quoteOfTheDay(quotesFile.text(), daysLeft)

  // The date fields stay tucked away until the pencil (or `e`) asks for
  // them, so the popup reads as the count and the quote first. An unset
  // widget opens straight into editing: there is nothing else to show.
  property bool editing: false

  function refresh() {
    now = new Date()
  }

  function startEditing() {
    editing = true
    Qt.callLater(loadFields)
  }

  function stopEditing() {
    editing = false
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  // Merged over the existing entry rather than replacing it, so a key this
  // panel does not know about (a hand-set `format`) survives a save.
  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]

    root.settings = entry
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function loadFields() {
    bornField.text = root.bornValue
    expectancyField.text = String(Model.parseLifeExpectancy(root.lifeExpectancy))
    bornField.selectAll()
    bornField.forceActiveFocus()
  }

  // A full date wins when one is typed; a bare year clears any date that was
  // there, because the year the user just entered is the more recent word on
  // the subject and a stale date would quietly outrank it.
  function commit() {
    var typed = String(bornField.text).replace(/^\s+|\s+$/g, "")
    var span = Model.parseLifeExpectancy(expectancyField.text)
    var exact = Model.parseBirthDate(typed, root.today.year)

    if (exact) persistSettings({ birthYear: exact.year, birthDate: typed, lifeExpectancy: span })
    else persistSettings({ birthYear: Model.parseBirthYear(typed, root.today.year), birthDate: "", lifeExpectancy: span })

    root.stopEditing()
  }

  // Tab hops between the two, Enter commits the pair and goes back to the
  // count, Escape drops the edit and goes back without saving.
  function handleKey(event, other) {
    if (event.key === Qt.Key_Escape) {
      root.stopEditing()
      event.accepted = true
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      root.commit()
      event.accepted = true
    } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
      other.selectAll()
      other.forceActiveFocus()
      event.accepted = true
    }
  }

  onOpenedChanged: {
    if (!opened) return
    refresh()
    if (daysLeft < 0) startEditing()
    else stopEditing()
  }

  FileView {
    id: quotesFile
    path: Qt.resolvedUrl("quotes.txt").toString().replace(/^file:\/\//, "")
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  KeyboardPanel {
    id: popup
    anchorItem: root.anchorItem
    bar: root.bar
    owner: root.barIdentity
    open: root.opened
    focusTarget: root.editing ? bornField : keyCatcher
    contentWidth: popup.fittedContentWidth(Style.space(300))
    contentHeight: popup.fittedContentHeight(content.implicitHeight)

    Column {
      id: content
      anchors.fill: parent
      spacing: Style.space(10)

      Item {
        width: parent.width
        height: Math.max(header.implicitHeight, editButton.implicitHeight)

        PanelSectionHeader {
          id: header
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "MEMENTO MORI"
        }

        PanelActionButton {
          id: editButton
          anchors.right: parent.right
          anchors.rightMargin: -Style.space(4)
          anchors.verticalCenter: parent.verticalCenter
          iconText: root.editing ? "󰅖" : "󰏫"
          tooltipText: root.editing ? "Cancel" : "Edit birth date"
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          onClicked: root.editing ? root.stopEditing() : root.startEditing()
        }

        // Keyboard handling while just viewing: Esc closes, e or Enter edits.
        PanelKeyCatcher {
          id: keyCatcher
          width: 0
          height: 0
          onCloseRequested: root.close()
          onActivateRequested: root.startEditing()
          onTextKey: function(text, modifiers) { if (text === "e") root.startEditing() }
        }
      }

      // ---- The count, stated once and large. Everything below it is the
      //      two numbers it was derived from.
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.daysLeft < 0 ? "—" : Model.groupDigits(root.daysLeft)
        color: root.contentForeground
        font.family: root.contentFontFamily
        font.pixelSize: Style.font.body * 2.2
        renderType: Text.NativeRendering
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.daysLeft < 0
          ? "set a birth year to begin"
          : "days remaining · " + root.percent + "% lived"
        color: Qt.darker(root.contentForeground, 1.5)
        font.family: root.contentFontFamily
        font.pixelSize: Style.font.bodySmall
        renderType: Text.NativeRendering
      }

      Text {
        visible: root.quote !== ""
        width: parent.width
        topPadding: Style.space(4)
        text: root.quote
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        color: root.contentForeground
        font.family: root.contentFontFamily
        font.pixelSize: Style.font.bodySmall
        font.italic: true
        renderType: Text.NativeRendering
      }

      PanelSeparator {
        visible: root.editing
        width: parent.width
      }

      Row {
        visible: root.editing
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(8)

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "BORN"
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.bodySmall
          font.letterSpacing: 1
        }

        TextField {
          id: bornField
          width: Style.space(96)
          anchors.verticalCenter: parent.verticalCenter
          placeholderText: "1990 or 1990-06-17"
          foreground: root.contentForeground
          font.family: root.contentFontFamily

          Keys.onPressed: function(event) { root.handleKey(event, expectancyField) }
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          leftPadding: Style.space(6)
          text: "LIVE TO"
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.bodySmall
          font.letterSpacing: 1
        }

        TextField {
          id: expectancyField
          width: Style.space(56)
          anchors.verticalCenter: parent.verticalCenter
          placeholderText: "90"
          foreground: root.contentForeground
          font.family: root.contentFontFamily
          inputMethodHints: Qt.ImhDigitsOnly

          Keys.onPressed: function(event) { root.handleKey(event, bornField) }
        }
      }

      Text {
        visible: root.editing
        anchors.horizontalCenter: parent.horizontalCenter
        text: "enter saves · tab switches · esc cancels"
        color: Qt.darker(root.contentForeground, 1.8)
        font.family: root.contentFontFamily
        font.pixelSize: Style.font.caption
        renderType: Text.NativeRendering
      }
    }
  }
}
