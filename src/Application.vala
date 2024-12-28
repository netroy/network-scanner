[CCode (cprefix = "", lower_case_cprefix = "", cheader_filename = "config.h")]
extern const string GETTEXT_PACKAGE;
extern const string LOCALEDIR;

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
    Environment.set_variable ("GSETTINGS_SCHEMA_DIR", "/app/share/glib-2.0/schemas", true);

    Intl.setlocale (LocaleCategory.ALL, "");
    Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
    Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
    Intl.textdomain (GETTEXT_PACKAGE);
  }

  public static int main (string[] args) {
    return new Application ().run (args);
  }
}
