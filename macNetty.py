#!/usr/bin/env python3
"""
NetConfig.py - macOS Network Configuration Wizard
A user-friendly CLI tool for managing network profiles and auto-switching
"""

import sys
import os
import subprocess
import time

# ANSI Color Codes
class Colors:
    RESET = '\033[0m'
    BOLD = '\033[1m'
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    MAGENTA = '\033[95m'
    CYAN = '\033[96m'
    WHITE = '\033[97m'


def print_header():
    """Display ASCII art header with branding"""
    header = f"""
{Colors.CYAN}{Colors.BOLD}
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║   ███╗   ██╗███████╗████████╗ ██████╗ ██████╗ ███╗   ██╗ ║
║   ████╗  ██║██╔════╝╚══██╔══╝██╔════╝██╔═══██╗████╗  ██║ ║
║   ██╔██╗ ██║█████╗     ██║   ██║     ██║   ██║██╔██╗ ██║ ║
║   ██║╚██╗██║██╔══╝     ██║   ██║     ██║   ██║██║╚██╗██║ ║
║   ██║ ╚████║███████╗   ██║   ╚██████╗╚██████╔╝██║ ╚████║ ║
║   ╚═╝  ╚═══╝╚══════╝   ╚═╝    ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝ ║
║                                                           ║
║          macOS Network Configuration Wizard v1.0          ║
║              Simplifying Network Management               ║
╚═══════════════════════════════════════════════════════════╝
{Colors.RESET}
"""
    print(header)


def print_success(message):
    """Print success message in green"""
    print(f"{Colors.GREEN}✓ {message}{Colors.RESET}")


def print_error(message):
    """Print error message in red"""
    print(f"{Colors.RED}✗ {message}{Colors.RESET}")


def print_warning(message):
    """Print warning message in yellow"""
    print(f"{Colors.YELLOW}⚠ {message}{Colors.RESET}")


def print_info(message):
    """Print info message in cyan"""
    print(f"{Colors.CYAN}ℹ {message}{Colors.RESET}")


def print_prompt(message):
    """Print prompt message in yellow bold"""
    return f"{Colors.YELLOW}{Colors.BOLD}{message}{Colors.RESET}"


def check_root_privileges():
    """Verify script is running with root privileges"""
    if os.geteuid() != 0:
        print_error("This script requires root privileges to configure network settings.")
        print_info("Please run with sudo:")
        print(f"\n    {Colors.BOLD}sudo python3 NetConfig.py{Colors.RESET}\n")
        sys.exit(1)
    print_success("Running with root privileges")


def run_command(command, capture_output=True, check=True):
    """Execute shell command with error handling"""
    try:
        if capture_output:
            result = subprocess.run(
                command,
                shell=True,
                capture_output=True,
                text=True,
                check=check
            )
            return result.stdout.strip()
        else:
            subprocess.run(command, shell=True, check=check)
            return None
    except subprocess.CalledProcessError as e:
        print_error(f"Command failed: {command}")
        if e.stderr:
            print_error(f"Error: {e.stderr}")
        return None


def get_user_input(prompt, default=None):
    """Get user input with optional default value"""
    if default:
        prompt_text = f"{prompt} [{default}]: "
    else:
        prompt_text = f"{prompt}: "
    
    user_input = input(print_prompt(prompt_text)).strip()
    
    if not user_input and default:
        return default
    return user_input


def get_yes_no(prompt, default='N'):
    """Get yes/no input from user"""
    response = get_user_input(f"{prompt} [y/N]" if default == 'N' else f"{prompt} [Y/n]", default).lower()
    return response in ['y', 'yes']


def show_progress(message, duration=2):
    """Display animated progress indicator"""
    print(f"\n{Colors.CYAN}{message}", end='', flush=True)
    for _ in range(duration * 4):
        print(".", end='', flush=True)
        time.sleep(0.25)
    print(f" Done!{Colors.RESET}\n")


def get_network_interface():
    """Detect primary Wi-Fi network interface"""
    # Try common interfaces
    interfaces = ['en0', 'en1']
    for iface in interfaces:
        result = run_command(f"networksetup -listallhardwareports | grep -A 1 Wi-Fi | grep 'Device:' | awk '{{print $2}}'")
        if result:
            return result
    return 'en0'


def create_network_profile():
    """Create a new network location profile"""
    print(f"\n{Colors.BOLD}{Colors.MAGENTA}══════════════════════════════════════════{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}   CREATE NEW NETWORK PROFILE{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}══════════════════════════════════════════{Colors.RESET}\n")
    
    # Get SSID
    ssid = get_user_input("Enter the Wi-Fi Name (SSID) exactly")
    if not ssid:
        print_error("SSID cannot be empty!")
        return
    
    location_name = ssid 
    
    existing_locations = run_command("networksetup -listlocations")
    if location_name in existing_locations:
        print_warning(f"Location '{location_name}' already exists!")
        if not get_yes_no("Do you want to delete it and recreate?", 'N'):
            return
        run_command(f"networksetup -deletelocation '{location_name}'")
    
    print_info(f"Creating network location: {location_name}")
    result = run_command(f"networksetup -createlocation '{location_name}' populate")
    if result is None:
        print_error("Failed to create location")
        return
    
    show_progress("Setting up location", 1)
    
    run_command(f"networksetup -switchtolocation '{location_name}'")
    print_success(f"Switched to location: {location_name}")
    
    interface = get_network_interface()
    service_name = "Wi-Fi"
    
    # Configure Static IP if needed
    if get_yes_no("Do you need a Static IP?", 'N'):
        print(f"\n{Colors.CYAN}Static IP Configuration:{Colors.RESET}")
        ip_address = get_user_input("Enter IP Address (e.g., 192.168.1.100)")
        router = get_user_input("Enter Router/Gateway (e.g., 192.168.1.1)")
        subnet = get_user_input("Enter Subnet Mask", "255.255.255.0")
        
        if ip_address and router:
            print_info("Applying static IP configuration...")
            cmd = f"networksetup -setmanual '{service_name}' {ip_address} {subnet} {router}"
            if run_command(cmd) is not None:
                print_success(f"Static IP configured: {ip_address}")
            else:
                print_error("Failed to set static IP")
    else:
        run_command(f"networksetup -setdhcp '{service_name}'")
        print_success("Using DHCP (Automatic IP)")
    
    # Configure Proxy if needed
    if get_yes_no("Do you need a Proxy?", 'N'):
        print(f"\n{Colors.CYAN}Proxy Configuration:{Colors.RESET}")
        proxy_host = get_user_input("Enter Proxy Host/IP")
        proxy_port = get_user_input("Enter Proxy Port")
        
        if proxy_host and proxy_port:
            print_info("Applying proxy configuration...")
            cmd = f"networksetup -setwebproxy '{service_name}' {proxy_host} {proxy_port}"
            run_command(cmd)
            cmd = f"networksetup -setsecurewebproxy '{service_name}' {proxy_host} {proxy_port}"
            run_command(cmd)
            print_success(f"Proxy configured: {proxy_host}:{proxy_port}")
    
    show_progress("Finalizing configuration", 1)
    
    print(f"\n{Colors.GREEN}{Colors.BOLD}╔════════════════════════════════════════╗")
    print(f"║   Profile Created Successfully! ✓      ║")
    print(f"╚════════════════════════════════════════╝{Colors.RESET}\n")
    print_info(f"Location: {location_name}")
    print_info("Your network profile is now active!")


def install_auto_switcher():
    """Install Wi-Fi auto-switcher with LaunchAgent"""
    print(f"\n{Colors.BOLD}{Colors.MAGENTA}══════════════════════════════════════════{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}   INSTALL AUTO-SWITCHER{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}══════════════════════════════════════════{Colors.RESET}\n")
    
    print_info("This will automatically switch network profiles based on your Wi-Fi network")
    print_info("Scanning every 10 seconds in the background\n")
    
    real_user = os.environ.get('SUDO_USER') or os.environ.get('USER')
    home_dir = os.path.expanduser(f"~{real_user}")
    
    monitor_dir = os.path.join(home_dir, '.locationchanger')
    os.makedirs(monitor_dir, exist_ok=True)
    
    monitor_script = os.path.join(monitor_dir, 'monitor.sh')
    
    script_content = """#!/bin/bash
# Wi-Fi Auto-Switcher Monitor Script
# Automatically switches network location based on current SSID

# Get current SSID using ipconfig (Apple Silicon compatible)
CURRENT_SSID=$(ipconfig getsummary en0 2>/dev/null | awk -F' SSID : ' '{print $2}' | head -n1)

# Fallback to networksetup if ipconfig fails
if [ -z "$CURRENT_SSID" ]; then
    CURRENT_SSID=$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | awk '/ SSID/ {print substr($0, index($0, $2))}')
fi

# Get current location
CURRENT_LOCATION=$(networksetup -getcurrentlocation)

# If SSID is empty, we're not connected to Wi-Fi
if [ -z "$CURRENT_SSID" ]; then
    exit 0
fi

# If current location doesn't match SSID, switch to it
if [ "$CURRENT_SSID" != "$CURRENT_LOCATION" ]; then
    # Check if location exists
    if networksetup -listlocations | grep -q "^${CURRENT_SSID}$"; then
        networksetup -switchtolocation "$CURRENT_SSID"
        logger "NetConfig Auto-Switcher: Switched to location '$CURRENT_SSID'"
    fi
fi
"""
    
    try:
        with open(monitor_script, 'w') as f:
            f.write(script_content)
        os.chmod(monitor_script, 0o755)
        print_success(f"Monitor script created: {monitor_script}")
    except Exception as e:
        print_error(f"Failed to create monitor script: {e}")
        return
    
    # Create LaunchAgent plist
    launch_agent_dir = os.path.join(home_dir, 'Library', 'LaunchAgents')
    os.makedirs(launch_agent_dir, exist_ok=True)
    
    plist_path = os.path.join(launch_agent_dir, 'com.user.wifichanger.plist')
    
    plist_content = f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.wifichanger</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>{monitor_script}</string>
    </array>
    
    <key>StartInterval</key>
    <integer>10</integer>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>StandardOutPath</key>
    <string>/tmp/wifichanger.log</string>
    
    <key>StandardErrorPath</key>
    <string>/tmp/wifichanger.error.log</string>
</dict>
</plist>
"""
    
    try:
        with open(plist_path, 'w') as f:
            f.write(plist_content)
        print_success(f"LaunchAgent created: {plist_path}")
    except Exception as e:
        print_error(f"Failed to create LaunchAgent: {e}")
        return
    
    try:
        import pwd
        uid = pwd.getpwnam(real_user).pw_uid
        gid = pwd.getpwnam(real_user).pw_gid
        os.chown(monitor_dir, uid, gid)
        os.chown(monitor_script, uid, gid)
        os.chown(plist_path, uid, gid)
    except Exception as e:
        print_warning(f"Could not set ownership: {e}")
    
    run_command(f"launchctl unload '{plist_path}'", check=False)
    
    show_progress("Loading LaunchAgent", 1)
    result = run_command(f"launchctl load '{plist_path}'")
    
    if result is not None:
        print(f"\n{Colors.GREEN}{Colors.BOLD}╔════════════════════════════════════════════════╗")
        print(f"║   Auto-Switcher Installed Successfully! ✓      ║")
        print(f"╚════════════════════════════════════════════════╝{Colors.RESET}\n")
        print_success("Your Mac will now automatically switch network profiles!")
        print_info("Monitoring interval: Every 10 seconds")
        print_info(f"Logs available at: /tmp/wifichanger.log")
    else:
        print_error("Failed to load LaunchAgent")


def show_menu():
    """Display main menu and handle user selection"""
    while True:
        print(f"\n{Colors.BOLD}{Colors.CYAN}════════════════════════════════════════{Colors.RESET}")
        print(f"{Colors.BOLD}{Colors.WHITE}   MAIN MENU{Colors.RESET}")
        print(f"{Colors.BOLD}{Colors.CYAN}════════════════════════════════════════{Colors.RESET}\n")
        
        print(f"{Colors.YELLOW}[1]{Colors.RESET} Create New Network Profile")
        print(f"{Colors.YELLOW}[2]{Colors.RESET} Install Auto-Switcher (Set & Forget)")
        print(f"{Colors.YELLOW}[3]{Colors.RESET} Exit\n")
        
        choice = get_user_input("Select an option [1-3]")
        
        if choice == '1':
            create_network_profile()
        elif choice == '2':
            install_auto_switcher()
        elif choice == '3':
            print(f"\n{Colors.CYAN}Thank you for using NetConfig!{Colors.RESET}")
            print(f"{Colors.CYAN}Goodbye! 👋{Colors.RESET}\n")
            sys.exit(0)
        else:
            print_warning("Invalid option. Please select 1, 2, or 3.")


def main():
    """Main entry point"""
    try:
        print_header()
        check_root_privileges()
        show_menu()
    except KeyboardInterrupt:
        print(f"\n\n{Colors.YELLOW}Operation cancelled by user.{Colors.RESET}")
        sys.exit(0)
    except Exception as e:
        print_error(f"Unexpected error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
