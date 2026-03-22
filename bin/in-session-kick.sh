#!/bin/bash
# Called when host presses Ctrl+P k
# Removes a user from the session

SESSION=$(echo "$1" | tr -d '"' | tr -d "'")
CALLER_TTY=$(echo "$2" | tr -d '"' | tr -d "'" | sed 's|/|_|g')
TARGET_USER=$(echo "$3" | tr -d '"' | tr -d "'")
STATE_DIR="$HOME/cis/trace/sessions/$SESSION"
SOCKET="$STATE_DIR/tmux.sock"

# Get host TTY
HOST_TTY=$(cat "$STATE_DIR/host_tty" 2>/dev/null)
REAL_CALLER=$(echo "$CALLER_TTY" | sed 's|_|/|g')

# Security: Only host can kick users
if [ "$CALLER_TTY" != "$HOST_TTY" ]; then
    tmux -S "$SOCKET" send-keys -t "$REAL_CALLER" "echo 'Only the Host can kick users.'" Enter
    exit 0
fi

# Find target user's TTY
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

# Prevent kicking the host
if [ "$TARGET_TTY" = "$HOST_TTY" ]; then
    tmux -S "$SOCKET" send-keys -t "$REAL_CALLER" "echo 'Cannot kick the Host!'" Enter
    exit 0
fi

# Convert TTY back to path format for tmux
REAL_TTY=$(echo "$TARGET_TTY" | sed 's|_|/|g')

# Create kick marker file (detected by observer menu)
touch "$STATE_DIR/kicked.$TARGET_TTY"

# Detach the target client
tmux -S "$SOCKET" detach-client -t "$REAL_TTY"

# Clean up their files
rm -f "$STATE_DIR/role.$TARGET_TTY" "$STATE_DIR/user.$TARGET_TTY"

# Notify everyone
tmux -S "$SOCKET" send-keys -t "$REAL_CALLER" "echo '$TARGET_USER was kicked from the session.'" Enter

# Log the kick
echo "$(date '+%Y-%m-%d %H:%M:%S') - KICK: Host kicked user $TARGET_USER from session" >> "$STATE_DIR/session.log"
exit 0