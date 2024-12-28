public class NetworkScanner.Application : Gtk.Application {
  public Application () {
    Object (
      application_id: "in.netroy.network-scanner",
      flags: ApplicationFlags.FLAGS_NONE
    );
  }

  protected override void activate () {
    var main_window = new MainWindow (this);
    main_window.present ();
  }

  public static int main (string[] args) {
    return new Application ().run (args);
  }
}
