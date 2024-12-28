public class NetworkScanner.Application : Adw.Application {
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

  protected override void startup () {
    base.startup ();
    Adw.init ();

    // Initialize internationalization support
    Intl.setlocale (LocaleCategory.ALL, "");
    Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.LOCALEDIR);
    Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");
    Intl.textdomain (Config.GETTEXT_PACKAGE);
  }

  public static int main (string[] args) {
    return new Application ().run (args);
  }
}
