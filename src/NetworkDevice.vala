public class NetworkScanner.NetworkDevice : Object {
    public string ip_address { get; set; }
    public string? hostname { get; set; }
    public string? mac_address { get; set; }
    public bool is_online { get; set; }
    public bool is_favorite { get; set; }

    public NetworkDevice (string ip_address) {
        Object (
            ip_address: ip_address,
            is_online: false,
            is_favorite: false
        );
    }

    public string display_name {
        get {
            return hostname ?? ip_address;
        }
    }
}
