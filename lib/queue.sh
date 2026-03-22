#!/bin/bash

# Add client to queue with timestamp for FIFO ordering
queue_add() {
    SESSION=$1
    TTY=$2
    STATE_DIR="$HOME/cis/trace/sessions/$SESSION"
    echo "$(date +%s):$TTY" >> "$STATE_DIR/queue"
}

# Remove client from queue (when granted or disconnected)
queue_remove() {
    SESSION=$1
    TTY=$2
    STATE_DIR="$HOME/cis/trace/sessions/$SESSION"
    sed -i '' "/$TTY/d" "$STATE_DIR/queue" 2>/dev/null
}

# Get first client in queue (oldest timestamp)
queue_next() {
    SESSION=$1
    STATE_DIR="$HOME/cis/trace/sessions/$SESSION"
    head -1 "$STATE_DIR/queue" 2>/dev/null | cut -d: -f2
}

# Get client's position in queue (1-based)
queue_position() {
    SESSION=$1
    TTY=$2
    STATE_DIR="$HOME/cis/trace/sessions/$SESSION"
    grep -n "$TTY" "$STATE_DIR/queue" | cut -d: -f1
}

# Get total number waiting in queue
queue_count() {
    SESSION=$1
    STATE_DIR="$HOME/cis/trace/sessions/$SESSION"
    wc -l < "$STATE_DIR/queue" | tr -d ' '
}

# Remove requests older than 30 seconds
queue_cleanup() {
    SESSION=$1
    STATE_DIR="$HOME/cis/trace/sessions/$SESSION"
    NOW=$(date +%s)
    SOCKET="$STATE_DIR/tmux.sock"
    
    # Keep checking front until no more expired entries
    while true; do
        FRONT_LINE=$(head -1 "$STATE_DIR/queue" 2>/dev/null)
        [ -z "$FRONT_LINE" ] && break
        
        TIMESTAMP=$(echo "$FRONT_LINE" | cut -d: -f1)
        TTY=$(echo "$FRONT_LINE" | cut -d: -f2)
        AGE=$((NOW - TIMESTAMP))
        
        # If front expired, remove it and check new front
        if [ $AGE -ge 30 ]; then
            # Remove expired front
            sed -i '' "1d" "$STATE_DIR/queue" 2>/dev/null
            REAL_TTY=$(echo "$TTY" | sed 's|_|/|g')
            tmux -S "$SOCKET" send-keys -t "$REAL_TTY" "echo 'Your request expired (30s timeout at front of queue)'" Enter
        else
            # Front not expired, stop checking
            break
        fi
    done
}