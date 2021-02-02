import QtQuick 2.0
import org.kde.plasma.core 2.0 as PlasmaCore;
import org.kde.plasma.components 2.0 as Plasma;
import org.kde.kwin 2.0;

Item {
    id: root

    readonly property var ignoreClass: (
        KWin.readConfig("ignoreClass", "").split(",").map(function(rule) {
                return rule.trim();
            })
    )

    readonly property var ignoreRole: (
        KWin.readConfig("ignoreRole", "").split(",").map(function(rule) {
                return rule.trim();
            })
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
    property var current_stack: ""

    PlasmaCore.DataSource {
        id: shell
        engine: 'executable'

        connectedSources: []

        function run(cmd) {
            current_stack = "";
            shell.connectSource(cmd);
        }

        onNewData: {
            current_stack = shell.data;
            //console.log("keys="+current_stack.keys() + ", v = "+ JSON.stringify(current_stack[current_stack.keys()], null, 4));
            current_stack = shell.data[shell.data.keys()]["stdout"].split(",").map(Number);
            console.log(current_stack)
//            shell.disconnectSource(sourceName);
            opacify();
        }
    }

    function opacify() {
        if (last_active != workspace.activeClient) {
            last_active = workspace.activeClient;
            if (last_active == null)
                reset_all()
            if (typeof old_setting[String(last_active.windowId)] == 'undefined') {
                old_setting[String(last_active.windowId)] = last_active.opacity;
            }
            last_active.opacity = activeOpacity;
            var reset_other = false;
            for (var i = current_stack.length - 1; i >=0; --i) {
                if (current_stack[i] <= 0)
                    continue;
                var other_client = workspace.getClient(current_stack[i]);
                print_debug_info(other_client);
                if (should_ignore(other_client))
                    continue;
                if (other_client == last_active) {
                    reset_other = true;
                } else if (reset_other || !on_same_surface(last_active, other_client) || !is_covered_by(last_active, other_client)) {
                    reset_opacify(other_client)
                } else {
                    do_opacify(other_client);
                }
            }
        }
    }

    function get_window_stack() {
        //var cmd = "for i in `xprop -root |grep _NET_CLIENT_LIST_STACKING\( | cut -b 48- | sed 's/,//g'` ; do echo $i `xprop -id $i |grep NET_WM_NAME`; done"
        var cmd = "xprop -root |grep _NET_CLIENT_LIST_STACKING\\( | cut -b 48- "
        shell.run(cmd)
    }

    function reset_all() {
        console.log("reset all")
        var other_clients = workspace.clientList();
        for (var i = 0; i < other_clients.length; i++) {
            var other_client = other_clients[i];
            var window_id = String(other_client.windowId)
            if (typeof old_setting[window_id] != 'undefined') {
                oldval = Math.round(old_setting[window_id]*10)/10.0;
                if (other_clients.opacity != oldval)
                    other_clients.opacity = oldval
            }
        }
        old_setting = {};
        last_active = null;
    }

    function print_debug_info(client) {
        console.log(client.windowId + " : " + client.internalId + " : " + client.pid + " : " + client.caption + ": " + client.geometry.x + ", " +  (client.geometry.x + client.geometry.width) + ", " + client.geometry.y + ", " + (client.geometry.y + client.geometry.height) + ": " + client.resourceClass + ", " + client.resourceName + ", " + client.windowRole + ", " + client.specialWindow + ", minimized = " + client.minimized + ", s = " + client.screen + ", d = " + client.desktop + ", act = " + client.activity + ", act_len = " + client.activities.length);
        client.activities.forEach(function(act) {
//            console.log("\t" + String(act));
        });
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
        var ax1 = client.geometry.x;
        var ay1 = client.geometry.y;
        var ax2 = ax1 + client.geometry.width;
        var ay2 = ay1 + client.geometry.height;
        var bx1 = other_client.geometry.x;
        var by1 = other_client.geometry.y;
        var bx2 = bx1 + other_client.geometry.width;
        var by2 = by1 + other_client.geometry.height;        

        if (ax1 > bx2 || bx1 > ax2)
            return false
        if (ay1 > by2 || by1 > ay2)
            return false
        return true
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
    //        console.log("\t targetting, old value = " + old_setting[window_id]);
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
    //        || resourceClass === "plasmashell"
            || (ignoreClass.indexOf(resourceClass) >= 0)
            || (ignoreClass.indexOf(resourceName) >= 0)
    //        || (matchWords(client.caption, KWINCONFIG.ignoreTitle) >= 0)
            || (ignoreRole.indexOf(windowRole) >= 0)
        );
    }

    Component.onCompleted: {
        console.log("Opacify-kwin started");
        workspace.clientActivated.connect(function (client) {get_window_stack();});
    }
}