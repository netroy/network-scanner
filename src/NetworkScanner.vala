public class NetworkScanner.NetworkScanner : Object {
  public signal void device_discovered (NetworkDevice device);

  private bool scanning = false;
  private Subprocess? current_scan = null;
  private Cancellable? cancellable = null;

  public NetworkScanner () {
  }

  public async void start_scan (string interface_name) throws Error {
    if (scanning) {
      return;
    }

    scanning = true;
    cancellable = new Cancellable ();

    try {
      // Create subprocess asynchronously
      current_scan = new Subprocess.newv ({
        "arp-scan",
        "--interface=" + interface_name,
        "--localnet"
      }, SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);

      // Create data input streams
      var stdout_pipe = current_scan.get_stdout_pipe ();
      var stdout_stream = new DataInputStream (stdout_pipe);

      // Start reading output asynchronously
      while (true) {
        if (cancellable.is_cancelled ()) {
          break;
        }

        string? line = yield stdout_stream.read_line_async (Priority.DEFAULT, cancellable);
        if (line == null) break;

        if (line.strip () == "") continue;
        if (line.contains ("Interface:")) continue;
        if (line.contains ("Starting")) continue;
        if (line.contains ("packets")) continue;

        var fields = line.strip ().split ("\t");
        if (fields.length >= 2) {
          var ip = fields[0].strip ();
          var mac = fields[1].strip ();

          var device = new NetworkDevice (ip);
          device.mac_address = mac;
          device.is_online = true;

          // Start an async hostname lookup
          lookup_hostname.begin (device);

          device_discovered (device);
        }
      }

      if (!cancellable.is_cancelled ()) {
        yield current_scan.wait_check_async (cancellable);
      }

    } catch (Error e) {
      if (!(e is IOError.CANCELLED)) {
        warning ("Error scanning network: %s", e.message);
        throw e;
      }
    } finally {
      if (current_scan != null) {
        current_scan.force_exit ();
        current_scan = null;
      }
      cancellable = null;
      scanning = false;
    }
  }

  public void cancel_scan () {
    if (cancellable != null) {
      cancellable.cancel ();
    }
  }

  public async List<string> get_local_interfaces () {
    var interfaces = new List<string> ();

    try {
      // Create subprocess for interface listing
      var subprocess = new Subprocess.newv ({
        "ip",
        "-brief",
        "link",
        "show"
      }, SubprocessFlags.STDOUT_PIPE);

      // Get output asynchronously
      var stdout_pipe = subprocess.get_stdout_pipe ();
      var stdout_stream = new DataInputStream (stdout_pipe);

      while (true) {
        string? line = yield stdout_stream.read_line_async (Priority.DEFAULT, null);
        if (line == null) break;

        if (line.strip () == "") continue;

        var parts = line.strip ().split (" ", 2);
        if (parts.length > 0) {
          var iface = parts[0];
          // Skip loopback, docker, bridge, and virtual interfaces
          if (iface != "lo" &&
              !iface.contains ("docker") &&
              !iface.contains ("veth") &&
              !iface.contains ("br") &&
              !iface.contains ("bridge")) {
            interfaces.append (iface.dup ());
          }
        }
      }

      yield subprocess.wait_check_async ();

    } catch (Error e) {
      warning ("Error getting network interfaces: %s", e.message);
    }

    return interfaces;
  }

  private async void lookup_hostname (NetworkDevice device) {
    try {
      var resolver = GLib.Resolver.get_default ();
      var name = yield resolver.lookup_by_address_async (new InetAddress.from_string (device.ip_address));
      if (name != null) {
        device.hostname = name;
        device_discovered (device);  // Re-emit to update UI
      }
    } catch (Error e) {
      // Ignore resolution errors
    }
  }
}
