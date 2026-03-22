# CIS - Collaborative Interactive Shell

## Authors
- Anuska Bhattarai (800832698) - anuskbh@siue.edu
- Deepshan Adhikari (800846035) - deepadh@siue.edu
- Sumit Shrestha (800835513) - sumishr@siue.edu

## Course
CS514 - Operating Systems  
Instructor: Dr. Igor Crk  
Southern Illinois University Edwardsville
Department of Computer Science

## Features
- One host creates a session, multiple observers can join
- Real-time output broadcasting to all participants
- Floor control: request, grant, and release control
- FIFO queue for control requests
- Observer menu for easy control management
- Participant listing with current controller indicated
- Chat messaging between all participants
- Host can kick users from session
- Automatic cleanup on disconnect
- Traces session logging
- Multi-laptop support via SSH

## Requirements
- tmux 3.0 or higher
- Bash shell
- SSH client (for multi-laptop usage)
- macOS or Linux

## Installation

### Prerequisites
```bash
# Check if tmux is installed
tmux -V

# If not installed:
# macOS
brew install tmux

# Ubuntu/Debian
sudo apt install tmux
```

```bash
# Create directory structure
mkdir -p ~/cis/{bin,etc,lib,trace/sessions}

# Navigate to CIS directory
cd ~/cis

# Copy all scripts to appropriate folders (assuming you have the files in current directory)
cp bin/* ~/cis/bin/
cp etc/* ~/cis/etc/
cp lib/* ~/cis/lib/

# Make all scripts executable
chmod +x ~/cis/bin/*
```

## Project Folder Structure
```bash
~/cis/
│
├── bin/                             # Executable scripts
│   ├── cis                          # Main wrapper script
│   ├── handle-disconnect.sh         # Cleanup on client disconnect
│   ├── in-session-grant.sh          # Grant control to user
│   ├── in-session-kick.sh           # Kick user from session
│   ├── in-session-message.sh        # Broadcast chat messages
│   ├── in-session-release.sh        # Release control
│   ├── in-session-request.sh        # Request control
│   └── in-session-who.sh            # List participants
│
├── etc/                             # Configuration files
│   └── collaborative-tmux.conf      # tmux configuration
│
├── lib/                             # Library files
│   └── queue.sh                     # Queue management functions
│
└── trace/                           # Session logs
    └── sessions/                    # Session lists
        └── [session-name]/          # Example: test/, demo/, etc.
            ├── controller           # Current controller TTY
            ├── host_tty             # Host's TTY identifier
            ├── queue                # FIFO request queue
            ├── session.log          # Event log with timestamps
            ├── tmux.sock            # tmux socket for this session
            ├── role.*               # One file per user: e.g.: role._dev_ttys000
            └── user.*               # One file per user: e.g.: user._dev_ttys000
```

## Usage Guide

### Starting a Session (Host)

- For this project we kept our main cis folder in root of the system.

```bash
cd ~/cis/bin
./cis host <session-name>
```

### Joining a Session (Observer)
```bash
cd ~/cis/bin
./cis join host_username <session-name>

# To set a custom username while testing in the same terminal:
USER="username" ./cis join host_username <session-name>
```

### Ending a Session (only by Host)
```bash
./cis end <session-name>

// OR simply press ctrl+d or type exit command
```

## In-Session Commands

Press "Ctrl+P" followed by a key to execute commands:

|-----|------------------|-----------------------------------------------------------------------|
| Key | Action           | Description                                                           |
|-----|------------------|-----------------------------------------------------------------------|
| d   | Request control  | Opens observer menu to request queue position (in observer terminal)  |
| 1   | Release control  | Current controller gives up control (passes to next in queue)         |
| w   | Who              | Lists all participants and current queue                              |
| m   | Message          | Broadcast message to all participants                                 |
| g   | Grant            | Host grants control to specific user (prompts for username)           |
| k   | Kick             | Host removes user from session (prompts for username)                 |
|-----|------------------|-----------------------------------------------------------------------|


## Observer Menu Options

When an observer presses "Ctrl+P" and d, they see:

```bash
╔════════════════════════════════════════════════════════════╗
║                 CIS - OBSERVER MENU                        ║
╚════════════════════════════════════════════════════════════╝
  1) Request Control
  2) Return to Session (Read-Only)
  3) Leave Session Completely

Choose an option (1-3):
```

## Out-of-Band Commands (regular terminal)

cis list <host_username>	            List active sessions on host machine
cis request <host_username> <session>	Request control from outside (adds to queue)
cis end <session>	                    End session (only by Host)


## Multi-Laptop Usage

Ensure both laptops are on same network

Copy CIS folder to both laptops or use shared storage

On Laptop A (Host):
```bash
cd ~/cis/bin
./cis host <session-name>
```

On Laptop B (Observer):

```bash
ssh host_username@host_laptop_ip_address
cd ~/cis/bin
./cis join host_username <session-name>
```

## Logs and Traces

- All session logs are stored in:
```bash
~/cis/trace/sessions/<session-name>/session.log
```