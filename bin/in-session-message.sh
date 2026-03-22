#!/bin/bash
# Called when user presses Ctrl+P m
# Broadcasts a message to all participants

SESSION=$(echo "$1" | tr -d '"' | tr -d "'")
CALLER_TTY=$(echo "$2" | tr -d '"' | tr -d "'" | sed 's|/|_|g')
MESSAGE="$3"
STATE_DIR="$HOME/cis/trace/sessions/$SESSION"
SOCKET="$STATE_DIR/tmux.sock"

# Get sender's username
SENDER=$(cat "$STATE_DIR/user.$CALLER_TTY" 2>/dev/null)
[ -z "$SENDER" ] && SENDER="Host"

# Broadcast message to every active participant
for role_file in "$STATE_DIR"/role.*; do
    if [ -f "$role_file" ]; then
        TTY=$(basename "$role_file" | cut -d. -f2)
        REAL_TTY=$(echo "$TTY" | sed 's|_|/|g')
        tmux -S "$SOCKET" send-keys -t "$REAL_TTY" "echo '[$SENDER]: $MESSAGE'" Enter
    fi
done

# Log the message
echo "$(date '+%Y-%m-%d %H:%M:%S') - MESSAGE: $SENDER: $MESSAGE" >> "$STATE_DIR/session.log"