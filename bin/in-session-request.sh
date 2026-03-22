#!/bin/bash
# Called when user presses Ctrl+P r
# Adds requester to FIFO queue

SESSION=$(echo "$1" | tr -d '"' | tr -d "'")
CALLER_TTY=$(echo "$2" | tr -d '"' | tr -d "'" | sed 's|/|_|g')
STATE_DIR="$HOME/cis/trace/sessions/$SESSION"
SOCKET="$STATE_DIR/tmux.sock"

# Include queue library
source "$HOME/cis/lib/queue.sh"

# Clean up expired requests before processing new one
queue_cleanup "$SESSION"

# Get username
USERNAME=$(cat "$STATE_DIR/user.$CALLER_TTY" 2>/dev/null)
[ -z "$USERNAME" ] && USERNAME="$CALLER_TTY"

# Check if already in queue (prevent duplicates)
if grep -q "$CALLER_TTY" "$STATE_DIR/queue" 2>/dev/null; then
    POSITION=$(queue_position "$SESSION" "$CALLER_TTY")
    tmux -S "$SOCKET" send-keys -t "$(echo $CALLER_TTY | sed 's|_|/|g')" "echo 'Already in queue at position $POSITION'" Enter
    exit 0
fi

# Check if already controller (no need to request)
CURRENT_CONTROLLER=$(cat "$STATE_DIR/controller" 2>/dev/null)
if [ "$CURRENT_CONTROLLER" = "$CALLER_TTY" ]; then
    tmux -S "$SOCKET" send-keys -t "$(echo $CALLER_TTY | sed 's|_|/|g')" "echo 'You are already controller'" Enter
    exit 0
fi

# Add to queue with timestamp
queue_add "$SESSION" "$CALLER_TTY"
POSITION=$(queue_position "$SESSION" "$CALLER_TTY")
TOTAL=$(queue_count "$SESSION")

# Notify requester of their position
REAL_CALLER=$(echo "$CALLER_TTY" | sed 's|_|/|g')
tmux -S "$SOCKET" send-keys -t "$REAL_CALLER" "echo 'Request added - position $POSITION of $TOTAL'" Enter

# Notify host of new request
HOST_TTY=$(cat "$STATE_DIR/host_tty" 2>/dev/null)
if [ -n "$HOST_TTY" ]; then
    REAL_HOST=$(echo "$HOST_TTY" | sed 's|_|/|g')
    tmux -S "$SOCKET" send-keys -t "$REAL_HOST" "echo 'REQUEST: $USERNAME (position $POSITION)'" Enter
fi

# Log the request
echo "$(date '+%Y-%m-%d %H:%M:%S') - REQUEST: User $USERNAME (TTY: $CALLER_TTY) added to queue position $POSITION" >> "$STATE_DIR/session.log"