# macNetty 🌐🍎

> **A beautiful, interactive CLI wizard for macOS network configuration and auto-switching**

macNetty simplifies network management for macOS users by providing an elegant command-line interface to create location-based network profiles and automatically switch between them based on your Wi-Fi connection.

![macOS](https://img.shields.io/badge/macOS-10.12+-blue.svg)
![Bash](https://img.shields.io/badge/bash-4.0+-green.svg)
![License](https://img.shields.io/badge/license-MIT-blue.svg)

## ✨ Features
- 🔧 **Network Profile Management** - Create location-based profiles for different Wi-Fi networks
- 📡 **Static IP Configuration** - Set custom IP addresses, gateways, and subnet masks
- 🔐 **Proxy Support** - Configure HTTP/HTTPS proxies per network location
- 🔄 **Auto-Switching** - Automatically switch network profiles when connecting to different Wi-Fi networks
- 🍏 **Apple Silicon Compatible** - Uses `ipconfig` for M1/M2/M3 Mac compatibility
- 🚫 **Zero Dependencies** - Pure Bash - no Python, Node.js, or external libraries required
- 🎨 **Beautiful CLI Interface** - Color-coded output with ASCII art for a modern terminal experience

## 🚀 Quick Start

### Prerequisites

- macOS 10.12 or later
- Administrator (sudo) access

### Installation

1. **Download macNetty:**
   ```bash
   curl -O https://raw.githubusercontent.com/yourusername/macNetty/main/macNetty.sh
   chmod +x macNetty.sh
   ```

2. **Run the wizard:**
   ```bash
   sudo ./macNetty.sh
   ```

That's it! No compilation, no dependencies, no package managers.

## 📖 Usage

### Main Menu Options

When you run macNetty, you'll see three options:

```
[1] Create New Network Profile
[2] Install Auto-Switcher (Set & Forget)
[3] Exit
```

### Option 1: Create New Network Profile

Create a custom network configuration for a specific Wi-Fi network:

1. Enter the exact Wi-Fi SSID (network name)
2. Choose whether to use Static IP (optional)
   - Enter IP Address, Gateway, and Subnet Mask
3. Choose whether to configure a Proxy (optional)
   - Enter Proxy Host and Port

**Example Use Case:** Configure your office Wi-Fi with a static IP and proxy, while your home Wi-Fi uses DHCP.

### Option 2: Install Auto-Switcher

Set up automatic network profile switching:

- Monitors your Wi-Fi connection every 10 seconds
- Automatically switches to the matching network profile when you connect to a known Wi-Fi network
- Runs silently in the background via macOS LaunchAgent
- Logs activity to `/tmp/wifichanger.log`

**Perfect for:** Users who frequently move between home, office, coffee shops, etc.

## 🔧 How It Works

### Network Profiles

macNetty uses macOS's built-in **Network Locations** feature (`networksetup`) to create and manage profiles. Each Wi-Fi SSID gets its own location with custom settings.

### Auto-Switching

The auto-switcher works by:

1. Creating a monitor script (`~/.locationchanger/monitor.sh`)
2. Installing a LaunchAgent that runs the script every 10 seconds
3. Comparing current Wi-Fi SSID to current network location
4. Switching locations automatically when they don't match

The monitor script uses `ipconfig getsummary en0` for Apple Silicon compatibility, ensuring it works on both Intel and ARM-based Macs.

## 📝 Examples

### Configure Static IP for Office Network

```bash
sudo ./macNetty.sh
# Select [1] Create New Network Profile
# Enter SSID: OfficeWiFi
# Static IP? y
# IP: 192.168.10.100
# Gateway: 192.168.10.1
# Subnet: 255.255.255.0
# Proxy? n
```

### Setup Auto-Switching

```bash
sudo ./macNetty.sh
# First, create profiles for each network (option 1)
# Then select [2] Install Auto-Switcher
# Done! Your Mac will now auto-switch
```


## 🐛 Troubleshooting

### Auto-switcher not working?

Check if the LaunchAgent is running:
```bash
launchctl list | grep wifichanger
```

View logs:
```bash
tail -f /tmp/wifichanger.log
```

### Permission errors?

Make sure you're running with `sudo`:
```bash
sudo ./macNetty.sh
```

### Network not switching?

Verify the location was created:
```bash
networksetup -listlocations
```

Check current location:
```bash
networksetup -getcurrentlocation
```

## 🤝 Contributing

Contributions are welcome! Here's how you can help:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Ideas for Contributions

- DNS server configuration
- IPv6 support
- VPN integration
- Export/import profiles
- GUI wrapper
- Homebrew formula

## 📄 License

This project is licensed under the MIT License.


## 🙏 Acknowledgments

The Wi-Fi network based automation tool is inspired by [eprev's locationchanger script](https://github.com/eprev/locationchanger). Thanks for your contribution!


## 📬 Support

If you find macNetty useful, please:
- ⭐ Star this repository
- 🐛 Report bugs via Issues
- 💡 Suggest features via Issues
- 📢 Share with others who might benefit

---


**Made with ❤️ for Mac users who love the terminal**
