#!/usr/bin/env bash

check_args() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <log_directory> [interval_seconds]"
        exit 1
    fi

    if ! [[ "${2:-60}" =~ ^[0-9]+$ ]] || [[ "${2:-60}" -lt 1 ]]; then
        echo "Error: interval must be a positive integer"
        exit 1
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
    local log_file="$1"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    build_report "$timestamp" >>"$log_file"
}

main() {
    check_args "$@"

    local log_dir="$1"
    local interval="${2:-60}"

    mkdir -p "$log_dir"
    local log_file="$log_dir/monitor_$(date +%Y-%m-%d).log"

    while true; do
        write_report "$log_file"
        sleep "$interval"
    done
}

main "$@"
