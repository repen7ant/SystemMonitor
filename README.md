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

Default interval for systemd service is 1 hour.
To change the log directory or interval, edit `ExecStart` in `monitor.service`, then run `daemon-reload` and `restart`.

## Requirements

- Linux
- Bash 4+
- Standard utilities: `ps`, `df`, `awk`, `uptime`
