public enum DeviceType {
  UNKNOWN,
  ROUTER,
  COMPUTER,
  LAPTOP,
  PHONE,
  TABLET,
  TV,
  PRINTER,
  IOT;

  public string to_string () {
    switch (this) {
      case ROUTER:
        return _("Router");
      case COMPUTER:
        return _("Computer");
      case LAPTOP:
        return _("Laptop");
      case PHONE:
        return _("Phone");
      case TABLET:
        return _("Tablet");
      case TV:
        return _("TV");
      case PRINTER:
        return _("Printer");
      case IOT:
        return _("IoT Device");
      default:
        return _("Unknown");
    }
  }

  public string get_icon_name () {
    switch (this) {
      case ROUTER:
        return "network-wireless-symbolic";
      case COMPUTER:
        return "computer-symbolic";
      case LAPTOP:
        return "computer-laptop-symbolic";
      case PHONE:
        return "phone-symbolic";
      case TABLET:
        return "tablet-symbolic";
      case TV:
        return "tv-symbolic";
      case PRINTER:
        return "printer-symbolic";
      case IOT:
        return "smart-home-symbolic";
      default:
        return "network-workstation-symbolic";
    }
  }
}

public class NetworkDevice : Object {
  public string ip_address { get; set; }
  public string? mac_address { get; set; default = null; }
  public string? hostname { get; set; }
  public string? vendor { get; set; }
  public DeviceType device_type { get; private set; default = DeviceType.UNKNOWN; }

  public string display_name {
    get {
      return hostname ?? ip_address;
    }
  }

  public NetworkDevice (string ip_address) {
    Object (ip_address: ip_address);
  }

  public void detect_device_type () {
    // Try to detect device type from hostname
    if (hostname != null) {
      string lower_hostname = hostname.down ();

      if (lower_hostname.contains ("router") || lower_hostname.contains ("gateway") || lower_hostname.contains ("ap")) {
        device_type = DeviceType.ROUTER;
        return;
      }

      if (lower_hostname.contains ("phone") || lower_hostname.contains ("android") || lower_hostname.contains ("iphone")) {
        device_type = DeviceType.PHONE;
        return;
      }

      if (lower_hostname.contains ("laptop")) {
        device_type = DeviceType.LAPTOP;
        return;
      }

      if (lower_hostname.contains ("tv") || lower_hostname.contains ("shield") || lower_hostname.contains ("roku")) {
        device_type = DeviceType.TV;
        return;
      }

      if (lower_hostname.contains ("print")) {
        device_type = DeviceType.PRINTER;
        return;
      }
    }

    // Try to detect from MAC address vendor
    if (vendor != null) {
      string lower_vendor = vendor.down ();

      if (lower_vendor.contains ("raspberry") || lower_vendor.contains ("arduino") || lower_vendor.contains ("espressif")) {
        device_type = DeviceType.IOT;
        return;
      }

      if (lower_vendor.contains ("apple")) {
        // Further detect Apple device type
        if (hostname != null && hostname.down ().contains ("iphone")) {
          device_type = DeviceType.PHONE;
        } else if (hostname != null && hostname.down ().contains ("ipad")) {
          device_type = DeviceType.TABLET;
        } else {
          device_type = DeviceType.COMPUTER;
        }
        return;
      }

      if (lower_vendor.contains ("samsung") || lower_vendor.contains ("lg")) {
        if (hostname != null && (hostname.down ().contains ("tv") || hostname.down ().contains ("smart"))) {
          device_type = DeviceType.TV;
        }
        return;
      }
    }

    // Default to computer if we couldn't determine the type
    device_type = DeviceType.COMPUTER;
  }
}
