#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

usage() {
    echo -e "${CYAN}Usage:${RESET} $0 <log_directory> [interval_seconds] [--retention <days>]"
    echo ""
    echo "  <log_directory>      Required. Path to the directory for log files."
    echo "  [interval_seconds]   Optional. Collection interval in seconds (default: 60)."
    echo "  [--retention <days>] Optional. Delete logs older than N days (default: no deletion)."
    echo ""
    echo -e "${CYAN}Example:${RESET} $0 /var/log/sysmon 30 --retention 7"
    exit 1
}

check_args() {
    if [[ $# -lt 1 ]]; then
        echo -e "${RED}Error:${RESET} log directory is required."
        usage
    fi
    if ! [[ "${2:-60}" =~ ^[0-9]+$ ]] || [[ "${2:-60}" -lt 1 ]]; then
        echo -e "${RED}Error:${RESET} interval must be a positive integer."
        exit 1
    fi
    local i
    for ((i = 1; i <= $#; i++)); do
        if [[ "${!i}" == "--retention" ]]; then
            local j=$((i + 1))
            if [[ -z "${!j:-}" ]] || ! [[ "${!j}" =~ ^[0-9]+$ ]] || [[ "${!j}" -lt 1 ]]; then
                echo -e "${RED}Error:${RESET} --retention requires a positive integer (days)."
                exit 1
            fi
        fi
    done
}

parse_retention() {
    local args=("$@")
    for ((i = 0; i < ${#args[@]}; i++)); do
        if [[ "${args[$i]}" == "--retention" ]]; then
            echo "${args[$((i + 1))]}"
            return
        fi
    done
    echo ""
}

cleanup_old_logs() {
    local log_dir="$1"
    local retention_days="$2"

    [[ -z "$retention_days" ]] && return

    local count
    count=$(find "$log_dir" -maxdepth 1 -name "monitor_*.log" \
        -mtime +"$retention_days" 2>/dev/null | wc -l)

    if [[ "$count" -gt 0 ]]; then
        find "$log_dir" -maxdepth 1 -name "monitor_*.log" \
            -mtime +"$retention_days" -delete
        echo -e "  deleted ${count} log(s) older than ${retention_days} day(s)\n"
    fi
}

init_log_dir() {
    local log_dir="$1"

    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir"
        echo -e "${GREEN}✔${RESET} Directory created: ${CYAN}${log_dir}${RESET}"
    else
        echo -e "${GREEN}✔${RESET} Directory found: ${CYAN}${log_dir}${RESET}"
    fi
}

get_cpu_load() {
    local cpu1 cpu2
    cpu1=$(awk '/^cpu / {print $2+$3+$4+$5+$6+$7+$8, $5}' /proc/stat)
    sleep 1
    cpu2=$(awk '/^cpu / {print $2+$3+$4+$5+$6+$7+$8, $5}' /proc/stat)

    local total1 idle1 total2 idle2
    total1=$(echo "$cpu1" | awk '{print $1}')
    idle1=$(echo "$cpu1" | awk '{print $2}')
    total2=$(echo "$cpu2" | awk '{print $1}')
    idle2=$(echo "$cpu2" | awk '{print $2}')

    awk -v t1="$total1" -v i1="$idle1" -v t2="$total2" -v i2="$idle2" \
        'BEGIN { dt=t2-t1; di=i2-i1; printf "%.1f", (dt-di)/dt*100 }'
}

get_memory_usage() {
    awk '
        /^MemTotal:/     { total=$2 }
        /^MemAvailable:/ { avail=$2 }
        END { printf "%.0f", (1 - avail/total) * 100 }
    ' /proc/meminfo
}

get_disk_usage() {
    df -h / | awk 'NR==2 { gsub(/%/,"",$5); print $5 }'
}

get_top_cpu() {
    ps -eo %cpu,comm --no-headers |
        awk '{
            cpu = $1
            name = substr($0, index($0, $2), 15)
            arr[name] += cpu
        }
        END { for (i in arr) printf "%.1f %s\n", arr[i], i }' |
        sort -rnk1 |
        head -5 |
        awk '{
            cpu = $1
            name = substr($0, index($0, $2))
            printf "  %d. %s (%.1f%%)\n", ++n, name, cpu
        }'
}

get_top_mem() {
    grep -s "^Pss:" /proc/[0-9]*/smaps_rollup | awk -F'[: ]+' '
    {
        split($1, path, "/")
        pid = path[3]

        comm_file = "/proc/" pid "/comm"
        if ((getline comm < comm_file) > 0) {
            comm = substr(comm, 1, 15)
            if (comm !~ /^(ps|awk|grep|bash|cat)$/) {
                arr[comm] += $3
            }
        }
        close(comm_file)
    }
    END {
        for (i in arr) {
            if (arr[i] > 0) printf "%d %s\n", arr[i], i
        }
    }' |
        sort -rnk1 |
        head -5 |
        awk '{
            n++
            cpu = $1
            name = substr($0, index($0, $2))
            if (cpu >= 1048576) printf "  %d. %s (%.1fGB)\n", n, name, cpu/1048576
            else if (cpu >= 1024) printf "  %d. %s (%.0fMB)\n", n, name, cpu/1024
            else printf "  %d. %s (%dKB)\n", n, name, cpu
        }'
}

build_report() {
    local timestamp="$1"
    printf '\n=== Report for %s ===\n' "$timestamp"
    printf 'CPU Load:        %s\n' "$(get_cpu_load)"
    printf 'Memory Usage:    %s%%\n' "$(get_memory_usage)"
    printf 'Disk Usage (/):  %s%%\n' "$(get_disk_usage)"
    printf '\nTop processes by CPU:\n%s\n' "$(get_top_cpu)"
    printf '\nTop processes by memory:\n%s\n' "$(get_top_mem)"
}

write_report() {
    local log_dir="$1"
    local retention_days="$2"
    local log_file="$log_dir/monitor_$(date +%Y-%m-%d).log"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local report
    report="$(build_report "$timestamp")"
    echo "$report" >>"$log_file"
    echo -e "${BOLD}${report}${RESET}"
    echo -e "  ${GREEN}✔${RESET} Written to ${CYAN}${log_file}${RESET}\n"
    cleanup_old_logs "$log_dir" "$retention_days"
}

setup_trap() {
    local log_dir="$1"
    trap "echo -e \"\n${YELLOW}Monitoring stopped.${RESET} Log: ${CYAN}${log_dir}${RESET}\"; exit 0" \
        SIGINT SIGTERM
}

main() {
    check_args "$@"
    local log_dir="$1"
    local interval="${2:-60}"
    local retention_days
    retention_days="$(parse_retention "$@")"

    init_log_dir "$log_dir"
    local log_file="$log_dir/monitor_$(date +%Y-%m-%d).log"
    setup_trap "$log_file"

    echo ""
    echo -e "${BOLD}Monitoring started${RESET}"
    echo -e "  Log file  : ${CYAN}${log_file}${RESET}"
    echo -e "  Interval  : ${CYAN}${interval}s${RESET}"
    if [[ -n "$retention_days" ]]; then
        echo -e "  Retention : ${CYAN}${retention_days} day(s)${RESET}"
    else
        echo -e "  Retention : ${CYAN}disabled${RESET}"
    fi
    echo -e "  Stop with : ${YELLOW}Ctrl+C${RESET}"
    echo ""

    while true; do
        write_report "$log_dir" "$retention_days"
        sleep "$interval"
    done
}

main "$@"
