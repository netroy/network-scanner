[GtkTemplate (ui = "/in/netroy/network-scanner/ui/MainWindow.ui")]
public class NetworkScanner.MainWindow : Adw.ApplicationWindow {
    private NetworkScanner scanner;

    [GtkChild]
    private unowned Gtk.ListBox list_box;

    [GtkChild]
    private unowned Gtk.Button scan_button;

    [GtkChild]
    private unowned Gtk.DropDown interface_dropdown;

    [GtkChild]
    private unowned Gtk.Box button_box;

    [GtkChild]
    private unowned Gtk.Stack stack;

    public MainWindow (Adw.Application app) {
        Object (application: app);

        scanner = new NetworkScanner ();
        setup_signals ();
        populate_interfaces.begin ();
    }

    private async void populate_interfaces () {
        var interfaces = yield scanner.get_local_interfaces ();
        var model = (Gtk.StringList) interface_dropdown.get_model ();

        foreach (var iface in interfaces) {
            model.append (iface);
        }

        if (model.get_n_items () > 0) {
            interface_dropdown.set_selected (0);
            scan_button.sensitive = true;
        }
    }

    private void setup_signals () {
        scan_button.clicked.connect (() => {
            var model = (Gtk.StringList) interface_dropdown.get_model ();
            var selected = interface_dropdown.get_selected ();
            var interface_name = model.get_string (selected);

            clear_devices ();
            scan_button.sensitive = false;
            interface_dropdown.sensitive = false;

            // Add spinner button
            var spinner_button = new Gtk.Button ();
            spinner_button.add_css_class ("circular");
            spinner_button.add_css_class ("flat");
            spinner_button.tooltip_text = _("Click to stop scanning");

            var spinner = new Adw.Spinner ();
            spinner_button.set_child (spinner);

            spinner_button.clicked.connect (() => {
                scanner.cancel_scan ();
            });

            button_box.prepend (spinner_button);
            stack.visible_child_name = "list";

            scanner.start_scan.begin (interface_name, (obj, res) => {
                try {
                    scanner.start_scan.end (res);
                } catch (Error e) {
                    // Handle cancellation or other errors
                }

                scan_button.sensitive = true;
                interface_dropdown.sensitive = true;
                button_box.remove (spinner_button);

                if (list_box.get_first_child () == null) {
                    stack.visible_child_name = "empty";
                }
            });
        });

        scanner.device_discovered.connect (device => {
            stack.visible_child_name = "list";
            add_or_update_device (device);
        });
    }

    private void clear_devices () {
        while (list_box.get_first_child () != null) {
            list_box.remove (list_box.get_first_child ());
        }
    }

    private void add_or_update_device (NetworkDevice device) {
        // Check if device already exists
        var existing = find_device_row (device.ip_address);
        if (existing != null) {
            list_box.remove (existing);
        }

        var row = new Adw.ActionRow ();
        row.title = device.display_name;
        if (device.hostname != null && device.hostname != device.ip_address) {
            row.subtitle = device.ip_address;
        }

        // Status indicator
        var status = new Gtk.Image ();
        status.icon_name = device.is_online ? "emblem-ok-symbolic" : "emblem-important-symbolic";
        status.add_css_class (device.is_online ? "success" : "error");
        row.add_prefix (status);

        // Favorite button
        var fav_button = new Gtk.Button ();
        fav_button.add_css_class ("flat");
        fav_button.icon_name = "starred-symbolic";
        fav_button.valign = Gtk.Align.CENTER;

        // Initial state
        if (!device.is_favorite) {
            fav_button.remove_css_class ("accent");
        } else {
            fav_button.add_css_class ("accent");
        }

        fav_button.clicked.connect (() => {
            device.is_favorite = !device.is_favorite;
            if (device.is_favorite) {
                fav_button.add_css_class ("accent");
            } else {
                fav_button.remove_css_class ("accent");
            }
        });

        row.add_suffix (fav_button);
        list_box.append (row);
    }

    private Gtk.ListBoxRow? find_device_row (string ip_address) {
        var row = list_box.get_first_child ();
        while (row != null) {
            // Implementation needed
            row = row.get_next_sibling ();
        }
        return null;
    }
}
