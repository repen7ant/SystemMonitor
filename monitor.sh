#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

usage() {
    echo -e "${CYAN}Usage:${RESET} $0 <log_directory> [interval_seconds]"
    echo ""
    echo "  <log_directory>      Required. Path to the directory for log files."
    echo "  [interval_seconds]   Optional. Collection interval in seconds (default: 60)."
    echo ""
    echo -e "${CYAN}Example:${RESET} $0 /var/log/sysmon 30"
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
    uptime |
        awk -F'[,:]' '{
            for (i=NF; i>=1; i--) {
                if ($i ~ /[0-9]+\.[0-9]+/) { print $i; break }
            }
        }' |
        awk '{print $1}'
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
    ps -eo %cpu,comm --sort=-%cpu |
        awk 'NR>1 && $1>0 && $2!="ps" { printf "  %d. %s (%.1f%%)\n", ++n, $2, $1 }' |
        head -5
}

get_top_mem() {
    ps -eo rss,comm --sort=-rss |
        awk 'NR>1 && $1>0 {
            if ($1 >= 1048576)
                printf "  %d. %s (%.1fGB)\n", ++n, $2, $1/1048576
            else if ($1 >= 1024)
                printf "  %d. %s (%.0fMB)\n", ++n, $2, $1/1024
            else
                printf "  %d. %s (%dKB)\n",   ++n, $2, $1
          }' |
        head -5
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
    local log_file="$log_dir/monitor_$(date +%Y-%m-%d).log"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    local report
    report="$(build_report "$timestamp")"

    echo "$report" >>"$log_file"

    echo -e "${BOLD}${report}${RESET}"
    echo -e "  ${GREEN}✔${RESET} Written to ${CYAN}${log_file}${RESET}\n"
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

    init_log_dir "$log_dir"

    local log_file="$log_dir/monitor_$(date +%Y-%m-%d).log"

    setup_trap "$log_file"

    echo ""
    echo -e "${BOLD}Monitoring started${RESET}"
    echo -e "  Log file : ${CYAN}${log_file}${RESET}"
    echo -e "  Interval : ${CYAN}${interval}s${RESET}"
    echo -e "  Stop with: ${YELLOW}Ctrl+C${RESET}"
    echo ""

    while true; do
        write_report "$log_dir"
        sleep "$interval"
    done
}

main "$@"
