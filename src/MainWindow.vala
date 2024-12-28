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

  [GtkChild]
  private unowned Gtk.SearchEntry search_entry;

  private Gtk.FilterListModel filter_model;
  private Gtk.StringFilter string_filter;
  private Gtk.Button? spinner_button = null;

  public MainWindow (Adw.Application app) {
    Object (application: app);

    scanner = new NetworkScanner ();
    setup_signals ();
    setup_list_box ();
    populate_interfaces.begin ();
  }

  private void setup_list_box () {
    list_box.set_sort_func ((row1, row2) => {
      var device1 = ((Adw.ExpanderRow) row1).title;
      var device2 = ((Adw.ExpanderRow) row2).title;
      return device1.collate (device2);
    });

    // Setup search filtering
    search_entry.search_changed.connect (() => {
      string_filter.search = search_entry.text;
    });
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

  private void cleanup_scan_ui () {
    scan_button.sensitive = true;
    interface_dropdown.sensitive = true;

    if (spinner_button != null) {
      button_box.remove (spinner_button);
      spinner_button = null;
    }

    if (list_box.get_first_child () == null) {
      stack.visible_child_name = "empty";
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
      spinner_button = new Gtk.Button ();
      spinner_button.add_css_class ("circular");
      spinner_button.add_css_class ("flat");
      spinner_button.tooltip_text = _("Click to stop scanning");

      var spinner = new Adw.Spinner ();
      spinner_button.set_child (spinner);

      spinner_button.clicked.connect (() => {
        debug ("Stop button clicked, initiating scan cancellation");
        scanner.cancel_scan ();
        // Don't cleanup UI here, wait for the scan to actually finish
      });

      button_box.prepend (spinner_button);
      stack.visible_child_name = "list";

      scanner.start_scan.begin (interface_name, (obj, res) => {
        try {
          scanner.start_scan.end (res);
          debug ("Scan completed normally");
        } catch (Error e) {
          warning ("Scan error: %s", e.message);
        } finally {
          debug ("Cleaning up UI after scan");
          cleanup_scan_ui ();
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

    var row = new Adw.ExpanderRow ();

    // Add device type icon
    var type_icon = new Gtk.Image ();
    type_icon.icon_name = device.device_type.get_icon_name ();
    row.add_prefix (type_icon);

    // Title and subtitle
    row.title = device.display_name;
    var subtitle = new StringBuilder ();

    if (device.hostname != null && device.hostname != device.ip_address) {
      subtitle.append (device.ip_address);
    }

    if (device.vendor != null) {
      if (subtitle.len > 0) {
        subtitle.append (" • ");
      }
      subtitle.append (device.vendor);
    }

    if (subtitle.len > 0) {
      row.subtitle = subtitle.str;
    }

    // Add detailed information in the expanded section
    var details_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
    details_box.margin_start = details_box.margin_end = 12;
    details_box.margin_top = details_box.margin_bottom = 6;

    // Device Type
    var type_label = new Gtk.Label (null);
    type_label.xalign = 0;
    type_label.wrap = true;
    type_label.selectable = true;
    type_label.set_markup (@"<b>$(_("Device Type:")))</b> $(device.device_type.to_string ())");
    details_box.append (type_label);

    // IP Address
    var ip_label = new Gtk.Label (null);
    ip_label.xalign = 0;
    ip_label.wrap = true;
    ip_label.selectable = true;
    ip_label.set_markup (@"<b>$(_("IP Address:")))</b> $(device.ip_address)");
    details_box.append (ip_label);

    // MAC Address
    if (device.mac_address != null) {
      var mac_label = new Gtk.Label (null);
      mac_label.xalign = 0;
      mac_label.wrap = true;
      mac_label.selectable = true;
      mac_label.set_markup (@"<b>$(_("MAC Address:")))</b> $(device.mac_address)");
      details_box.append (mac_label);
    }

    // Hostname (if different from display name)
    if (device.hostname != null && device.hostname != device.display_name) {
      var hostname_label = new Gtk.Label (null);
      hostname_label.xalign = 0;
      hostname_label.wrap = true;
      hostname_label.selectable = true;
      hostname_label.set_markup (@"<b>$(_("Hostname:")))</b> $(device.hostname)");
      details_box.append (hostname_label);
    }

    // Vendor information
    if (device.vendor != null) {
      var vendor_label = new Gtk.Label (null);
      vendor_label.xalign = 0;
      vendor_label.wrap = true;
      vendor_label.selectable = true;
      vendor_label.set_markup (@"<b>$(_("Vendor:")))</b> $(device.vendor)");
      details_box.append (vendor_label);
    }

    row.add_row (details_box);
    list_box.append (row);
  }

  private Gtk.ListBoxRow? find_device_row (string ip_address) {
    var row = list_box.get_first_child ();
    while (row != null) {
      if (row is Adw.ExpanderRow) {
        var expander_row = (Adw.ExpanderRow) row;
        if (expander_row.subtitle != null && expander_row.subtitle.contains (ip_address)) {
          return (Gtk.ListBoxRow) row;
        }
      }
      row = row.get_next_sibling ();
    }
    return null;
  }
}
