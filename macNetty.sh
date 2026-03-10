#!/bin/bash
################################################################################
# macNetty - macOS Network Configuration Wizard
# A user-friendly CLI tool for managing network profiles and auto-switching
################################################################################

set -e

# ANSI Color Codes
RESET='\033[0m'
BOLD='\033[1m'
RED='\033[91m'
GREEN='\033[92m'
YELLOW='\033[93m'
BLUE='\033[94m'
MAGENTA='\033[95m'
CYAN='\033[96m'
WHITE='\033[97m'

################################################################################
# Display Functions
################################################################################

print_header() {
    cat << "EOF"
[96m[1m
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║   ███╗   ███╗ █████╗  ██████╗███╗   ██╗███████╗████████╗ ║
║   ████╗ ████║██╔══██╗██╔════╝████╗  ██║██╔════╝╚══██╔══╝ ║
║   ██╔████╔██║███████║██║     ██╔██╗ ██║█████╗     ██║    ║
║   ██║╚██╔╝██║██╔══██║██║     ██║╚██╗██║██╔══╝     ██║    ║
║   ██║ ╚═╝ ██║██║  ██║╚██████╗██║ ╚████║███████╗   ██║    ║
║   ╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═══╝╚══════╝   ╚═╝    ║
║                           ████████╗██╗   ██╗              ║
║                           ╚══██╔══╝╚██╗ ██╔╝              ║
║                              ██║    ╚████╔╝               ║
║                              ██║     ╚██╔╝                ║
║                              ██║      ██║                 ║
║                              ╚═╝      ╚═╝                 ║
║                                                           ║
║          macOS Network Configuration Wizard v1.0          ║
║              Simplifying Network Management               ║
╚═══════════════════════════════════════════════════════════╝
[0m
EOF
}

print_success() {
    echo -e "${GREEN}✓ $1${RESET}"
}

print_error() {
    echo -e "${RED}✗ $1${RESET}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${RESET}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${RESET}"
}

print_prompt() {
    echo -ne "${YELLOW}${BOLD}$1${RESET}"
}

show_progress() {
    local message="$1"
    local duration="${2:-2}"
    echo -ne "\n${CYAN}${message}"
    for ((i=0; i<duration*4; i++)); do
        echo -n "."
        sleep 0.25
    done
    echo -e " Done!${RESET}\n"
}

################################################################################
# Utility Functions
################################################################################

check_root_privileges() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script requires root privileges to configure network settings."
        print_info "Please run with sudo:"
        echo -e "\n    ${BOLD}sudo ./macNetty${RESET}\n"
        exit 1
    fi
    print_success "Running with root privileges"
}

get_user_input() {
    local prompt="$1"
    local default="$2"
    local user_input
    
    if [[ -n "$default" ]]; then
        echo -ne "${YELLOW}${BOLD}${prompt} [${default}]: ${RESET}" >&2
        read -r user_input
        echo "${user_input:-$default}"
    else
        echo -ne "${YELLOW}${BOLD}${prompt}: ${RESET}" >&2
        read -r user_input
        echo "$user_input"
    fi
}

get_yes_no() {
    local prompt="$1"
    local default="${2:-N}"
    local response
    
    if [[ "$default" == "N" ]]; then
        response=$(get_user_input "$prompt [y/N]" "$default")
    else
        response=$(get_user_input "$prompt [Y/n]" "$default")
    fi
    
    response=$(echo "$response" | tr '[:upper:]' '[:lower:]')
    [[ "$response" == "y" || "$response" == "yes" ]]
}

run_command() {
    local cmd="$1"
    local output
    
    if output=$(eval "$cmd" 2>&1); then
        echo "$output"
        return 0
    else
        print_error "Command failed: $cmd"
        print_error "Error: $output"
        return 1
    fi
}

get_network_interface() {
    local interface
    interface=$(networksetup -listallhardwareports | grep -A 1 Wi-Fi | grep 'Device:' | awk '{print $2}' | head -n1)
    echo "${interface:-en0}"
}

################################################################################
# Feature 1: Create Network Profile
################################################################################

create_network_profile() {
    echo -e "\n${BOLD}${MAGENTA}══════════════════════════════════════════${RESET}"
    echo -e "${BOLD}${MAGENTA}   CREATE NEW NETWORK PROFILE${RESET}"
    echo -e "${BOLD}${MAGENTA}══════════════════════════════════════════${RESET}\n"
    
    local ssid
    ssid=$(get_user_input "Enter the Wi-Fi Name (SSID) exactly")
    
    if [[ -z "$ssid" ]]; then
        print_error "SSID cannot be empty!"
        return
    fi
    
    local location_name="$ssid"
    
    if networksetup -listlocations | grep -q "^${location_name}$"; then
        print_warning "Location '$location_name' already exists!"
        if ! get_yes_no "Do you want to delete it and recreate?" "N"; then
            return
        fi
        networksetup -deletelocation "$location_name" 2>/dev/null || true
    fi
    
    print_info "Creating network location: $location_name"
    if ! networksetup -createlocation "$location_name" populate >/dev/null 2>&1; then
        print_error "Failed to create location"
        return
    fi
    
    show_progress "Setting up location" 1
    
    networksetup -switchtolocation "$location_name" >/dev/null 2>&1
    print_success "Switched to location: $location_name"
    
    local interface
    interface=$(get_network_interface)
    local service_name="Wi-Fi"
    
    if get_yes_no "Do you need a Static IP?" "N"; then
        echo -e "\n${CYAN}Static IP Configuration:${RESET}"
        
        local ip_address router subnet
        ip_address=$(get_user_input "Enter IP Address (e.g., 192.168.1.100)")
        router=$(get_user_input "Enter Router/Gateway (e.g., 192.168.1.1)")
        subnet=$(get_user_input "Enter Subnet Mask" "255.255.255.0")
        
        if [[ -n "$ip_address" && -n "$router" ]]; then
            print_info "Applying static IP configuration..."
            if networksetup -setmanual "$service_name" "$ip_address" "$subnet" "$router" 2>/dev/null; then
                print_success "Static IP configured: $ip_address"
            else
                print_error "Failed to set static IP"
            fi
        fi
    else
        networksetup -setdhcp "$service_name" 2>/dev/null
        print_success "Using DHCP (Automatic IP)"
    fi
    
    if get_yes_no "Do you need a Proxy?" "N"; then
        echo -e "\n${CYAN}Proxy Configuration:${RESET}"
        
        local proxy_host proxy_port
        proxy_host=$(get_user_input "Enter Proxy Host/IP")
        proxy_port=$(get_user_input "Enter Proxy Port")
        
        if [[ -n "$proxy_host" && -n "$proxy_port" ]]; then
            print_info "Applying proxy configuration..."
            networksetup -setwebproxy "$service_name" "$proxy_host" "$proxy_port" 2>/dev/null
            networksetup -setsecurewebproxy "$service_name" "$proxy_host" "$proxy_port" 2>/dev/null
            print_success "Proxy configured: ${proxy_host}:${proxy_port}"
        fi
    fi
    
    # Configure DNS if needed
    if get_yes_no "Do you want to set custom DNS servers?" "N"; then
        echo -e "\n${CYAN}DNS Configuration:${RESET}"
        
        local dns_primary dns_secondary dns_servers
        dns_primary=$(get_user_input "Enter Primary DNS (e.g., 8.8.8.8)")
        dns_secondary=$(get_user_input "Enter Secondary DNS (optional, e.g., 8.8.4.4)")
        
        if [[ -n "$dns_primary" ]]; then
            print_info "Applying DNS configuration..."
            
            if [[ -n "$dns_secondary" ]]; then
                dns_servers="$dns_primary $dns_secondary"
            else
                dns_servers="$dns_primary"
            fi
            
            if networksetup -setdnsservers "$service_name" $dns_servers 2>/dev/null; then
                if [[ -n "$dns_secondary" ]]; then
                    print_success "DNS configured: $dns_primary, $dns_secondary"
                else
                    print_success "DNS configured: $dns_primary"
                fi
            else
                print_error "Failed to set DNS servers"
            fi
        fi
    else
        networksetup -setdnsservers "$service_name" "Empty" 2>/dev/null
        print_success "Using automatic DNS (from DHCP)"
    fi
    
    show_progress "Finalizing configuration" 1
    
    echo -e "\n${GREEN}${BOLD}╔════════════════════════════════════════╗"
    echo -e "║   Profile Created Successfully! ✓      ║"
    echo -e "╚════════════════════════════════════════╝${RESET}\n"
    print_info "Location: $location_name"
    print_info "Your network profile is now active!"
}

################################################################################
# Feature 2: Delete Network Profile
################################################################################

delete_network_profile() {
    echo -e "\n${BOLD}${MAGENTA}══════════════════════════════════════════${RESET}"
    echo -e "${BOLD}${MAGENTA}   DELETE NETWORK PROFILE${RESET}"
    echo -e "${BOLD}${MAGENTA}══════════════════════════════════════════${RESET}\n"
    
    # Get list of existing locations
    local locations
    locations=$(networksetup -listlocations)
    
    if [[ -z "$locations" ]]; then
        print_error "No network profiles found!"
        return
    fi
    
    # Display available profiles
    echo -e "${CYAN}Available Network Profiles:${RESET}\n"
    echo "$locations" | nl -w2 -s'. '
    echo ""
    
    # Get user selection
    local profile_name
    profile_name=$(get_user_input "Enter the profile name to delete")
    
    if [[ -z "$profile_name" ]]; then
        print_error "Profile name cannot be empty!"
        return
    fi
    
    # Verify profile exists
    if ! echo "$locations" | grep -q "^${profile_name}$"; then
        print_error "Profile '$profile_name' not found!"
        return
    fi
    
    # Confirm deletion
    print_warning "You are about to delete the profile: $profile_name"
    if ! get_yes_no "Are you sure you want to delete this profile?" "N"; then
        print_info "Deletion cancelled."
        return
    fi
    
    # Delete the location
    if networksetup -deletelocation "$profile_name" 2>/dev/null; then
        echo -e "\n${GREEN}${BOLD}╔════════════════════════════════════════╗"
        echo -e "║   Profile Deleted Successfully! ✓      ║"
        echo -e "╚════════════════════════════════════════╝${RESET}\n"
        print_success "Profile '$profile_name' has been removed"
    else
        print_error "Failed to delete profile '$profile_name'"
    fi
}

################################################################################
# Feature 3: Install Auto-Switcher
################################################################################

install_auto_switcher() {
    echo -e "\n${BOLD}${MAGENTA}══════════════════════════════════════════${RESET}"
    echo -e "${BOLD}${MAGENTA}   INSTALL AUTO-SWITCHER${RESET}"
    echo -e "${BOLD}${MAGENTA}══════════════════════════════════════════${RESET}\n"
    
    print_info "This will automatically switch network profiles based on your Wi-Fi network"
    print_info "Scanning every 10 seconds in the background"
    echo ""
    
    local real_user="${SUDO_USER:-$USER}"
    local home_dir
    home_dir=$(eval echo "~$real_user")
    
    local monitor_dir="$home_dir/.locationchanger"
    mkdir -p "$monitor_dir"
    
    local monitor_script="$monitor_dir/monitor.sh"
    
    cat > "$monitor_script" << 'MONITOR_EOF'
#!/bin/bash
# Wi-Fi Auto-Switcher Monitor Script
# Automatically switches network location based on current SSID

CURRENT_SSID=$(ipconfig getsummary en0 2>/dev/null | awk -F' SSID : ' '{print $2}' | head -n1)

if [ -z "$CURRENT_SSID" ]; then
    CURRENT_SSID=$(ipconfig getsummary en0 | awk -F ' SSID : '  '/ SSID : / {print $2}')

CURRENT_LOCATION=$(networksetup -getcurrentlocation)

if [ -z "$CURRENT_SSID" ]; then
    exit 0
fi

if [ "$CURRENT_SSID" != "$CURRENT_LOCATION" ]; then
    if networksetup -listlocations | grep -q "^${CURRENT_SSID}$"; then
        networksetup -switchtolocation "$CURRENT_SSID"
        logger "macNetty Auto-Switcher: Switched to location '$CURRENT_SSID'"
    fi
fi
MONITOR_EOF
    
    chmod 755 "$monitor_script"
    print_success "Monitor script created: $monitor_script"
    
    # Create LaunchAgent plist
    local launch_agent_dir="$home_dir/Library/LaunchAgents"
    mkdir -p "$launch_agent_dir"
    
    local plist_path="$launch_agent_dir/com.user.wifichanger.plist"
    
    cat > "$plist_path" << PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.wifichanger</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>$monitor_script</string>
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
PLIST_EOF
    
    print_success "LaunchAgent created: $plist_path"
    
    # Fix ownership
    chown -R "$real_user" "$monitor_dir" 2>/dev/null || true
    chown "$real_user" "$plist_path" 2>/dev/null || true
    
    sudo -u "$real_user" launchctl unload "$plist_path" 2>/dev/null || true
    
    show_progress "Loading LaunchAgent" 1
    
    if sudo -u "$real_user" launchctl load "$plist_path" 2>/dev/null; then
        echo -e "\n${GREEN}${BOLD}╔════════════════════════════════════════════════╗"
        echo -e "║   Auto-Switcher Installed Successfully! ✓      ║"
        echo -e "╚════════════════════════════════════════════════╝${RESET}\n"
        print_success "Your Mac will now automatically switch network profiles!"
        print_info "Monitoring interval: Every 10 seconds"
        print_info "Logs available at: /tmp/wifichanger.log"
    else
        print_error "Failed to load LaunchAgent"
    fi
}

################################################################################
# Main Menu
################################################################################

show_menu() {
    while true; do
        echo -e "\n${BOLD}${CYAN}════════════════════════════════════════${RESET}"
        echo -e "${BOLD}${WHITE}   MAIN MENU${RESET}"
        echo -e "${BOLD}${CYAN}════════════════════════════════════════${RESET}\n"
        
        echo -e "${YELLOW}[1]${RESET} Create New Network Profile"
        echo -e "${YELLOW}[2]${RESET} Delete Network Profile"
        echo -e "${YELLOW}[3]${RESET} Install Auto-Switcher (Set & Forget)"
        echo -e "${YELLOW}[4]${RESET} Exit"
        echo ""
        
        local choice
        choice=$(get_user_input "Select an option [1-4]")
        
        case "$choice" in
            1)
                create_network_profile
                ;;
            2)
                delete_network_profile
                ;;
            3)
                install_auto_switcher
                ;;
            4)
                echo -e "\n${CYAN}Thank you for using macNetty!${RESET}"
                echo -e "${CYAN}Goodbye! 👋${RESET}\n"
                exit 0
                ;;
            *)
                print_warning "Invalid option. Please select 1, 2, 3, or 4."
                ;;
        esac
    done
}

################################################################################
# Main Entry Point
################################################################################

main() {
    print_header
    check_root_privileges
    show_menu
}

trap 'echo -e "\n\n${YELLOW}Operation cancelled by user.${RESET}"; exit 0' INT

main
