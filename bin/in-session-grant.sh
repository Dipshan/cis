#!/bin/bash
# Called when host presses Ctrl+P g
# Transfers control from current controller to target user

SESSION=$(echo "$1" | tr -d '"' | tr -d "'")
CALLER_TTY=$(echo "$2" | tr -d '"' | tr -d "'" | sed 's|/|_|g')
TARGET_USER=$(echo "$3" | tr -d '"' | tr -d "'")
STATE_DIR="$HOME/cis/trace/sessions/$SESSION"
SOCKET="$STATE_DIR/tmux.sock"

# Get host TTY and convert caller TTY back to path format
HOST_TTY=$(cat "$STATE_DIR/host_tty" 2>/dev/null)
REAL_CALLER=$(echo "$CALLER_TTY" | sed 's|_|/|g')

# Security: Only host can grant control
if [ "$CALLER_TTY" != "$HOST_TTY" ]; then
    tmux -S "$SOCKET" send-keys -t "$REAL_CALLER" "echo 'Only the Host can grant control.'" Enter
    exit 0
fi

# Find target user's TTY by searching user files
TARGET_TTY=""
for role_file in "$STATE_DIR"/role.*; do
    if [ -f "$role_file" ]; then
        TTY=$(basename "$role_file" | cut -d. -f2)
        if [ "$(cat "$STATE_DIR/user.$TTY" 2>/dev/null)" = "$TARGET_USER" ]; then
            TARGET_TTY="$TTY"
            break
        fi
    fi
done

# Verify user exists
if [ -z "$TARGET_TTY" ]; then
    tmux -S "$SOCKET" send-keys -t "$REAL_CALLER" "echo 'User $TARGET_USER not found.'" Enter
    exit 0
fi

# Check if already controller
OLD_CONTROLLER=$(cat "$STATE_DIR/controller" 2>/dev/null)
if [ "$OLD_CONTROLLER" = "$TARGET_TTY" ]; then
    tmux -S "$SOCKET" send-keys -t "$REAL_CALLER" "echo 'User is already the controller!'" Enter
    exit 0
fi

# Update controller file
echo "$TARGET_TTY" > "$STATE_DIR/controller"

# Update role files
if [ -n "$OLD_CONTROLLER" ] && [ -f "$STATE_DIR/role.$OLD_CONTROLLER" ]; then
    echo "observer" > "$STATE_DIR/role.$OLD_CONTROLLER"
fi
echo "controller" > "$STATE_DIR/role.$TARGET_TTY"

# Log the grant
echo "$(date '+%Y-%m-%d %H:%M:%S') - GRANT: Host granted control to $TARGET_USER (TTY: $TARGET_TTY)" >> "$STATE_DIR/session.log"

# Switch keyboard control
if [ -n "$OLD_CONTROLLER" ]; then
    REAL_OLD=$(echo "$OLD_CONTROLLER" | sed 's|_|/|g')
    tmux -S "$SOCKET" switch-client -c "$REAL_OLD" -r
    tmux -S "$SOCKET" send-keys -t "$REAL_OLD" "echo 'Control granted to $TARGET_USER'" Enter
fi

REAL_NEW=$(echo "$TARGET_TTY" | sed 's|_|/|g')
tmux -S "$SOCKET" switch-client -c "$REAL_NEW" -r
tmux -S "$SOCKET" send-keys -t "$REAL_NEW" "echo 'You are now CONTROLLER'" Enter

exit 0