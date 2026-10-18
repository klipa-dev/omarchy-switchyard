import QtQuick

// Switchyard's shell entry point. The host mounts this so the plugin can be
// enabled and listed; wave 1 has no in-shell behaviour (routing and launching
// happen entirely in the Bash handler and CLI). A later section adds a
// settings panel that talks to the same rules file.
Item {
    property var shell: null
    property string omarchyPath: ""
}
