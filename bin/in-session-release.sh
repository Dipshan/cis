#!/bin/bash
# Called when controller presses Ctrl+P 1
# Returns control to next in queue if available, otherwise to host

SESSION=$(echo "$1" | tr -d '"' | tr -d "'")
CALLER_TTY=$(echo "$2" | tr -d '"' | tr -d "'" | sed 's|/|_|g')
STATE_DIR="$HOME/cis/trace/sessions/$SESSION"
SOCKET="$STATE_DIR/tmux.sock"

# Get current state
CURRENT_CONTROLLER=$(cat "$STATE_DIR/controller" 2>/dev/null)
HOST_TTY=$(cat "$STATE_DIR/host_tty" 2>/dev/null)

# Security: Only current controller can release
if [ "$CURRENT_CONTROLLER" != "$CALLER_TTY" ]; then
    exit 1
fi

# Get username for logging
USERNAME=$(cat "$STATE_DIR/user.$CALLER_TTY" 2>/dev/null)

# Remove them from queue if they were in it
sed -i '' "/$CALLER_TTY/d" "$STATE_DIR/queue" 2>/dev/null

# Demote caller to observer
echo "observer" > "$STATE_DIR/role.$CALLER_TTY"
REAL_CALLER=$(echo "$CALLER_TTY" | sed 's|_|/|g')
tmux -S "$SOCKET" switch-client -c "$REAL_CALLER" -r
tmux -S "$SOCKET" send-keys -t "$REAL_CALLER" "echo 'Control released'" Enter

# Check if there's someone waiting in queue
NEXT_IN_QUEUE=$(head -1 "$STATE_DIR/queue" 2>/dev/null | cut -d: -f2)

if [ -n "$NEXT_IN_QUEUE" ]; then
    # Grant control to next person in queue
    echo "$NEXT_IN_QUEUE" > "$STATE_DIR/controller"
    echo "controller" > "$STATE_DIR/role.$NEXT_IN_QUEUE"
    
    # Remove them from queue (they're now controller)
    sed -i '' "1d" "$STATE_DIR/queue" 2>/dev/null
    
    # Notify new controller
    REAL_NEXT=$(echo "$NEXT_IN_QUEUE" | sed 's|_|/|g')
    tmux -S "$SOCKET" switch-client -c "$REAL_NEXT" -r
    tmux -S "$SOCKET" send-keys -t "$REAL_NEXT" "echo 'You are now controller'" Enter
    
    # Log
    NEXT_USER=$(cat "$STATE_DIR/user.$NEXT_IN_QUEUE" 2>/dev/null)
    echo "$(date '+%Y-%m-%d %H:%M:%S') - RELEASE: $USERNAME released, control passed to $NEXT_USER" >> "$STATE_DIR/session.log"
else
    # No one in queue, return control to host
    echo "$HOST_TTY" > "$STATE_DIR/controller"
    echo "controller" > "$STATE_DIR/role.$HOST_TTY"
    REAL_HOST=$(echo "$HOST_TTY" | sed 's|_|/|g')
    tmux -S "$SOCKET" switch-client -c "$REAL_HOST" -r
    tmux -S "$SOCKET" send-keys -t "$REAL_HOST" "echo 'Control returned to Host'" Enter
    
    # Log
    echo "$(date '+%Y-%m-%d %H:%M:%S') - RELEASE: $USERNAME released, returned to Host" >> "$STATE_DIR/session.log"
fi