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
./monitor.sh <log_directory> [interval_seconds] --retention [days]
```

```bash
# Example 1: write logs to /var/log/sysmon every 30 seconds
./monitor.sh /var/log/sysmon 30

# Example 2: write logs to /var/log/sysmon every 1 hour and retent logs for a week
./monitor.sh /var/log/sysmon 3600 --retention 7
```

Stop with `Ctrl+C`.

## Log file

Created automatically, named by date: `monitor_2026-03-18.log`.  
A new file is created each day during long-running sessions.

### Report example

```bash
=== Report for 2026-04-23 22:58:33 ===
CPU Load:        5.5
Memory Usage:    39%
Disk Usage (/):  24%

Top processes by CPU:
  1. Isolated (25.0%)
  2. firefox (8.9%)
  3. github-desktop (3.1%)
  4. Xorg (1.9%)
  5. v2ray (1.0%)

Top processes by memory:
  1. Isolated (1.7GB)
  2. firefox (907MB)
  3. Telegram (406MB)
  4. github-desktop (357MB)
  5. kitty (194MB)
```

## Running as a systemd service

Copy the script and the unit file:

```bash
sudo cp monitor.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/monitor.sh
sudo cp monitor.service /etc/systemd/system/monitor.service
```

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable monitor.service
sudo systemctl start monitor.service
```

Useful commands:

```bash
sudo systemctl status monitor.service    # check status
sudo systemctl restart monitor.service   # restart
sudo systemctl stop monitor.service      # stop
journalctl -u monitor.service -f         # follow logs
```

Default interval for systemd service is 1 hour and default logs retention value is 2 weeks.
To change the log directory, interval or retention value, edit `ExecStart` in `monitor.service`, then run `daemon-reload` and `restart`.

## Requirements

- Linux
- Bash 4+
- Standard utilities: `ps`, `df`, `awk`
