# SystemMonitor

A Bash script that periodically collects system metrics and writes them to a log file.

## What it collects

- CPU load (1-minute average)
- RAM usage (%)
- Disk usage (`/`)
- Top 5 processes by CPU and by memory

## Usage

```bash
chmod +x monitor.sh
./monitor.sh <log_directory> [interval_seconds]
```

```bash
# Example: write logs to /var/log/sysmon every 30 seconds
./monitor_v3.sh /var/log/sysmon 30
```

Stop with `Ctrl+C`.

## Log file

Created automatically, named by date: `monitor_2026-03-18.log`.  
A new file is created each day during long-running sessions.

## Requirements

- Linux
- Bash 4+
- Standard utilities: `ps`, `df`, `awk`, `uptime`
