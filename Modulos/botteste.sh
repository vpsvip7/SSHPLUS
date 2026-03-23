#!/bin/bash
# sshmonitor – User Monitoring screen (menu option [07] MONITOR USERS).
#
# Spec: Professional, minimal, scannable CLI (htop-ish). Two modes: LIVE view (activity + last seen)
# and Details view (totals, remaining days, password). Data from users.db (read-only) and live
# connection tracking; never write to users.db from this screen.
# Keys: d=Details, e=Expand, p=Masked passwords, P=Show full (confirm), s=Sort, f=Filter, q=Quit, Enter=Back.
# Optional hotkeys: a=active, x=expiring≤7d, n=never, *=all.
# Menu option [07] calls this script (e.g. exec sshmonitor or bash Modules/sshmonitor).

# Load color helpers (install path vs dev path)
if [[ -f /etc/SSHPlus/colors ]]; then
	source /etc/SSHPlus/colors
elif [[ -f /bin/colors ]]; then
	source /bin/colors
elif [[ -f "$(dirname "$0")/colors" ]]; then
	source "$(dirname "$0")/colors"
fi

# Load centralized DB (read-only from this screen)
if [[ -f /etc/SSHPlus/db ]]; then
	source /etc/SSHPlus/db
elif [[ -f /bin/db ]]; then
	source /bin/db
elif [[ -f "$(dirname "$0")/db" ]]; then
	source "$(dirname "$0")/db"
fi

if [[ -z "${SSHPLUS_FROM_REPO:-}" ]]; then
	_mod_dir="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
	_repo_root="$(cd "${_mod_dir}/.." 2>/dev/null && pwd)"
	[[ -f "${_repo_root}/install.sh" ]] && [[ -f "${_repo_root}/version" ]] && export SSHPLUS_FROM_REPO=1
	unset -v _mod_dir _repo_root
fi
[[ -z "${SSHPLUS_FROM_REPO:-}" ]] && [[ ! -e /usr/lib/sshplus ]] && exit 0

# -------------------- Configuration: Refresh interval --------------------
# Read refresh interval from config file, default to 10 seconds (spec: 10s)
get_refresh_interval() {
	local config_file="/etc/SSHPlus/refresh_interval"
	local default_interval=10
	if [[ -f "$config_file" ]] && [[ -s "$config_file" ]]; then
		local interval
		interval=$(tr -d '\r\n' < "$config_file" 2>/dev/null | grep -E '^[0-9]+$' | head -1)
		if [[ -n "$interval" ]] && [[ "$interval" -ge 5 ]] && [[ "$interval" -le 300 ]]; then
			echo "$interval"
			return
		fi
	fi
	echo "$default_interval"
}

# -------------------- Formatters --------------------
fmt_bytes_compact() {
	awk -v b="${1:-0}" 'BEGIN{
		if(b>=1073741824) printf "%.1fG", b/1073741824
		else if(b>=1048576) printf "%.1fM", b/1048576
		else if(b>=1024) printf "%.0fK", b/1024
		else printf "%dB", b+0
	}'
}

# Format latest_connection_date (ISO or "never") to "DD/MM HH:MM (Nd)" or "never"
fmt_last_seen() {
	local v="${1:-}"
	[[ -z "$v" || "$v" == "never" ]] && echo "never" && return
	local epoch now_sec d dt
	epoch=$(date -d "$v" +%s 2>/dev/null) || { echo "never"; return; }
	now_sec=$(date +%s 2>/dev/null) || now_sec=0
	[[ -z "${now_sec:-}" || ! "${now_sec:-0}" =~ ^[0-9]+$ ]] && now_sec=0
	d=$(( (now_sec - epoch) / 86400 ))
	dt=$(date -d "@$epoch" +"%d/%m %H:%M" 2>/dev/null) || dt="?"
	echo "${dt} (${d}d)"
}

# Mask password: first 2 chars + • (middle) + last 1–2 chars (spec: Ha••••n1 style)
mask_password() {
	local raw="${1:-}"
	[[ -z "$raw" ]] && echo "" && return
	local len=${#raw}
	if [[ $len -le 4 ]]; then
		echo "••••"
		return
	fi
	local first="${raw:0:2}" last="${raw: -2}"
	[[ $len -lt 6 ]] && last="${raw: -1}"
	local mid_len=$(( len - 4 ))
	[[ $mid_len -lt 0 ]] && mid_len=0
	local dots
	printf -v dots '%*s' "$mid_len" ''; dots="${dots// /•}"
	echo "${first}${dots}${last}"
}

# -------------------- Parse users.db into arrays (read-only) --------------------
# Sets: _U_LIST, _U_max_conn, _U_tot_up, _U_tot_down, _U_total_traffic, _U_last_traffic, _U_latest_iso, _U_exp, _U_remaining_days, _U_password
# DB format: 9 columns; field 9 (password) is rest of line and may contain spaces. Never write to users.db from this screen.
parse_users_db() {
	local u line username lim exp reg tot_up tot_down last latest pass exp_sec now_sec diff
	_U_LIST=()
	declare -gA _U_max_conn _U_tot_up _U_tot_down _U_total_traffic _U_last_traffic _U_latest_iso _U_exp _U_remaining_days _U_password 2>/dev/null || true

	now_sec=$(date +%s)
	local sys_users
	sys_users=$(awk -F: '$3>=1000 {print $1}' /etc/passwd 2>/dev/null | grep -v nobody)
	while read -r u; do
		[[ -z "$u" ]] && continue
		sshplus_with_db_lock sshplus_db_ensure_user "$u" >/dev/null 2>&1 || true
		line="$(sshplus_db_get_line "$u" 2>/dev/null || true)"
		_U_LIST+=("$u")
		lim=$(awk '{print $2}' <<<"${line:-}")
		exp=$(awk '{print $3}' <<<"${line:-}")
		reg=$(awk '{print $4}' <<<"${line:-}")
		tot_up=$(awk '{print $5+0}' <<<"${line:-}")
		tot_down=$(awk '{print $6+0}' <<<"${line:-}")
		last=$(awk '{print $7+0}' <<<"${line:-}")
		latest=$(awk '{print $8}' <<<"${line:-}")
		pass=$(awk 'NF>=9{rest=$9;for(i=10;i<=NF;i++) rest=rest " " $i; print rest} NF==8{print $8}' <<<"${line:-}")
		_U_max_conn["$u"]="${lim:-1}"
		_U_tot_up["$u"]="${tot_up:-0}"
		_U_tot_down["$u"]="${tot_down:-0}"
		_U_total_traffic["$u"]=$(( ${tot_up:-0} + ${tot_down:-0} ))
		_U_last_traffic["$u"]="${last:-0}"
		_U_latest_iso["$u"]="${latest:-never}"
		_U_exp["$u"]="${exp:-never}"
		_U_password["$u"]="${pass:-}"
		if [[ -z "$exp" || "$exp" == "never" ]]; then
			_U_remaining_days["$u"]="∞"
		else
			exp_sec=$(date -d "$exp" +%s 2>/dev/null) || { _U_remaining_days["$u"]="?"; continue; }
			diff=$(( (exp_sec - now_sec) / 86400 ))
			_U_remaining_days["$u"]="$diff"
		fi
	done <<<"$sys_users"
}

# -------------------- Live connections (not stored in db) --------------------
# Per user: now_conn_count, now_down, now_up, now_time (sum of session times), and per-connection lines.
# Uses same PID list for count and traffic so "now online" and "current traffic" stay in sync.
# Sets: _L_conn_count, _L_now_down, _L_now_up, _L_now_time_sec, _L_connections (newline-sep lines "slot|down|up|time_sec")
get_live_connections() {
	local u
	unset _L_conn_count _L_now_down _L_now_up _L_now_time_sec _L_connections 2>/dev/null || true
	declare -gA _L_conn_count _L_now_down _L_now_up _L_now_time_sec _L_connections

	for u in "${_U_LIST[@]:-}"; do
		[[ -z "$u" ]] && continue
		_L_conn_count["$u"]=0
		_L_now_down["$u"]=0
		_L_now_up["$u"]=0
		_L_now_time_sec["$u"]=0
		_L_connections["$u"]=""

		# SSH sessions: get PIDs of user's sshd processes first, then use for both count and traffic
		local ssh_pids ovp=0 pid r w etime_sec line
		ssh_pids=$(ps -u "$u" -o pid= 2>/dev/null | while read -r p; do
			[[ -n "$p" ]] && ps -p "$p" -o comm= 2>/dev/null | grep -q sshd && echo "$p"
		done)
		[[ -e /etc/openvpn/openvpn-status.log ]] && ovp=$(grep -E ,"$u", /etc/openvpn/openvpn-status.log 2>/dev/null | wc -l)
		ovp=${ovp//[!0-9]/}; ovp=${ovp:-0}
		local sqd=0
		while read -r pid; do [[ -n "$pid" ]] && ((sqd++)) || true; done <<<"$ssh_pids"
		local total_conn=$((sqd + ovp))
		_L_conn_count["$u"]=$total_conn

		if [[ $sqd -gt 0 ]]; then
			local sum_down=0 sum_up=0 sum_time=0 idx=0 conn_lines=""
			while read -r pid; do
				[[ -z "$pid" ]] && continue
				r=0 w=0
				[[ -r "/proc/$pid/io" ]] && while read -r line; do
					case "$line" in rchar:*) r="${line#rchar:}";; wchar:*) w="${line#wchar:}";; esac
				done < "/proc/$pid/io" 2>/dev/null
				etime_sec=0
				local et
				et=$(ps -o etimes= -p "$pid" 2>/dev/null)
				[[ -n "$et" && "$et" =~ ^[0-9]+$ ]] && etime_sec=$et
				# Fallback: some systems use etime ([[DD-]HH:]MM:SS) instead of etimes
				if [[ ${etime_sec:-0} -eq 0 ]]; then
					et=$(ps -o etime= -p "$pid" 2>/dev/null | tr -d ' ')
					if [[ -n "$et" ]]; then
						etime_sec=$(echo "$et" | awk -F: '{
							n=NF
							sec = (n>=1) ? $n+0 : 0
							min = (n>=2) ? $(n-1)+0 : 0
							x = (n>=3) ? $(n-2) : "0"
							split(x, a, "-")
							hr  = (length(a)>=2) ? a[2]+0 : x+0
							day = (length(a)>=2) ? a[1]+0 : 0
							print sec + min*60 + hr*3600 + day*86400
						}')
						[[ -z "$etime_sec" || ! "$etime_sec" =~ ^[0-9]+$ ]] && etime_sec=0
					fi
				fi
				((idx++)) || true
				sum_down=$((sum_down + r)); sum_up=$((sum_up + w)); sum_time=$((sum_time + etime_sec))
				conn_lines+="${idx}|${r}|${w}|${etime_sec}"$'\n'
			done <<<"$ssh_pids"
			_L_now_down["$u"]=$sum_down
			_L_now_up["$u"]=$sum_up
			_L_now_time_sec["$u"]=$sum_time
			_L_connections["$u"]="$conn_lines"
		fi
	done
}

# -------------------- Status: active | idle | inactive | never --------------------
compute_status() {
	local username="$1" now_count="${2:-0}" latest_iso="${3:-}" total_traffic="${4:-0}"
	if [[ "${now_count:-0}" -gt 0 ]]; then
		echo "active"
		return
	fi
	if [[ -z "$latest_iso" || "$latest_iso" == "never" ]]; then
		[[ "${total_traffic:-0}" -eq 0 ]] && echo "never" || echo "inactive"
		return
	fi
	local epoch now_sec diff
	epoch=$(date -d "$latest_iso" +%s 2>/dev/null) || { echo "inactive"; return; }
	now_sec=$(date +%s)
	diff=$(( (now_sec - epoch) / 86400 ))
	[[ $diff -le 0 ]] && diff=0
	if [[ $diff -eq 0 ]]; then
		local h=$(( (now_sec - epoch) / 3600 ))
		[[ $h -lt 24 ]] && echo "idle" || echo "inactive"
	else
		echo "inactive"
	fi
}

# -------------------- Sort: 1=username↑ 2=last_seen↓ 3=bandwidth↓ 4=total_time↓ --------------------
apply_sort() {
	local sort_mode="${1:-1}" list=("${@:2}")
	[[ ${#list[@]} -eq 0 ]] && return
	case "$sort_mode" in
		1) for u in "${list[@]}"; do echo "$u"; done | sort ;;
		2) for u in "${list[@]}"; do
				local lat="${_U_latest_iso[$u]:-never}"
				local ts=0
				[[ -n "$lat" && "$lat" != "never" ]] && ts=$(date -d "$lat" +%s 2>/dev/null)
				printf "%d\t%s\n" "$ts" "$u"
			done | sort -rn -k1 | cut -f2 ;;
		3) for u in "${list[@]}"; do
				local t="${_U_total_traffic[$u]:-0}"
				printf "%d\t%s\n" "$t" "$u"
			done | sort -rn -k1 | cut -f2 ;;
		4) for u in "${list[@]}"; do
				local t="${_U_total_traffic[$u]:-0}"
				printf "%d\t%s\n" "$t" "$u"
			done | sort -rn -k1 | cut -f2 ;;
		*) for u in "${list[@]}"; do echo "$u"; done | sort ;;
	esac
}

# -------------------- Filter: 1=all 2=active 3=expiring≤7 4=expired 5=never_used --------------------
apply_filter() {
	local filter_mode="${1:-1}" list=("${@:2}")
	[[ ${#list[@]} -eq 0 ]] && return
	local -a out
	for u in "${list[@]}"; do
		local status now_count latest total rem
		now_count="${_L_conn_count[$u]:-0}"
		latest="${_U_latest_iso[$u]:-never}"
		total="${_U_total_traffic[$u]:-0}"
		rem="${_U_remaining_days[$u]:-?}"
		status=$(compute_status "$u" "$now_count" "$latest" "$total")
		case "$filter_mode" in
			1) out+=("$u") ;;
			2) [[ "$status" == "active" ]] && out+=("$u") ;;
			3) [[ "$rem" =~ ^[0-9]+$ ]] && [[ $rem -le 7 && $rem -ge 0 ]] && out+=("$u") ;;
			4) [[ "$rem" =~ ^-?[0-9]+$ ]] && [[ $rem -le 0 ]] && out+=("$u") ;;
			5) [[ "$status" == "never" ]] && out+=("$u") ;;
			*) out+=("$u") ;;
		esac
	done
	printf '%s\n' "${out[@]}"
}

# -------------------- UI state (persisted across refresh) --------------------
MONITOR_DETAILS=0
MONITOR_EXPAND=0
MONITOR_PASS_MASKED=0
MONITOR_PASS_FULL=0
MONITOR_SORT=1
MONITOR_FILTER=1
declare -A MONITOR_EXPANDED

# Session logging state (per-user, for this sshmonitor run only)
declare -A _S_ACTIVE _S_START_TS _S_START_ISO _S_BYTES_START _S_BYTES_END _S_BYTES_START_DOWN _S_BYTES_START_UP _S_BYTES_END_DOWN _S_BYTES_END_UP

# Sort labels for header
_sort_label() {
	case "${1:-1}" in
		1) echo "username↑" ;;
		2) echo "last_seen↓" ;;
		3) echo "bandwidth↓" ;;
		4) echo "total_time↓" ;;
		*) echo "username↑" ;;
	esac
}

_filter_label() {
	case "${1:-1}" in
		1) echo "all" ;;
		2) echo "active" ;;
		3) echo "expiring≤7d" ;;
		4) echo "expired" ;;
		5) echo "never" ;;
		*) echo "all" ;;
	esac
}

# Alias for compact uptime display (same as _sec_to_hms)
fmt_uptime_short() { _sec_to_hms "$1"; }

_sec_to_hms() {
	awk -v s="${1:-0}" 'BEGIN{
		h=int(s/3600); m=int((s%3600)/60); s=int(s%60)
		printf "%02d:%02d:%02d", h, m, s
	}'
}

# -------------------- Session state (in-memory only; do not write to users.db from this screen) --------------------
_update_session_logs() {
	# Requires: _U_LIST, _L_conn_count, _L_now_down, _L_now_up. Spec: never write live data into users.db from this screen.
	# Session state (_S_*) kept for display consistency only; no DB or log writes here.
	local u now_count now_bytes start_ts end_ts delta_sec delta_hms bytes_sess end_iso
	for u in "${_U_LIST[@]:-}"; do
		[[ -z "$u" ]] && continue
		now_count="${_L_conn_count[$u]:-0}"
		now_bytes=$(( ${_L_now_down[$u]:-0} + ${_L_now_up[$u]:-0} ))

		if [[ "$now_count" -gt 0 ]]; then
			# Session active: keep updating end bytes (and up/down) so we have accurate totals when they disconnect
			if [[ -z "${_S_ACTIVE[$u]:-}" ]]; then
				_S_ACTIVE["$u"]=1
				_S_START_TS["$u"]=$(date +%s)
				_S_START_ISO["$u"]=$(sshplus_now_iso)
				_S_BYTES_START["$u"]="$now_bytes"
				_S_BYTES_START_DOWN["$u"]="${_L_now_down[$u]:-0}"
				_S_BYTES_START_UP["$u"]="${_L_now_up[$u]:-0}"
			fi
			_S_BYTES_END["$u"]="$now_bytes"
			_S_BYTES_END_DOWN["$u"]="${_L_now_down[$u]:-0}"
			_S_BYTES_END_UP["$u"]="${_L_now_up[$u]:-0}"
		else
			# No active connections; if we had an active session, close and log it
			if [[ -n "${_S_ACTIVE[$u]:-}" ]]; then
				start_ts="${_S_START_TS[$u]:-0}"
				[[ -z "$start_ts" ]] && start_ts=0
				end_ts=$(date +%s)
				end_iso=$(sshplus_now_iso)
				delta_sec=$(( end_ts - start_ts ))
				(( delta_sec < 0 )) && delta_sec=0
				delta_hms=$(_sec_to_hms "$delta_sec")
				bytes_sess=$(( ${_S_BYTES_END[$u]:-0} - ${_S_BYTES_START[$u]:-0} ))
				(( bytes_sess < 0 )) && bytes_sess=0
				session_upload=$(( ${_S_BYTES_END_UP[$u]:-0} - ${_S_BYTES_START_UP[$u]:-0} ))
				session_download=$(( ${_S_BYTES_END_DOWN[$u]:-0} - ${_S_BYTES_START_DOWN[$u]:-0} ))
				(( session_upload < 0 )) && session_upload=0
				(( session_download < 0 )) && session_download=0
				# Do not write to users.db from this screen (spec: read-only for DB)
				unset _S_ACTIVE["$u"] _S_START_TS["$u"] _S_START_ISO["$u"] _S_BYTES_START["$u"] _S_BYTES_END["$u"] _S_BYTES_START_DOWN["$u"] _S_BYTES_START_UP["$u"] _S_BYTES_END_DOWN["$u"] _S_BYTES_END_UP["$u"]
			fi
		fi
	done
}

# -------------------- LIVE view --------------------
print_user_monitor_screen() {
	parse_users_db
	get_live_connections
	_update_session_logs

	local total_users=${#_U_LIST[@]}
	local n_active=0 n_idle=0 n_inactive=0 n_never=0
	local sum_traffic_down=0 sum_traffic_up=0
	for u in "${_U_LIST[@]:-}"; do
		[[ -z "$u" ]] && continue
		local st now_count latest total
		now_count="${_L_conn_count[$u]:-0}"
		latest="${_U_latest_iso[$u]:-never}"
		total="${_U_total_traffic[$u]:-0}"
		st=$(compute_status "$u" "$now_count" "$latest" "$total")
		case "$st" in active) ((n_active++));; idle) ((n_idle++));; inactive) ((n_inactive++));; never) ((n_never++));; esac
		sum_traffic_down=$((sum_traffic_down + ${_U_tot_down[$u]:-0}))
		sum_traffic_up=$((sum_traffic_up + ${_U_tot_up[$u]:-0}))
	done

	local filtered_list
	filtered_list=($(apply_filter "$MONITOR_FILTER" "${_U_LIST[@]}"))
	local sorted_list
	sorted_list=($(apply_sort "$MONITOR_SORT" "${filtered_list[@]}"))

	local cols
	cols=$(term_cols 2>/dev/null) || cols=80
	local sep
	sep=$(printf '%*s' "$cols" "" | tr ' ' '-')

	# Title + auto-refresh on one line (spec: USERS MONITORING, auto-refresh: 10s)
	local refresh_interval
	refresh_interval=$(get_refresh_interval)
	# Padding so title + "auto-refresh: Ns" fits in cols (17 + 18 = 35 chars for right part)
	printf "%bUSERS MONITORING%b%*s%bauto-refresh: %ds%b\n" "$(c ui_title)" "$(reset)" "$(( cols - 35 ))" "" "$(c ui_value)" "$refresh_interval" "$(reset)"
	printf "%b%s%b\n" "$(c ui_frame)" "$sep" "$(reset)"
	echo ""

	# Summary: status counts + total traffic ⬇/⬆ (spec: 🟢 active, 🟡 idle, 🔴 inactive, ⚪ never)
	printf "👤 %d users    🟢 %d active   🟡 %d idle   🔴 %d inactive   ⚪ %d never\n" "$total_users" "$n_active" "$n_idle" "$n_inactive" "$n_never"
	printf "🛜 Total traffic   ⬇ %s   ⬆ %s            Sort: %s   Filter: %s\n" \
		"$(fmt_bytes_compact "$sum_traffic_down")" "$(fmt_bytes_compact "$sum_traffic_up")" "$(_sort_label "$MONITOR_SORT")" "$(_filter_label "$MONITOR_FILTER")"
	echo ""

	# Expired warning
	local n_expired=0
	for u in "${_U_LIST[@]:-}"; do
		local rem="${_U_remaining_days[$u]:-?}"
		[[ "$rem" =~ ^-?[0-9]+$ ]] && [[ $rem -le 0 ]] && ((n_expired++)) || true
	done
	[[ $n_expired -gt 0 ]] && printf "%b⚠ %d users are expired (Filter: expired to review)%b\n" "$(c ui_warn)" "$n_expired" "$(reset)"
	[[ $n_expired -gt 0 ]] && echo ""

	printf "%b%s%b\n" "$(c ui_frame)" "$sep" "$(reset)"
	echo ""
	printf "%bUSER        NOW/MAX   NOW TRAFFIC     NOW TIME   LAST SEEN%b\n" "$(c ui_section)" "$(reset)"
	printf "%b%s%b\n" "$(c ui_frame)" "$sep" "$(reset)"
	echo ""

	# Group by status and print
	local -A done
	for st in active idle inactive never; do
		local -a group=()
		for u in "${sorted_list[@]}"; do
			[[ -n "${done[$u]:-}" ]] && continue
			local now_count latest total
			now_count="${_L_conn_count[$u]:-0}"
			latest="${_U_latest_iso[$u]:-never}"
			total="${_U_total_traffic[$u]:-0}"
			local s
			s=$(compute_status "$u" "$now_count" "$latest" "$total")
			[[ "$s" == "$st" ]] && group+=("$u") && done[$u]=1
		done
		[[ ${#group[@]} -eq 0 ]] && continue

		local label count_grp
		case "$st" in
			active) label="ACTIVE"; count_grp=${#group[@]} ;;
			idle) label="IDLE"; count_grp=${#group[@]} ;;
			inactive) label="INACTIVE"; count_grp=${#group[@]} ;;
			never) label="NEVER"; count_grp=${#group[@]} ;;
			*) label=""; count_grp=0 ;;
		esac
		printf "%s (%d)\n" "$label" "$count_grp"

		for u in "${group[@]}"; do
			local icon max_conn now_count now_down now_up now_time_sec latest_iso
			now_count="${_L_conn_count[$u]:-0}"
			latest_iso="${_U_latest_iso[$u]:-never}"
			total="${_U_total_traffic[$u]:-0}"
			local status
			status=$(compute_status "$u" "$now_count" "$latest_iso" "$total")
			case "$status" in active) icon="🟢";; idle) icon="🟡";; inactive) icon="🔴";; *) icon="⚪";; esac
			max_conn="${_U_max_conn[$u]:-1}"
			now_down="${_L_now_down[$u]:-0}"
			now_up="${_L_now_up[$u]:-0}"
			now_time_sec="${_L_now_time_sec[$u]:-0}"

			local conn_lines
			conn_lines="${_L_connections[$u]:-}"

			if [[ "$now_count" -gt 0 ]]; then
				local now_traffic_str now_time_str
				now_traffic_str="Σ $(fmt_bytes_compact "$now_down")/$(fmt_bytes_compact "$now_up")"
				now_time_str=$(_sec_to_hms "$now_time_sec")
				if [[ -z "$conn_lines" ]]; then
					# No per-connection data (e.g. OpenVPN-only): one summary line only
					printf "%s %-10s %5s/%s   %-14s %-10s %s\n" "$icon" "$u" "$now_count" "$max_conn" "$now_traffic_str" "$now_time_str" "now"
				elif [[ -n "${MONITOR_EXPANDED[$u]:-}" ]]; then
					# Expanded: summary line + one row per session (↳ #1, #2, …)
					printf "%s %-10s %5s/%s   %-14s %-10s %s\n" "$icon" "$u" "$now_count" "$max_conn" "$now_traffic_str" "$now_time_str" "now"
					local idx=0
					while IFS= read -r line; do
						[[ -z "$line" ]] && continue
						((idx++)) || true
						local slot down up t_sec
						IFS='|' read -r slot down up t_sec <<<"$line"
						now_traffic_str="$(fmt_bytes_compact "$down")/$(fmt_bytes_compact "$up")"
						now_time_str=$(_sec_to_hms "${t_sec:-0}")
						printf "   ↳ #%-8s %5s/%s   %-14s %-10s now\n" "$idx" "$idx" "$max_conn" "$now_traffic_str" "$now_time_str"
					done <<<"$conn_lines"
				else
					# Collapsed: single summary line (same as OpenVPN)
					printf "%s %-10s %5s/%s   %-14s %-10s %s\n" "$icon" "$u" "$now_count" "$max_conn" "$now_traffic_str" "$now_time_str" "now"
				fi
			else
				local now_traffic_str now_time_str last_seen_str
				now_traffic_str="-"
				now_time_str="-"
				last_seen_str=$(fmt_last_seen "$latest_iso")
				printf "%s %-10s %5s/%s   %-14s %-10s %s\n" "$icon" "$u" "$now_count" "$max_conn" "$now_traffic_str" "$now_time_str" "$last_seen_str"
			fi
		done
		echo ""
	done

	printf "%b%s%b\n" "$(c ui_frame)" "$sep" "$(reset)"
	echo ""
	# Footer: show [e] Expand only when there are active users (spec)
	if [[ "$n_active" -gt 0 ]]; then
		if [[ "${MONITOR_EXPAND:-0}" -eq 1 ]]; then
			printf "%bKeys: [Enter] Back  [d] Details  [e] Expand (on)  [f] Filter  [s] Sort  [q] Quit%b\n" "$(c ui_muted)" "$(reset)"
		else
			printf "%bKeys: [Enter] Back  [d] Details  [e] Expand  [f] Filter  [s] Sort  [q] Quit%b\n" "$(c ui_muted)" "$(reset)"
		fi
	else
		printf "%bKeys: [Enter] Back  [d] Details  [f] Filter  [s] Sort  [q] Quit%b\n" "$(c ui_muted)" "$(reset)"
	fi
}

# -------------------- Details view --------------------
print_user_monitor_details() {
	parse_users_db
	get_live_connections

	local filtered_list
	filtered_list=($(apply_filter "$MONITOR_FILTER" "${_U_LIST[@]}"))
	local sorted_list
	sorted_list=($(apply_sort "$MONITOR_SORT" "${filtered_list[@]}"))

	local cols
	cols=$(term_cols 2>/dev/null) || cols=80
	local sep
	sep=$(printf '%*s' "$cols" "" | tr ' ' '-')

	printf "%bUSERS MONITORING — Details%b\n" "$(c ui_title)" "$(reset)"
	printf "%b%s%b\n" "$(c ui_frame)" "$sep" "$(reset)"
	echo ""
	printf "Sort: %s   Filter: %s\n" "$(_sort_label "$MONITOR_SORT")" "$(_filter_label "$MONITOR_FILTER")"
	echo ""
	printf "%bUSER        MAX   TOTAL TRAFFIC   TOTAL TIME   PASSWORD     REMAINING%b\n" "$(c ui_section)" "$(reset)"
	printf "%b%s%b\n" "$(c ui_frame)" "$sep" "$(reset)"
	echo ""

	for u in "${sorted_list[@]}"; do
		[[ -z "$u" ]] && continue
		local max_conn tot_down tot_up pass remaining pass_disp
		max_conn="${_U_max_conn[$u]:-1}"
		tot_down="${_U_tot_down[$u]:-0}"
		tot_up="${_U_tot_up[$u]:-0}"
		pass="${_U_password[$u]:-}"
		remaining="${_U_remaining_days[$u]:-?}"
		if [[ "$remaining" == "∞" || "$remaining" == "?" ]]; then
			:
		elif [[ "$remaining" =~ ^-?[0-9]+$ ]]; then
			[[ $remaining -lt 0 ]] && remaining="0d" || remaining="${remaining}d"
		fi
		if [[ -n "${MONITOR_PASS_FULL:-}" && "$MONITOR_PASS_FULL" -eq 1 ]]; then
			pass_disp="${pass:-—}"
		elif [[ -n "${MONITOR_PASS_MASKED:-}" && "$MONITOR_PASS_MASKED" -eq 1 ]]; then
			pass_disp=$(mask_password "${pass:-}")
		else
			pass_disp="(hidden)"
		fi
		# TOTAL TRAFFIC as down/up (spec: 3.4M/1.8M); TOTAL TIME not in DB → "-"
		printf "%-10s %3s   %-14s   %-10s   %-12s %s\n" "$u" "$max_conn" \
			"$(fmt_bytes_compact "$tot_down")/$(fmt_bytes_compact "$tot_up")" "-" "$pass_disp" "$remaining"
	done

	echo ""
	printf "%b%s%b\n" "$(c ui_frame)" "$sep" "$(reset)"
	echo ""
	printf "%bKeys: [Enter] Back  [p] Passwords  [P] Show full  [f] Filter  [s] Sort  [q] Quit%b\n" "$(c ui_muted)" "$(reset)"
}

# -------------------- Input loop --------------------
_monitor_handle_key() {
	local key="$1"
	case "$key" in
		d|D) MONITOR_DETAILS=$(( 1 - MONITOR_DETAILS )) ;;
		e|E) MONITOR_EXPAND=$(( 1 - MONITOR_EXPAND ))
			# If expand mode on, expand all active users; else collapse all
			if [[ "$MONITOR_EXPAND" -eq 1 ]]; then
				for u in "${_U_LIST[@]:-}"; do
					[[ "${_L_conn_count[$u]:-0}" -gt 0 ]] && MONITOR_EXPANDED[$u]=1
				done
			else
				unset MONITOR_EXPANDED
				declare -gA MONITOR_EXPANDED
			fi ;;
		p) [[ "$MONITOR_DETAILS" -eq 1 ]] && MONITOR_PASS_MASKED=$(( 1 - MONITOR_PASS_MASKED )) ;;
		P)  if [[ "$MONITOR_DETAILS" -eq 1 ]]; then
				if [[ "${MONITOR_PASS_FULL:-0}" -eq 1 ]]; then
					MONITOR_PASS_FULL=0
				else
					printf "%bShow full passwords? [y/N]: %b" "$(c ui_prompt)" "$(reset)"
					read -r -n 1 yn
					echo ""
					[[ "$yn" =~ ^[Yy]$ ]] && MONITOR_PASS_FULL=1
				fi
			fi ;;
		s|S) MONITOR_SORT=$(( MONITOR_SORT % 4 + 1 )) ;;
		f|F) MONITOR_FILTER=$(( MONITOR_FILTER % 5 + 1 )) ;;
		a|A) MONITOR_FILTER=2 ;;
		x|X) MONITOR_FILTER=3 ;;
		n|N) MONITOR_FILTER=5 ;;
		\*) MONITOR_FILTER=1 ;;
		q|Q) exit 0 ;;
		"") return 1 ;; # Enter
		*) ;;
	esac
	return 0
}

# Main loop: configurable refresh interval, keep state, Enter = back to menu
# Wrapped in a function so any loop-local vars can use 'local' (bash requires local inside functions).
_monitor_main() {
	local refresh_interval key
	while true; do
		clear
		if [[ "${MONITOR_DETAILS:-0}" -eq 1 ]]; then
			print_user_monitor_details
		else
			print_user_monitor_screen
		fi
		refresh_interval=$(get_refresh_interval)
		read -r -t "$refresh_interval" -n 1 key 2>/dev/null || key=""
		# Allow multi-char for "P" (Shift+p might send different byte)
		[[ -z "$key" ]] && continue
		_monitor_handle_key "$key" && continue
		# Enter pressed
		break
	done
}
_monitor_main