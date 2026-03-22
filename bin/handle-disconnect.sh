#!/bin/bash
# Called when any client detaches from tmux session
# Cleans up stale files and handles controller departure

SESSION=$(echo "$1" | tr -d '"' | tr -d "'")
STATE_DIR="$HOME/cis/trace/sessions/$SESSION"
SOCKET="$STATE_DIR/tmux.sock"

# If session folder doesn't exist
if [ ! -d "$STATE_DIR" ]; then
    exit 0
fi

# Read current state
HOST_TTY=$(cat "$STATE_DIR/host_tty" 2>/dev/null)
CURRENT_CONTROLLER=$(cat "$STATE_DIR/controller" 2>/dev/null)
REAL_HOST=$(echo "$HOST_TTY" | sed 's|_|/|g')

# Get all currently attached TTYs from tmux
ACTIVE_TTYS=$(tmux -S "$SOCKET" list-clients -t "$SESSION" -F "#{client_tty}" 2>/dev/null | sed 's/\//_/g')

# Check each role file to find who left
for role_file in "$STATE_DIR"/role.*; do
    if [ -f "$role_file" ]; then
        TTY=$(basename "$role_file" | cut -d. -f2)
        
        # If this TTY is not in active list, they disconnected
        if ! echo "$ACTIVE_TTYS" | grep -q "$TTY"; then
            
            # Case 1: Host disconnected - kill entire session
            if [ "$TTY" = "$HOST_TTY" ]; then
                echo "$(date '+%Y-%m-%d %H:%M:%S') - HOST DISCONNECT: Session ended due to host disconnect" >> "$STATE_DIR/session.log"
                tmux -S "$SOCKET" kill-session -t "$SESSION" 2>/dev/null
                rm -rf "$STATE_DIR" 2>/dev/null
                rm -f "$SOCKET" 2>/dev/null
                exit 0
            fi
            
            # Get username for logging
            USERNAME=$(cat "$STATE_DIR/user.$TTY" 2>/dev/null)
            
            # Remove from queue if present
            if [ -f "$STATE_DIR/queue" ]; then
                sed -i.bak "/$TTY/d" "$STATE_DIR/queue" 2>/dev/null
            fi
            
            # Case 2: Controller disconnected - return control to host
            if [ "$TTY" = "$CURRENT_CONTROLLER" ]; then
                echo "$(date '+%Y-%m-%d %H:%M:%S') - DISCONNECT: Controller $USERNAME disconnected, control returned to Host" >> "$STATE_DIR/session.log"
                echo "$HOST_TTY" > "$STATE_DIR/controller"
                echo "controller" > "$STATE_DIR/role.$HOST_TTY"
                
                # Unlock host's keyboard
                tmux -S "$SOCKET" switch-client -c "$REAL_HOST" -r
                tmux -S "$SOCKET" send-keys -t "$REAL_HOST" "echo 'Control safely returned to Host'" Enter
            else
                # Case 3: Observer disconnected - just log it
                echo "$(date '+%Y-%m-%d %H:%M:%S') - DISCONNECT: User $USERNAME left session" >> "$STATE_DIR/session.log"
            fi
            
            # Clean up their files
            rm -f "$STATE_DIR/role.$TTY" "$STATE_DIR/user.$TTY" 2>/dev/null
            
        fi
    fi
done

exit 0