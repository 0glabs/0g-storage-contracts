# Flow Context Update Daemon

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

