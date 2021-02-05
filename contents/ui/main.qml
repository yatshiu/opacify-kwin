import QtQuick 2.0
import org.kde.plasma.core 2.0 as PlasmaCore;
import org.kde.kwin 2.0;

Item {
    id: root

    readonly property var ignoreClass: (
        KWin.readConfig("ignoreClass", "conky-semi").length > 0 ? KWin.readConfig("ignoreClass", "conky-semi").split(",").map(function(rule) {
                return rule.trim();
            }) : []
    )

    readonly property var ignoreRole: (
        KWin.readConfig("ignoreRole", "").length > 0 ? KWin.readConfig("ignoreRole", "").split(",").map(function(rule) {
                return rule.trim();
            }) : []
    )

    readonly property var activeOpacity: (
        KWin.readConfig("activeOpacity", 1.0)
    )

    readonly property var inactiveOpacity: (
        KWin.readConfig("inactiveOpacity", 0.3)
    )

    property var last_active: null
    property var old_setting: {"a":1.0}
    property var run_counter: 0
    property var current_stack: {"a": 2}

    PlasmaCore.DataSource {
        // TODO: to get stacking order properly 
        //    https://bugs.kde.org/show_bug.cgi?id=409889
        id: shell
        engine: 'executable'
        readonly property var cmd: "xprop -root |grep _NET_CLIENT_LIST_STACKING\\( | cut -b 48- ";
        connectedSources: []

        function run() {
            shell.connectSource(cmd);
        }

        onNewData: {
//            console.log("data = " + JSON.stringify(shell.data, null, 4));            
            var new_map = {};
            var alist = shell.data[cmd]["stdout"].split(",").map(Number);
            for (var i = alist.length - 1; i >= 0; --i) {
                new_map[alist[i]] = i;
            }
            shell.disconnectSource(sourceName);
            if (current_stack != new_map) {
                current_stack = new_map;
                opacify();
            }
        }
    }

    function opacify() {
        if (!current_stack)
            return;

//        console.log ("stack = " + JSON.stringify(current_stack));
        if (workspace.activeClient == null) {
            reset_all();
            return;
        }
        if (last_active != workspace.activeClient) {
            last_active = workspace.activeClient;
            var active_idx = current_stack[last_active.windowId]
//            console.log("idx:" + active_idx + ", c = " + JSON.stringify(last_active, " "));

            if (typeof old_setting[String(last_active.windowId)] == 'undefined') {
                old_setting[String(last_active.windowId)] = last_active.opacity;
            }
            last_active.opacity = activeOpacity;

            var other_clients = workspace.clientList()
            for (var i = 0; i < other_clients.length; ++i) {
                var other_client = other_clients[i];
                if (other_client == last_active)
                    continue;
//                print_debug_info(other_client);
                if (should_ignore(other_client)) {
//                    console.log("ignored");
                    continue;
                }

                var other_idx = current_stack[other_client.windowId];
                if (other_idx > active_idx && (on_same_surface(last_active, other_client) && is_covered_by(last_active, other_client))) {
                    do_opacify(other_client);
                } else {
                    reset_opacify(other_client);
                }
            }
        }
    }

    function reset_all() {
        console.log("reset all")
        var other_clients = workspace.clientList();
        for (var i = 0; i < other_clients.length; i++) {
            var other_client = other_clients[i];
            var window_id = String(other_client.windowId)
            if (typeof old_setting[window_id] != 'undefined') {
                var oldval = Math.round(old_setting[window_id]*10)/10.0;
                if (other_clients.opacity != oldval)
                    other_clients.opacity = oldval
            }
        }
        old_setting = {};
        last_active = null;
    }

    function print_debug_info(client) {
        if (client != null)
            console.log("idx:" + current_stack[client.windowId] + " " + client.windowId + " : " + client.caption + ": " + client.geometry.x + ", " +  (client.geometry.x + client.geometry.width) + ", " + client.geometry.y + ", " + (client.geometry.y + client.geometry.height) + ": " + client.resourceClass + ", " + client.resourceName + ", " + client.windowRole + ", " + client.specialWindow + ", minimized = " + client.minimized + ", s = " + client.screen + ", d = " + client.desktop + ", act = " + client.activity + ", act_len = " + client.activities.length);
        else
            console.log("trying to print null client");
    }

    function on_same_surface(client, other_client) {
        return (
            !client.minimized 
            && !other_client.minimized 
            && client.screen == other_client.screen
            && (other_client.activities.length == 0  || other_client.activities.indexOf(workspace.currentActivity) != -1) /* on all activities or same activities*/
            && (client.desktop == -1 || other_client.desktop == -1 || client.desktop == other_client.desktop)
            )
    }

    function is_covered_by(client, other_client) {
        if (client.geometry.left >= other_client.geometry.right || other_client.geometry.left >= client.geometry.right)
            return false;
        if (client.geometry.top >= other_client.geometry.bottom || other_client.geometry.top >= client.geometry.bottom)
            return false;

        return true;
    }

    function save_opacity(window_id, opacity) {
        if (typeof old_setting[window_id] == 'undefined') {
            if (opacity != activeOpacity)
                old_setting[window_id] = opacity;
        }
    }

    function do_opacify(client) {
        if (client.opacity != inactiveOpacity) {
            var window_id = String(client.windowId)
            save_opacity(window_id, client.opacity)
//            console.log("\t targetting, old value = " + old_setting[window_id]);
            client.opacity = inactiveOpacity
        }
    }

    function reset_opacify(client) {    
        var oldval = old_setting[String(client.windowId)];
        if (typeof oldval == 'undefined') {
            // we didn't set it opacity, don't touch it
//            console.log("\t NOT restoring, reset to 1.0");
            client.opacity = activeOpacity
        } else {   
            oldval = Math.round(oldval*10)/10.0;
//            console.log("\t restoring " + oldval);
            client.opacity = oldval;
        }
    }

    function should_ignore(client) {
        const resourceClass = String(client.resourceClass);
        const resourceName = String(client.resourceName);
        const windowRole = String(client.windowRole);
        return (
            client.specialWindow
//            || resourceClass === "plasmashell"
            || (ignoreClass.indexOf(resourceClass) >= 0)
            || (ignoreClass.indexOf(resourceName) >= 0)
//            || (matchWords(client.caption, KWINCONFIG.ignoreTitle) >= 0)
            || (ignoreRole.indexOf(windowRole) >= 0)
        );
    }

    function workspace_callback() {
        if (shell == null) {
            remove_event_handlers()
            return;
        }
        shell.run()
    }

    function desktop_change_callback(desktop, client) {
        if (shell == null) {
            remove_event_handlers()
            return;
        }
        if workspace.activeClient != null && desktop != workspace.activeClient.desktop && workspace.activeClient.desktop != -1)
            reset_all();
    }

    function register_event_handers() {
        workspace.clientActivated.connect(workspace_callback)
//        workspace.clientAdded.connect(workspace_callback);
//        workspace.clientRemoved.connect(workspace_callback);
//        workspace.clientSetKeepAbove.connect(function (client, keepAbove) {shell.run();});
//        workspace.clientRestored.connect(workspace_callback);
        workspace.currentDesktopChanged.connect(desktop_change_callback)
    }

    function remove_event_handlers() {
        workspace.clientActivated.disconnect(workspace_callback)
//        workspace.clientAdded.connect(workspace_callback);
//        workspace.clientRemoved.connect(workspace_callback);
//        workspace.clientSetKeepAbove.connect(function (client, keepAbove) {shell.run();});
//        workspace.clientRestored.disconnect(workspace_callback);
        workspace.currentDesktopChanged.disconnect(desktop_change_callback)
    }

    Component.onCompleted: {
        console.log("Opacify-kwin started");
        shell.run();
        console.log("ignoreClass:" + ignoreClass + ", ignoreRole: " + ignoreRole, ", activeOpacity: " + activeOpacity + ", inactiveOpacity: " + inactiveOpacity)
        register_event_handers();
    }
}