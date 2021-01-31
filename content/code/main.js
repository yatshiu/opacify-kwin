var last_active = null;   // this is a client

var old_setting = {};

var run_count = 0;

function on_client_activated(client) {    
    if (client != null && last_active != client) {
//        print_debug_info(client)
//        client.activeChanged.connect(on_per_client_activated);          // on a per client callback, client is null
        last_active = client;        
        if (typeof old_setting[String(client.windowId)] == 'undefined') {
            old_setting[String(client.windowId)] = client.opacity;
        }
        client.opacity = 1.0;

        var other_clients = workspace.clientList();
        var reset_other = client.rect == client.visableRect;  // not being covered
        for (var i = 0; i < other_clients.length; i++) {
            var other_client = other_clients[i];
//            print_debug_info(other_client)
            if (should_ignore(other_client))
                continue;
            
            if (!on_same_surface || reset_other) {
                reset_opacify(other_client)
            } else {
                if (client != other_client) {
                    if (is_covered_by(client, other_client)) {
                        do_opacify(other_client);
                    } else {
                        reset_opacify(other_client);
                    }
                } else {
                    // if clientList is in Z-order we can stop checking and just reset anyone we opacify before
                    //  client is not in Z order
                    // reset_others = true;
                }
            }
        }
    }
    if (run_count >= 10000) {
        clean_setting()
        run_count = 0;
    }
}

function clean_setting() {
    var new_setting = {}
    var other_clients = workspace.clientList();
    for (var i = 0; i < other_clients.length; i++) {
        var other_client = other_clients[i];
        var window_id = String(other_client.windowId)
        if (typeof old_setting[window_id] != 'undefined') {
            new_setting[window_id] = old_setting[window_id]
        }
    }
    old_setting = new_setting
}

function on_per_client_activated() {
    // client is null, useless
}

function print_debug_info(client) {
    print(client.caption + ": " + client.geometry.x + ", " +  (client.geometry.x + client.geometry.width) + ", " + client.geometry.y + ", " + (client.geometry.y + client.geometry.height) + ": " + client.resourceClass + ", " + client.resourceName + ", " + client.windowRole + ", " + client.specialWindow);
}

function on_same_surface(client, other_client) {
    return (
        !client.minimized 
        && !other_client.minimized 
        && client.screen == other_client.screen
        && (client.activities.length === 0  || client.activities.indexOf(other_client.activity) !== -1) /* on all activities or same activities*/
        && (client.desktop == -1 || other_client.desktop == -1 || client.desktop == other_client.desktop)
        )
}

function is_covered_by(client, other_client) {
    if (client.desktop == -1 || other_client.desktop == -1 || client.desktop == other_client.desktop) {
        var ax1 = client.pos.x;
        var ay1 = client.pos.y;
        var ax2 = ax1 + client.geometry.width;
        var ay2 = ay1 + client.geometry.height;
        var bx1 = other_client.pos.x;
        var by1 = other_client.pos.y;
        var bx2 = bx1 + other_client.geometry.width;
        var by2 = by1 + other_client.geometry.height;        

        if (ax1 > bx2 || bx1 > ax2)
            return false
        if (ay1 > by2 || by1 > by2)
            return false
        return true
    }
    return false;
}

function save_opacity(window_id, opacity) {
    if (typeof old_setting[window_id] == 'undefined') {
        old_setting[window_id] = opacity;
    }
}

function do_opacify(client) {
    var window_id = String(client.windowId)
    save_opacity(window_id, client.opacity)
//    print("\t targetting, old value = " + old_setting[window_id]);
    client.opacity = 0.3
}

function reset_opacify(client) {    
    var oldval = old_setting[String(client.windowId)];
    if (typeof oldval == 'undefined') {
        // we didn't set it opacity, don't touch it
//        print("\t NOT restoring, reset to 1.0");
        client.opacity = 1.0
    } else {   
        oldval = Math.round(oldval*10)/10.0;
//        print("\t restoring " + oldval);
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
        || (KWINCONFIG.ignoreClass.indexOf(resourceClass) >= 0)
        || (KWINCONFIG.ignoreClass.indexOf(resourceName) >= 0)
//        || (matchWords(client.caption, KWINCONFIG.ignoreTitle) >= 0)
        || (KWINCONFIG.ignoreRole.indexOf(windowRole) >= 0)
    );
}

var KWINCONFIG = {
    ignoreClass : [],
    ignoreRole : [],
}

workspace.clientActivated.connect(on_client_activated);


