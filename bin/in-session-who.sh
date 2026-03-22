#!/bin/bash
# Called when user presses Ctrl+P w
# Shows all participants and queue status

SESSION=$(echo "$1" | tr -d '"' | tr -d "'")
CALLER_TTY=$(echo "$2" | tr -d '"' | tr -d "'" | sed 's|/|_|g')
STATE_DIR="$HOME/cis/trace/sessions/$SESSION"
SOCKET="$STATE_DIR/tmux.sock"

# Verify session exists
if [ -z "$SESSION" ] || [ ! -d "$STATE_DIR" ]; then
    tmux display-message "Session state not found for '$SESSION'"
    exit 1
fi

# Get current state
HOST_TTY=$(cat "$STATE_DIR/host_tty" 2>/dev/null)
CURRENT_CONTROLLER=$(cat "$STATE_DIR/controller" 2>/dev/null)

# Build list of participants with their roles
PARTICIPANTS=""
for role_file in "$STATE_DIR"/role.*; do
    [ -f "$role_file" ] || continue

    TTY=$(basename "$role_file" | cut -d. -f2)
    ROLE=$(cat "$role_file" 2>/dev/null)
    USERNAME=$(cat "$STATE_DIR/user.$TTY" 2>/dev/null)

    [ -n "$USERNAME" ] || USERNAME="$TTY"

    # Mark special roles
    if [ "$TTY" = "$HOST_TTY" ]; then
        PARTICIPANTS="$PARTICIPANTS HOST:$USERNAME"
    elif [ "$TTY" = "$CURRENT_CONTROLLER" ]; then
        PARTICIPANTS="$PARTICIPANTS CONTROLLER:$USERNAME"
    else
        PARTICIPANTS="$PARTICIPANTS OBSERVER:$USERNAME"
    fi
done

# Build queue list
QUEUE_USERS=""
if [ -f "$STATE_DIR/queue" ] && [ -s "$STATE_DIR/queue" ]; then
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        QTTY=$(echo "$line" | cut -d: -f2)
        QUSER=$(cat "$STATE_DIR/user.$QTTY" 2>/dev/null)
        [ -n "$QUSER" ] || QUSER="$QTTY"
        if [ -z "$QUEUE_USERS" ]; then
            QUEUE_USERS="$QUSER"
        else
            QUEUE_USERS="$QUEUE_USERS, $QUSER"
        fi
    done < "$STATE_DIR/queue"
else
    QUEUE_USERS="empty"
fi

# Display to the user who requested
tmux display-message "Participants:$PARTICIPANTS | Queue: $QUEUE_USERS"
exit 0