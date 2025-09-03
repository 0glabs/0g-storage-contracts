# Flow Context Update Daemon

Single script to automatically update flow context daily at 2:00 AM using nohup.

## Quick Start

```bash
# Set your private key for gas payments
export DEPLOYER_KEY="your_private_key_without_0x"

# Start daemon (runs in background)
./scripts/flow-update.sh start

# Check status
./scripts/flow-update.sh status
```

## Commands

```bash
./scripts/flow-update.sh start     # Start daemon with nohup
./scripts/flow-update.sh stop      # Stop daemon  
./scripts/flow-update.sh status    # Show status and PID
./scripts/flow-update.sh logs      # View logs (real-time)
./scripts/flow-update.sh run       # Run update once manually
./scripts/flow-update.sh restart   # Restart daemon
```

## Configuration

```bash
# Required for gas payments
export DEPLOYER_KEY="your_private_key_without_0x"

# Optional network (default: zgTestnetTurbo)
export FLOW_UPDATE_NETWORK="mainnet"
```

## How It Works

- Daemon runs in background using `nohup`
- Executes `hardhat flow:updatecontext` daily at 2:00 AM
- Prevents multiple runs per day
- Comprehensive logging with timestamps
- Automatic restart capability

## Logs

- Daily logs: `logs/flow-update-YYYYMMDD.log`
- Daemon logs: `logs/daemon-YYYYMMDD-HHMMSS.log`
- PID file: `logs/flow-daemon.pid`

## Troubleshooting

```bash
# Check if running
./scripts/flow-update.sh status

# View real-time logs
./scripts/flow-update.sh logs

# Test daemon without starting
./scripts/flow-update.sh debug

# Restart if stuck
./scripts/flow-update.sh restart
```

Single script to automatically update flow context daily at 2:00 AM.

## Quick Start

```bash
# Set your private key for gas payments
export DEPLOYER_KEY="your_private_key_without_0x"
export FLOW_UPDATE_NETWORK="zgTestnetTurbo"      # Optional network

# Start daemon
./scripts/flow-update.sh start

# Check status
./scripts/flow-update.sh status
```

## Commands

```bash
./scripts/flow-update.sh start     # Start daemon in tmux
./scripts/flow-update.sh stop      # Stop daemon  
./scripts/flow-update.sh status    # Show status
./scripts/flow-update.sh logs      # View logs
./scripts/flow-update.sh attach    # Attach to tmux session
./scripts/flow-update.sh run       # Run update once manually
```

