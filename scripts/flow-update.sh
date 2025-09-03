#!/bin/bash

# Flow Context Update Manager
# Single script to handle daily flow context updates with tmux daemon support

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_DIR/logs"
SESSION_NAME="flow-update-daemon"
NETWORK="${FLOW_UPDATE_NETWORK:-zgTestnetTurbo}"

# Create logs directory
mkdir -p "$LOG_DIR"

# Logging function
log() {
    local log_file="$LOG_DIR/flow-update-$(date +%Y%m%d).log"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$log_file"
}

# Check if tmux session exists
session_exists() {
    tmux has-session -t "$SESSION_NAME" 2>/dev/null
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
            sleep $sleep_seconds
        fi
        
        # Run update if we should
        if should_run_today; then
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
    if session_exists; then
        echo "Daemon already running in tmux session '$SESSION_NAME'"
        return 1
    fi
    
    echo "Starting flow update daemon..."
    tmux new-session -d -s "$SESSION_NAME" -c "$PROJECT_DIR" \
        "cd '$PROJECT_DIR' && FLOW_UPDATE_NETWORK='$NETWORK' DEPLOYER_KEY='$DEPLOYER_KEY' '$0' _daemon_loop"
    
    echo "Daemon started in tmux session '$SESSION_NAME'"
    echo "Use '$0 attach' to view or '$0 logs' to see logs"
}

# Stop daemon
stop_daemon() {
    if ! session_exists; then
        echo "Daemon not running"
        return 1
    fi
    
    tmux kill-session -t "$SESSION_NAME"
    echo "Daemon stopped"
}

# Show status
show_status() {
    echo "Flow Update Daemon Status:"
    echo "  Network: $NETWORK"
    echo "  Private Key: ${DEPLOYER_KEY:+✓ Configured}${DEPLOYER_KEY:-⚠ Not set (using default)}"
    
    if session_exists; then
        echo "  Status: ✓ Running in tmux session '$SESSION_NAME'"
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
    attach)
        if session_exists; then
            tmux attach -t "$SESSION_NAME"
        else
            echo "Daemon not running. Use '$0 start' to start it."
        fi
        ;;
    run)
        run_update
        ;;
    _daemon_loop)
        daemon_loop
        ;;
    help|--help|-h)
        echo "Usage: $0 {start|stop|restart|status|logs|attach|run}"
        echo ""
        echo "Commands:"
        echo "  start   - Start daemon (runs daily at 2 AM)"
        echo "  stop    - Stop daemon"
        echo "  restart - Restart daemon"
        echo "  status  - Show status"
        echo "  logs    - View logs"
        echo "  attach  - Attach to tmux session"
        echo "  run     - Run update once manually"
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
