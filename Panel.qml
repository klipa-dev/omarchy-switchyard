import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// Switchyard's settings panel: summoned over `omarchy-shell shell toggle
// klipa.switchyard '{}'`. Shows whether Switchyard is the default browser,
// the recorded fallback, and the configured rules; adds, edits and removes
// rules and picks the fallback browser; toggles activation.
// Every write goes through the CLI (Quickshell.Io Process); the only direct
// read is rules.json via FileView. No timers, no polling: everything here
// reacts to open() or a CLI run finishing.
Item {
  id: root

  property var shell: null
  property var manifest: null

  property bool opened: false

  readonly property string rulesInvalidMessage: "rules.json is invalid"

  // Prefer the plugin's own checkout (works for a user's `<name>.switchyard`
  // clone too); fall back to the stock install path only when the entry
  // point isn't loaded from a file:// URL (e.g. a packaged resource).
  readonly property string pluginDir: {
    var url = String(Qt.resolvedUrl("."))
    return url.indexOf("file://") === 0
      ? url.substring("file://".length)
      : (Quickshell.env("HOME") + "/.config/omarchy/plugins/klipa.switchyard/")
  }
  readonly property string cliPath: pluginDir + "bin/omarchy-switchyard"
  readonly property string rulesPath: {
    var configHome = Quickshell.env("XDG_CONFIG_HOME")
    var base = (configHome && configHome.length > 0) ? configHome : (Quickshell.env("HOME") + "/.config")
    return base + "/omarchy-switchyard/rules.json"
  }

  property bool active: false
  property string defaultBrowser: ""
  property string fallback: ""
  property bool hasFallback: false
  property string error: ""

  property var rules: []

  // Browsers known to the system, loaded fresh each time the panel opens
  // (`browsers --json`): [{id, name}, ...]. Feeds both dropdowns below.
  property var browsers: []
  readonly property var targetOptions: [{value: "webapp", label: "Web app window"}].concat(
    root.browsers.map(function(b) { return {value: String(b.id), label: String(b.name)} }))
  readonly property var fallbackOptions: root.browsers.map(function(b) {
    return {value: String(b.id), label: String(b.name)}
  })

  property string pendingRemoveHost: ""
  property bool removeConfirmOpen: false

  readonly property string statusText: root.active
    ? "Active"
    : "Not active (default browser: " + (root.defaultBrowser || "unknown") + ")"
  readonly property string fallbackText: "Fallback: " + (root.hasFallback ? root.fallback : "(none)")
  readonly property string actionButtonText: root.active ? "Deactivate" : "Activate"

  function targetLabel(target) {
    return target === "webapp" ? "Web app window" : String(target)
  }

  function open(payloadJson) {
    root.opened = true
    root.refreshStatus()
    root.refreshBrowsers()
    // The window is instantiated hidden, so content's `focus: true` is
    // evaluated before the surface is mapped and Escape would land nowhere.
    // Re-acquire after mapping.
    Qt.callLater(function() {
      if (root.opened) keyCatcher.forceActiveFocus()
    })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "klipa.switchyard")
    else root.close()
  }

  function refreshStatus() {
    if (statusProc.running) return
    if (root.error !== root.rulesInvalidMessage) root.error = ""
    statusProc.running = true
  }

  function activateOrDeactivate() {
    if (actionProc.running) return
    if (root.error !== root.rulesInvalidMessage) root.error = ""
    actionProc.command = [root.cliPath, root.active ? "deactivate" : "activate"]
    actionProc.running = true
  }

  function launchRulesEditor() {
    if (editorProc.running) return
    if (root.error !== root.rulesInvalidMessage) root.error = ""
    editorProc.running = true
  }

  function refreshBrowsers() {
    if (browsersProc.running) return
    browsersProc.running = true
  }

  // Every write below is one CLI call through Process, followed by a
  // status refresh; the rules list refreshes itself through
  // FileView.watchChanges.
  // Add row: "rules add <host> <target>" creates or replaces a rule for
  // that host (the add row doubles as the edit row: "Edit" fills it,
  // "Add" then replaces by host).
  // Remove: a ConfirmDialog, then "rules remove <host>".
  // Fallback dropdown: onChanged runs the CLI's "fallback" command with
  // the chosen desktop id.
  function addRule() {
    if (addProc.running) return
    var host = hostField.text.trim()
    if (host === "") return
    if (root.error !== root.rulesInvalidMessage) root.error = ""
    addProc.command = [root.cliPath, "rules", "add", host, targetDropdown.value]
    addProc.running = true
  }

  function editRule(host, target) {
    hostField.text = host
    targetDropdown.value = target
    hostField.forceActiveFocus()
  }

  function requestRemove(host) {
    root.pendingRemoveHost = host
    root.removeConfirmOpen = true
  }

  function cancelRemove() {
    root.removeConfirmOpen = false
    root.pendingRemoveHost = ""
  }

  function confirmRemove() {
    root.removeConfirmOpen = false
    if (removeProc.running) return
    if (root.error !== root.rulesInvalidMessage) root.error = ""
    removeProc.command = [root.cliPath, "rules", "remove", root.pendingRemoveHost]
    removeProc.running = true
  }

  function setFallback(id) {
    if (fallbackProc.running) return
    if (root.error !== root.rulesInvalidMessage) root.error = ""
    fallbackProc.command = [root.cliPath, "fallback", id]
    fallbackProc.running = true
  }

  function parseRules(raw) {
    try {
      var parsed = JSON.parse(raw)
      if (parsed && Array.isArray(parsed.rules)) {
        root.rules = parsed.rules
        if (root.error === root.rulesInvalidMessage) root.error = ""
      } else {
        root.rules = []
        root.error = root.rulesInvalidMessage
      }
    } catch (e) {
      root.rules = []
      root.error = root.rulesInvalidMessage
    }
  }

  Process {
    id: statusProc
    command: [root.cliPath, "status", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(text || "")
          root.active = !!parsed.active
          root.defaultBrowser = String(parsed.default_browser || "")
          root.hasFallback = parsed.fallback !== null && parsed.fallback !== undefined && String(parsed.fallback) !== ""
          root.fallback = root.hasFallback ? String(parsed.fallback) : ""
          // fallbackDropdown.value is a plain property Dropdown overwrites
          // imperatively on selection, which permanently breaks its
          // `value: root.fallback` binding the first time it fires; resync
          // it explicitly every time a fresh status confirms the real
          // fallback (on open, and after a `fallback` CLI call either way).
          fallbackDropdown.value = root.fallback
        } catch (e) {
          // Leave the previous status visible; a non-empty stderr or a
          // non-zero exit (below) still surfaces the failure.
        }
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (String(text || "").trim() !== "") root.error = String(text).trim()
    }
    onExited: function(exitCode) {
      if (exitCode !== 0 && root.error === "") root.error = "Could not read Switchyard's status"
    }
  }

  Process {
    id: actionProc
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (String(text || "").trim() !== "") root.error = String(text).trim()
    }
    onExited: function(exitCode) {
      if (exitCode !== 0 && root.error === "") root.error = "omarchy-switchyard failed"
      root.refreshStatus()
    }
  }

  Process {
    id: editorProc
    command: ["omarchy-launch-editor", root.rulesPath]
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (String(text || "").trim() !== "") root.error = String(text).trim()
    }
    onExited: function(exitCode) {
      if (exitCode === 0) root.dismiss()
      else if (root.error === "") root.error = "Could not open rules.json"
    }
  }

  Process {
    id: browsersProc
    command: [root.cliPath, "browsers", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(text || "[]")
          root.browsers = Array.isArray(parsed) ? parsed : []
        } catch (e) {
          root.browsers = []
        }
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (String(text || "").trim() !== "") root.error = String(text).trim()
    }
  }

  Process {
    id: addProc
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (String(text || "").trim() !== "") root.error = String(text).trim()
    }
    onExited: function(exitCode) {
      if (exitCode === 0) hostField.text = ""
      else if (root.error === "") root.error = "omarchy-switchyard failed"
      root.refreshStatus()
    }
  }

  Process {
    id: removeProc
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (String(text || "").trim() !== "") root.error = String(text).trim()
    }
    onExited: function(exitCode) {
      if (exitCode !== 0 && root.error === "") root.error = "omarchy-switchyard failed"
      root.pendingRemoveHost = ""
      root.refreshStatus()
    }
  }

  Process {
    id: fallbackProc
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (String(text || "").trim() !== "") root.error = String(text).trim()
    }
    onExited: function(exitCode) {
      if (exitCode !== 0 && root.error === "") root.error = "omarchy-switchyard failed"
      root.refreshStatus()
    }
  }

  FileView {
    id: rulesFile
    path: root.rulesPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.parseRules(text())
    onLoadFailed: {
      // No rules.json (not yet created, or just removed) is "No rules
      // configured", not an error: that message is reserved for a file
      // that exists but fails to parse or whose .rules isn't an array
      // (see parseRules above).
      root.rules = []
      if (root.error === root.rulesInvalidMessage) root.error = ""
    }
  }

  PanelWindow {
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "klipa-switchyard"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, 0.55)

      MouseArea {
        anchors.fill: parent
        onClicked: root.dismiss()
      }
    }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      // Gets keys first, even when a focused descendant (hostField, a
      // Dropdown trigger) would otherwise consume them: the confirm-dialog
      // and Escape-dismiss branches below must always run.
      Keys.priority: Keys.BeforeItem

      Keys.onPressed: function(event) {
        if (root.removeConfirmOpen) {
          if (removeConfirm.handleKey(event)) event.accepted = true
          return
        }
        if (event.key === Qt.Key_Escape) {
          root.dismiss()
          event.accepted = true
        }
      }

      Item {
        id: cluster
        anchors.centerIn: parent
        width: card.width
        height: card.height
        // Narrow or heavily scaled outputs: shrink the whole card rather
        // than clipping it at the screen edge.
        scale: Math.min(1,
          (keyCatcher.width - Style.space(32)) / Math.max(1, width),
          (keyCatcher.height - Style.space(32)) / Math.max(1, height))

        // Swallow clicks so only the scrim outside the card dismisses.
        MouseArea { anchors.fill: parent; onClicked: {} }

        BorderSurface {
          id: card
          width: Style.space(360)
          height: card.contentTopInset + card.contentBottomInset + content.implicitHeight
          color: Color.background
          radius: Style.cornerRadius
          padding: Style.space(18)

          Column {
            id: content
            anchors.fill: parent
            anchors.topMargin: card.contentTopInset
            anchors.rightMargin: card.contentRightInset
            anchors.bottomMargin: card.contentBottomInset
            anchors.leftMargin: card.contentLeftInset
            spacing: Style.space(14)

            PanelSectionHeader {
              text: "Switchyard"
              foreground: Color.foreground
            }

            Column {
              width: parent.width
              spacing: Style.space(4)

              Text {
                textFormat: Text.PlainText
                text: root.statusText
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                wrapMode: Text.Wrap
                width: parent.width
              }

              Text {
                textFormat: Text.PlainText
                text: root.fallbackText
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
              }

              Dropdown {
                id: fallbackDropdown
                width: parent.width
                label: "Fallback"
                value: root.fallback
                options: root.fallbackOptions
                onChanged: function(v) { root.setFallback(v) }
              }
            }

            Button {
              text: root.actionButtonText
              bordered: true
              enabled: !actionProc.running
              onClicked: root.activateOrDeactivate()
            }

            Text {
              textFormat: Text.PlainText
              visible: root.error !== ""
              text: root.error
              color: Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.Wrap
              width: parent.width
            }

            PanelSeparator {}

            PanelSectionHeader {
              text: "Rules"
              foreground: Color.foreground
            }

            Column {
              width: parent.width
              spacing: Style.space(6)

              Text {
                textFormat: Text.PlainText
                visible: root.rules.length === 0
                text: "No rules configured"
                color: Qt.darker(Color.foreground, 1.4)
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.italic: true
              }

              Repeater {
                model: root.rules

                Row {
                  required property var modelData
                  spacing: Style.space(8)
                  width: parent.width

                  Text {
                    textFormat: Text.PlainText
                    text: modelData.host || ""
                    color: Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                  }

                  Text {
                    textFormat: Text.PlainText
                    text: "→"
                    color: Qt.darker(Color.foreground, 1.4)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                  }

                  Text {
                    textFormat: Text.PlainText
                    text: root.targetLabel(modelData.target)
                    color: Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                  }

                  Button {
                    text: "Edit"
                    bordered: true
                    fontSize: Style.font.bodySmall
                    onClicked: root.editRule(modelData.host, modelData.target)
                  }

                  Button {
                    text: "Remove"
                    bordered: true
                    fontSize: Style.font.bodySmall
                    onClicked: root.requestRemove(modelData.host)
                  }
                }
              }
            }

            Item {
              width: parent.width
              height: Math.max(hostField.implicitHeight, targetDropdown.implicitHeight, addButton.implicitHeight)

              TextField {
                id: hostField
                anchors.left: parent.left
                anchors.right: targetDropdown.left
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                placeholderText: "*.example.com"
                onAccepted: root.addRule()
              }

              Dropdown {
                id: targetDropdown
                anchors.right: addButton.left
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(140)
                showLabel: false
                value: "webapp"
                options: root.targetOptions
              }

              Button {
                id: addButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "Add"
                bordered: true
                enabled: !addProc.running
                onClicked: root.addRule()
              }
            }

            PanelSeparator {}

            Row {
              width: parent.width
              spacing: Style.space(10)

              Button {
                text: "Open rules file"
                bordered: true
                enabled: !editorProc.running
                onClicked: root.launchRulesEditor()
              }

              Button {
                text: "Close"
                bordered: true
                onClicked: root.dismiss()
              }
            }
          }
        }
      }

      ConfirmDialog {
        id: removeConfirm
        anchors.fill: parent
        z: 10
        opened: root.removeConfirmOpen
        message: "Remove the rule for " + root.pendingRemoveHost + "?"
        confirmText: "Remove"
        background: Color.background
        foreground: Color.foreground
        onCanceled: root.cancelRemove()
        onConfirmed: root.confirmRemove()
      }
    }
  }
}
