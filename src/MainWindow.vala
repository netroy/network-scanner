public class NetworkScanner.MainWindow : Gtk.ApplicationWindow {
  public MainWindow (Gtk.Application app) {
    Object (
      application: app,
      title: "Network Scanner",
      default_width: 600,
      default_height: 400
    );

    // Create a basic layout
    var main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
    main_box.margin_start = main_box.margin_end = 12;
    main_box.margin_top = main_box.margin_bottom = 12;

    var header = new Gtk.HeaderBar ();
    set_titlebar (header);

    var scan_button = new Gtk.Button.with_label ("Scan Network");
    header.pack_start (scan_button);

    // Add a list box to show results
    var list_box = new Gtk.ListBox ();
    var scrolled = new Gtk.ScrolledWindow ();
    scrolled.set_child (list_box);
    main_box.append (scrolled);

    set_child (main_box);
  }
}
