#!/bin/bash

# Flow Context Update Manager
# Single script to handle daily flow context updates with tmux daemon support

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_DIR/logs"
PID_FILE="$LOG_DIR/flow-daemon.pid"
NETWORK="${FLOW_UPDATE_NETWORK:-zgTestnetTurbo}"

# Create logs directory
mkdir -p "$LOG_DIR"

# Logging function
log() {
    local log_file="$LOG_DIR/flow-update-$(date +%Y%m%d).log"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$log_file"
}

# Check if daemon is running
daemon_running() {
    [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null
}

# Run single update
run_update() {
    log "Starting flow context update on network: $NETWORK"
    
    if [[ -z "$DEPLOYER_KEY" ]]; then
        log "WARNING: DEPLOYER_KEY not set. Using default key for gas payments."
    fi
    
    cd "$PROJECT_DIR"
    local log_file="$LOG_DIR/flow-update-$(date +%Y%m%d).log"
    
    if npx hardhat flow:updatecontext --network "$NETWORK" >> "$log_file" 2>&1; then
        log "Flow context update completed successfully"
        return 0
    else
        log "ERROR: Flow context update failed"
        return 1
    fi
}

# Check if should run today
should_run_today() {
    local today=$(date +%Y%m%d)
    local last_run_file="$LOG_DIR/.last_run"
    
    if [[ -f "$last_run_file" ]] && [[ "$(cat "$last_run_file")" == "$today" ]]; then
        return 1
    fi
    
    echo "$today" > "$last_run_file"
    return 0
}

# Daemon loop function
daemon_loop() {
    log "Flow update daemon started (PID: $$)"
    log "Working directory: $(pwd)"
    log "Network: $NETWORK"
    log "Script path: $0"
    
    # Trap to handle graceful shutdown
    trap 'log "Daemon shutting down..."; exit 0' SIGTERM SIGINT
    
    while true; do
        # Calculate next 2 AM
        local current_time=$(date +%s)
        local today_2am=$(date -j -f "%Y-%m-%d %H:%M:%S" "$(date +%Y-%m-%d) 02:00:00" +%s 2>/dev/null || date -d "$(date +%Y-%m-%d) 02:00:00" +%s 2>/dev/null)
        
        local next_run
        if [[ $current_time -lt $today_2am ]]; then
            next_run=$today_2am
        else
            next_run=$((today_2am + 86400))
        fi
        
        local sleep_seconds=$((next_run - current_time))
        
        if [[ $sleep_seconds -gt 0 ]]; then
            log "Next update at: $(date -r $next_run '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -d "@$next_run" '+%Y-%m-%d %H:%M:%S' 2>/dev/null)"
            log "Sleeping for $sleep_seconds seconds..."
            
            # Sleep in chunks to be responsive to signals
            while [[ $sleep_seconds -gt 0 ]]; do
                local chunk=$((sleep_seconds > 300 ? 300 : sleep_seconds))
                sleep $chunk
                sleep_seconds=$((sleep_seconds - chunk))
                
                # Recalculate in case time changed
                current_time=$(date +%s)
                if [[ $current_time -ge $next_run ]]; then
                    break
                fi
            done
        fi
        
        # Run update if we should
        if should_run_today; then
            log "Running scheduled update..."
            run_update
        else
            log "Already ran today, skipping..."
        fi
        
        # Wait a minute before next check
        sleep 60
    done
}

# Start daemon
start_daemon() {
    if daemon_running; then
        echo "Daemon already running (PID: $(cat "$PID_FILE"))"
        return 1
    fi
    
    local daemon_log="$LOG_DIR/daemon-$(date +%Y%m%d-%H%M%S).log"
    
    echo "Starting flow update daemon..."
    echo "Working directory: $PROJECT_DIR"
    echo "Network: $NETWORK"
    echo "Log file: $daemon_log"
    echo "Private Key: ${DEPLOYER_KEY:+✓ Set}${DEPLOYER_KEY:-⚠ Not set (using default)}"
    
    cd "$PROJECT_DIR"
    nohup bash -c "FLOW_UPDATE_NETWORK='$NETWORK' DEPLOYER_KEY='$DEPLOYER_KEY' '$0' _daemon_loop" > "$daemon_log" 2>&1 &
    echo $! > "$PID_FILE"
    
    sleep 2
    if daemon_running; then
        echo "✓ Daemon started successfully (PID: $(cat "$PID_FILE"))"
        echo "Use '$0 logs' to view logs or '$0 stop' to stop"
        return 0
    else
        echo "ERROR: Daemon failed to start. Check log: $daemon_log"
        rm -f "$PID_FILE"
        return 1
    fi
}

# Start daemon with nohup (fallback when tmux not available)
start_daemon_nohup() {
    local pid_file="$LOG_DIR/flow-daemon.pid"
    local daemon_log="$LOG_DIR/daemon-$(date +%Y%m%d-%H%M%S).log"
    
    if [[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        echo "Daemon already running (PID: $(cat "$pid_file"))"
        return 1
    fi
    
    echo "Starting daemon with nohup..."
    echo "Log file: $daemon_log"
    
    cd "$PROJECT_DIR"
    nohup bash -c "FLOW_UPDATE_NETWORK='$NETWORK' DEPLOYER_KEY='$DEPLOYER_KEY' '$0' _daemon_loop" > "$daemon_log" 2>&1 &
    echo $! > "$pid_file"
    
    sleep 2
    if kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        echo "✓ Daemon started with PID: $(cat "$pid_file")"
        echo "Use '$0 logs' to view logs or '$0 stop' to stop"
        return 0
    else
        echo "ERROR: Daemon failed to start. Check log: $daemon_log"
        rm -f "$pid_file"
        return 1
    fi
}

# Stop daemon
stop_daemon() {
    if ! daemon_running; then
        echo "Daemon not running"
        return 1
    fi
    
    local pid=$(cat "$PID_FILE")
    kill "$pid"
    echo "Daemon stopped (PID: $pid)"
    rm -f "$PID_FILE"
}

# Show status
show_status() {
    echo "Flow Update Daemon Status:"
    echo "  Network: $NETWORK"
    echo "  Private Key: ${DEPLOYER_KEY:+✓ Configured}${DEPLOYER_KEY:-⚠ Not set (using default)}"
    
    if daemon_running; then
        echo "  Status: ✓ Running (PID: $(cat "$PID_FILE"))"
    else
        echo "  Status: ✗ Not running"
    fi
    
    # Show last run
    local last_run_file="$LOG_DIR/.last_run"
    if [[ -f "$last_run_file" ]]; then
        local last_run=$(cat "$last_run_file")
        echo "  Last run: $last_run"
    fi
}

# View logs
view_logs() {
    local latest_log=$(ls -t "$LOG_DIR"/flow-update-*.log 2>/dev/null | head -1)
    if [[ -n "$latest_log" ]]; then
        echo "Viewing: $latest_log"
        tail -f "$latest_log"
    else
        echo "No log files found"
    fi
}

# Main script
case "${1:-help}" in
    start)
        start_daemon
        ;;
    stop)
        stop_daemon
        ;;
    restart)
        stop_daemon
        sleep 2
        start_daemon
        ;;
    status)
        show_status
        ;;
    logs)
        view_logs
        ;;
    run)
        run_update
        ;;
    debug)
        echo "=== Debug Information ==="
        echo "Script: $0"
        echo "Project Dir: $PROJECT_DIR"
        echo "Network: $NETWORK"
        echo "PID File: $PID_FILE"
        echo "Daemon running: $(daemon_running && echo "Yes (PID: $(cat "$PID_FILE"))" || echo "No")"
        echo "Environment:"
        echo "  DEPLOYER_KEY: ${DEPLOYER_KEY:+Set}${DEPLOYER_KEY:-Not set}"
        echo "  FLOW_UPDATE_NETWORK: ${FLOW_UPDATE_NETWORK:-Not set (using default)}"
        echo ""
        echo "=== Testing daemon loop (will run for 10 seconds) ==="
        timeout 10 "$0" _daemon_loop || echo "Daemon loop test completed/failed"
        ;;
    test-daemon)
        echo "Testing daemon loop directly (Ctrl+C to stop)..."
        daemon_loop
        ;;
    _daemon_loop)
        daemon_loop
        ;;
    help|--help|-h)
        echo "Usage: $0 {start|stop|restart|status|logs|run|debug|test-daemon}"
        echo ""
        echo "Commands:"
        echo "  start       - Start daemon (runs daily at 2 AM)"
        echo "  stop        - Stop daemon"
        echo "  restart     - Restart daemon"
        echo "  status      - Show status"
        echo "  logs        - View logs"
        echo "  run         - Run update once manually"
        echo "  debug       - Show debug information and test daemon"
        echo "  test-daemon - Test daemon loop directly (for debugging)"
        echo ""
        echo "Environment variables:"
        echo "  DEPLOYER_KEY - Private key for gas payments (required)"
        echo "  FLOW_UPDATE_NETWORK - Network (default: zgTestnetTurbo)"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Use '$0 help' for usage"
        exit 1
        ;;
esac
