#!/usr/bin/env bash

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <log_directory> [interval_seconds]"
    exit 1
fi

LOG_DIR="$1"
INTERVAL="${2:-60}"

if ! [[ "$INTERVAL" =~ ^[0-9]+$ ]] || [[ "$INTERVAL" -lt 1 ]]; then
    echo "Error: interval must be a positive integer"
    exit 1
fi

mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/monitor_$(date +%Y-%m-%d).log"

while true; do
    TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
    CPU_LOAD="$(uptime | awk -F'[,:]' '{for(i=NF;i>=1;i--){if($i~/[0-9]+\.[0-9]+/){print $i;break}}}' | awk '{print $1}')"
    MEM_USAGE="$(awk '/^MemTotal:/{total=$2}/^MemAvailable:/{avail=$2}END{printf "%.0f",(1-avail/total)*100}' /proc/meminfo)"
    DISK_USAGE="$(df -h / | awk 'NR==2{gsub(/%/,"",$5);print $5}')"
    TOP_CPU="$(ps -eo comm,%cpu --sort=-%cpu | awk 'NR>1&&$2>0{printf "  %d. %s (%.1f%%)\n",NR-1,$1,$2}' | head -5)"
    TOP_MEM="$(ps -eo comm,rss --sort=-rss | awk 'NR>1&&$2>0{if($2>=1048576)printf "  %d. %s (%.1fGB)\n",NR-1,$1,$2/1048576;else if($2>=1024)printf "  %d. %s (%.0fMB)\n",NR-1,$1,$2/1024;else printf "  %d. %s (%dKB)\n",NR-1,$1,$2}' | head -5)"

    {
        echo ""
        echo "=== Report for ${TIMESTAMP} ==="
        echo "CPU Load:        ${CPU_LOAD}"
        echo "Memory Usage:    ${MEM_USAGE}%"
        echo "Disk Usage (/):  ${DISK_USAGE}%"
        echo ""
        echo "Top processes by CPU:"
        echo "${TOP_CPU}"
        echo ""
        echo "Top processes by memory:"
        echo "${TOP_MEM}"
    } >>"$LOG_FILE"

    sleep "$INTERVAL"
done
