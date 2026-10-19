import QtQuick

// Switchyard's headless shell entry point. The host mounts this so the
// plugin can be enabled and listed; routing and launching happen entirely in
// the Bash handler and CLI. The settings UI lives in Panel.qml.
Item {
    property var shell: null
    property string omarchyPath: ""
}
