import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Days remaining, counted against a configured birth year and life
// expectancy. The stock clock plugin keeps the same idea as a bar inside its
// calendar popup; this is the number on its own, always in view, and owned
// separately so the packaged clock stays untouched and keeps updating.
//
// Left click opens the settings popup -- clicking a countdown is how you ask
// what it is counting.
//
// Settings (per-widget, in shell.json's layout entry):
//   birthYear       4-digit year. Unset or implausible hides the widget.
//   lifeExpectancy  Whole years. Unset or absurd falls back to 90.
//   birthDate       Optional "YYYY-MM-DD". Without it the endpoint can be no
//                   better than January 1 of the birth year.
//   format          Label template; "{days}" is substituted.
BarWidget {
  id: root
  moduleName: "lookiyam.memento"

  property date now: clock.date

  readonly property var today: ({
    year: now.getFullYear(),
    month: now.getMonth(),
    day: now.getDate()
  })

  readonly property var birthYear: setting("birthYear", 0)
  readonly property var birthDate: setting("birthDate", "")
  readonly property var lifeExpectancy: setting("lifeExpectancy", 0)
  readonly property string labelFormat: setting("format", "{days}")

  // -1 means "not configured", and every label below collapses to empty on
  // it. The widget still paints its slot so there is something to click:
  // a countdown that vanishes when unset leaves no way to set it.
  readonly property int daysLeft: Model.daysRemaining(today, birthYear, birthDate, lifeExpectancy)
  readonly property int percent: Model.percentLived(today, birthYear, birthDate, lifeExpectancy)
  readonly property string displayText: daysLeft < 0 ? "—" : Model.barLabel(daysLeft, labelFormat)

  readonly property string tooltip: daysLeft < 0
    ? "Memento Mori — click to set a birth year"
    : Model.groupDigits(daysLeft) + " days remaining · " + percent + "% lived"

  function refresh() {
    now = new Date()
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  // ---- Popup. Shape contract for the bar's panel routing: Bar.findPanelWidget
  //      requires open/close/opened on the bar-widget root itself.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property real openPanelIndicatorWidth: button.labelWidth

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  // Minutes rather than a day timer: the count only turns over at midnight,
  // but a resume from suspend lands on whatever the next tick is, and a
  // minute of staleness is not worth a wakeup schedule of its own. This is
  // also the precision the stock clock runs at.
  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "lookiyam.memento"

    function refresh(): void { root.broadcast("refresh") }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.togglePanel() }
    function days(): string { return root.daysLeft < 0 ? "" : String(root.daysLeft) }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.displayText
    tooltipText: root.tooltip
    horizontalMargin: 8.75
    verticalPadding: 8.75

    onPressed: function(b) {
      if (b === Qt.LeftButton) root.togglePanel()
    }
  }
}
