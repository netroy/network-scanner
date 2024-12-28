namespace NetworkScanner {
  public class NetworkScanner : Object {
    private bool is_scanning = false;
    private Cancellable cancellable;
    private Regex mac_regex;
    private File vendor_db;
    private HashTable<string, string> vendor_cache;
    private Timer scan_timer;

    // Statistics
    private int total_devices = 0;
    private int enriched_devices = 0;
    private int hostname_lookups = 0;
    private int vendor_lookups = 0;
    private uint status_timeout_id = 0;

    public signal void device_discovered (NetworkDevice device);

    construct {
      cancellable = new Cancellable ();
      vendor_cache = new HashTable<string, string> (str_hash, str_equal);
      scan_timer = new Timer ();
      try {
        mac_regex = new Regex ("([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})", RegexCompileFlags.OPTIMIZE);
        load_vendor_database.begin ();
      } catch (Error e) {
        warning ("Error creating MAC regex: %s", e.message);
      }
    }

    private void reset_statistics () {
      total_devices = 0;
      enriched_devices = 0;
      hostname_lookups = 0;
      vendor_lookups = 0;
      scan_timer.start ();
    }

    private void log_scan_status () {
      double elapsed = scan_timer.elapsed ();
      string phase = enriched_devices < total_devices ? "Enriching" : "Complete";

      debug ("Scan Status [%.1fs] - %s", elapsed, phase);
      debug ("  Devices found: %d", total_devices);
      debug ("  Devices enriched: %d/%d (%.1f%%)",
        enriched_devices, total_devices,
        total_devices > 0 ? (enriched_devices * 100.0) / total_devices : 0.0
      );
      debug ("  Hostname lookups: %d", hostname_lookups);
      debug ("  Vendor lookups: %d", vendor_lookups);

      if (enriched_devices < total_devices && is_scanning) {
        double rate = enriched_devices / elapsed;
        double remaining = (total_devices - enriched_devices) / rate;
        debug ("  Estimated remaining time: %.1f seconds", remaining);
      }
    }

    private async void load_vendor_database () {
      vendor_db = File.new_for_path ("/usr/share/arp-scan/ieee-oui.txt");
      if (!vendor_db.query_exists ()) {
        warning ("Vendor database not found at %s", vendor_db.get_path ());
        return;
      }

      try {
        var input = new DataInputStream (yield vendor_db.read_async ());
        string line;
        var count = 0;
        while ((line = yield input.read_line_async ()) != null) {
          if (line.length > 8) {
            var parts = line.split ("\t", 2);
            if (parts.length == 2) {
              vendor_cache.insert (parts[0].up (), parts[1]);
              count++;
            }
          }
        }
        debug ("Loaded %d vendor entries", count);
      } catch (Error e) {
        warning ("Error loading vendor database: %s", e.message);
      }
    }

    public async string[] get_local_interfaces () {
      string[] interfaces = {};
      try {
        var file = File.new_for_path ("/proc/net/dev");
        var input = yield file.read_async ();
        var reader = new DataInputStream (input);

        string line;
        yield reader.read_line_async (); // Skip header
        yield reader.read_line_async (); // Skip header

        while ((line = yield reader.read_line_async ()) != null) {
          var parts = line.strip ().split (":");
          if (parts.length > 1) {
            string iface = parts[0].strip ();
            if (!should_skip_interface (iface)) {
              interfaces += iface;
            }
          }
        }
      } catch (Error e) {
        warning ("Error getting interfaces: %s", e.message);
      }
      return interfaces;
    }

    private bool should_skip_interface (string iface) {
      string[] skip_prefixes = {
        "lo", "docker", "br-", "veth", "virbr", "vnet",
        "tun", "tap", "tailscale"
      };
      foreach (var prefix in skip_prefixes) {
        if (iface.has_prefix (prefix)) return true;
      }
      return iface.contains ("_gwbridge");
    }

    private string? lookup_vendor (string mac_address) {
      if (mac_address == null || mac_address.length < 6) return null;

      string clean_mac = mac_address.replace (":", "").replace ( "-", "");
      string prefix = clean_mac.substring (0, 6).up ();

      vendor_lookups++;
      var vendor = vendor_cache.lookup (prefix);
      if (vendor != null) {
        debug ("Found vendor for MAC %s: %s", mac_address, vendor);
      }
      return vendor;
    }

    private async string? get_hostname (string ip_address) {
      if (!is_scanning) {
        debug ("Hostname lookup cancelled for %s: scan stopped", ip_address);
        return null;
      }

      try {
        hostname_lookups++;
        var resolver = Resolver.get_default ();
        var names = yield resolver.lookup_by_address_async (
          new InetAddress.from_string (ip_address)
        );
        if (!is_scanning) {
          debug ("Hostname lookup cancelled for %s after resolution: scan stopped", ip_address);
          return null;
        }
        if (names != null && names.length > 0) {
          var hostname = names[0].to_string ();
          debug ("Resolved hostname for %s: %s", ip_address, hostname);
          return hostname;
        }
      } catch (Error e) {
        if (!(e is ResolverError.NOT_FOUND || e is ResolverError.TEMPORARY_FAILURE)) {
          warning ("Hostname lookup failed for %s: %s", ip_address, e.message);
        }
      }
      return null;
    }

    private async void scan_network (string interface_name) throws Error {
      var devices = new GenericArray<NetworkDevice> ();
      var discovery_timer = new Timer ();

      // Fast device discovery from /proc/net/arp
      try {
        debug ("Starting fast device discovery…");
        var file = File.new_for_path ("/proc/net/arp");
        var input = yield file.read_async ();
        var reader = new DataInputStream (input);

        // Skip header line
        yield reader.read_line_async ();

        string? line;
        while ((line = yield reader.read_line_async ()) != null && is_scanning) {
          // Format: IP address       HW type     Flags       HW address            Mask     Device
          var parts = line.strip ().split (" ", 0);  // Split on space, remove empty parts
          // Filter out empty strings
          string[] valid_parts = {};
          foreach (var part in parts) {
            if (part.strip () != "") {
              valid_parts += part.strip ();
            }
          }

          if (valid_parts.length >= 4) {
            var ip = valid_parts[0];
            var mac = valid_parts[3].up ();
            var flags = valid_parts[2];
            var iface = valid_parts.length >= 6 ? valid_parts[5] : null;

            // Only process devices from the selected interface and with valid flags
            if (iface == interface_name && flags != "0x0") {
              var device = new NetworkDevice (ip);
              device.mac_address = mac;
              devices.add (device);
              total_devices++;
              debug ("Found device: IP=%s MAC=%s", ip, mac);
            }
          }
        }

        if (!is_scanning) {
          debug ("Device discovery cancelled after processing %d devices", total_devices);
          return;
        }

        debug ("Initial discovery completed in %.3fs, found %d devices",
          discovery_timer.elapsed (), total_devices);

      } catch (Error e) {
        warning ("Error reading ARP cache: %s", e.message);
        throw e;
      }

      if (total_devices == 0) {
        debug ("No devices found in ARP cache");
        return;
      }

      // Start periodic status updates
      status_timeout_id = Timeout.add_seconds (2, () => {
        if (is_scanning) {
          log_scan_status ();
          return Source.CONTINUE;
        }
        return Source.REMOVE;
      });

      // Process additional info in batches
      debug ("Starting device enrichment…");
      var batch_size = 5;
      var batch_number = 1;

      for (int i = 0; i < total_devices && !cancellable.is_cancelled () && is_scanning; i += batch_size) {
        var batch_timer = new Timer ();
        var batch_processed = 0;
        var current_batch_size = int.min (batch_size, total_devices - i);

        debug ("Processing batch %d (%d devices)…", batch_number, current_batch_size);

        // Process batch in parallel
        for (int j = 0; j < current_batch_size && is_scanning; j++) {
          var device = devices.get (i + j);
          enrich_device.begin (device, (obj, res) => {
            try {
              enrich_device.end (res);
              enriched_devices++;
              device_discovered (device);
            } catch (Error e) {
              warning ("Failed to enrich device data: %s", e.message);
            }
            batch_processed++;
          });
        }

        // Wait for batch to complete
        while (batch_processed < current_batch_size && !cancellable.is_cancelled () && is_scanning) {
          yield;
        }

        if (!is_scanning) {
          debug ("Scan cancelled during batch %d (%d/%d devices enriched)",
            batch_number, enriched_devices, total_devices);
          break;
        }

        debug ("Batch %d completed in %.3fs", batch_number, batch_timer.elapsed ());
        batch_number++;
      }

      if (status_timeout_id > 0) {
        Source.remove (status_timeout_id);
        status_timeout_id = 0;
      }

      if (!is_scanning) {
        debug ("Scan cancelled after processing %d/%d devices", enriched_devices, total_devices);
      } else {
        debug ("Scan completed in %.3fs", scan_timer.elapsed ());
      }
      log_scan_status ();
    }

    private async void enrich_device (NetworkDevice device) throws Error {
      if (!is_scanning) {
        debug ("Device enrichment cancelled for %s: scan stopped", device.ip_address);
        return;
      }

      var timer = new Timer ();

      // Add vendor info
      device.vendor = lookup_vendor (device.mac_address);

      if (!is_scanning) {
        debug ("Device enrichment cancelled for %s after vendor lookup: scan stopped", device.ip_address);
        return;
      }

      // Add hostname
      device.hostname = yield get_hostname (device.ip_address);

      if (!is_scanning) {
        debug ("Device enrichment cancelled for %s after hostname lookup: scan stopped", device.ip_address);
        return;
      }

      // Detect device type
      device.detect_device_type ();

      debug ("Enriched device in %.3fs: IP=%s MAC=%s Vendor=%s Hostname=%s",
        timer.elapsed (),
        device.ip_address,
        device.mac_address,
        device.vendor ?? "unknown",
        device.hostname ?? "none"
      );
    }

    public async void start_scan (string interface_name) throws Error {
      if (is_scanning) return;
      is_scanning = true;

      reset_statistics ();
      debug ("Starting network scan on interface %s", interface_name);

      cancellable.reset ();

      try {
        yield scan_network (interface_name);
      } catch (Error e) {
        warning ("Scan error: %s", e.message);
        throw e;
      } finally {
        is_scanning = false;
        debug ("Scan finished");
      }
    }

    public void cancel_scan () {
      if (is_scanning) {
        debug ("Cancelling scan");
        is_scanning = false;
        cancellable.cancel ();
      }
    }
  }
}
