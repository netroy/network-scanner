[CCode (cprefix = "", lower_case_cprefix = "", cheader_filename = "config.h")]
extern const string GETTEXT_PACKAGE;
extern const string LOCALEDIR;

public class NetworkScanner.MainWindow : Adw.ApplicationWindow {
  private NetworkScanner scanner;
  private Gtk.ListBox list_box;
  private Gtk.Button scan_button;
  private Gtk.Image scan_icon;
  private Gtk.DropDown interface_dropdown;
  private Gtk.Box button_box;

  public MainWindow (Adw.Application app) {
    Object (
      application: app,
      default_width: 600,
      default_height: 400,
      width_request: 360  // Minimum width for mobile
    );

    scanner = new NetworkScanner ();
    setup_ui ();
    setup_signals ();
    populate_interfaces.begin ();
  }

  private void setup_ui () {
    var main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

    // Header Bar
    var header = new Adw.HeaderBar ();
    header.add_css_class ("flat");
    header.show_title = false;

    // Interface dropdown with title in a clamp for responsiveness
    var interfaces_model = new Gtk.StringList (null);
    interface_dropdown = new Gtk.DropDown (interfaces_model, null);
    interface_dropdown.set_enable_search (false);

    var dropdown_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
    var interface_label = new Gtk.Label (_("Interface:"));
    interface_label.add_css_class ("dim-label");
    dropdown_box.append (interface_label);
    dropdown_box.append (interface_dropdown);

    var dropdown_clamp = new Adw.Clamp ();
    dropdown_clamp.maximum_size = 400;
    dropdown_clamp.tightening_threshold = 300;
    dropdown_clamp.child = dropdown_box;

    // Scan button with icon
    scan_button = new Gtk.Button ();
    scan_button.add_css_class ("suggested-action");
    var scan_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
    scan_icon = new Gtk.Image.from_icon_name ("system-search-symbolic");
    var scan_label = new Gtk.Label (_("Scan Network"));
    scan_box.append (scan_icon);
    scan_box.append (scan_label);
    scan_button.set_child (scan_box);
    scan_button.sensitive = false;

    // Container for spinner and button
    button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
    button_box.append (scan_button);

    header.pack_start (dropdown_clamp);
    header.pack_end (button_box);
    main_box.append (header);

    // Content Area
    var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
    content.add_css_class ("content");

    // Status page for empty state
    var status_page = new Adw.StatusPage ();
    status_page.icon_name = "network-wired-symbolic";
    status_page.title = _("Network Scanner");
    status_page.description = _("Select an interface and click Scan to discover devices on your network");

    // List box setup...
    list_box = new Gtk.ListBox ();
    list_box.add_css_class ("boxed-list");
    list_box.set_selection_mode (Gtk.SelectionMode.NONE);

    var scrolled = new Gtk.ScrolledWindow ();
    scrolled.set_child (list_box);
    scrolled.margin_start = scrolled.margin_end = 12;
    scrolled.margin_top = scrolled.margin_bottom = 12;
    scrolled.vexpand = true;

    var list_clamp = new Adw.Clamp ();
    list_clamp.maximum_size = 800;
    list_clamp.tightening_threshold = 600;
    list_clamp.child = scrolled;

    var stack = new Gtk.Stack ();
    stack.add_named (status_page, "empty");
    stack.add_named (list_clamp, "list");
    stack.transition_type = Gtk.StackTransitionType.CROSSFADE;

    content.append (stack);
    main_box.append (content);

    stack.visible_child_name = "empty";

    set_content (main_box);
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

      var stack = (Gtk.Stack) list_box.get_ancestor (typeof (Gtk.Stack));
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
      var stack = (Gtk.Stack) list_box.get_ancestor (typeof (Gtk.Stack));
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
