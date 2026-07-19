#!/bin/bash
# Initialize browser-use session output directory
# Usage: ./init-session.sh [output_dir] [session_name]
#
# Creates timestamped session directory with screenshots/, data/, logs/ subdirs.
# Outputs the session directory path to stdout.

OUTPUT_DIR="${1:-./browser-results}"
SESSION_NAME="${2:-$(date +%Y%m%d_%H%M%S)}"
SESSION_DIR="${OUTPUT_DIR}/${SESSION_NAME}"

mkdir -p "${SESSION_DIR}/screenshots"
mkdir -p "${SESSION_DIR}/data"

# Initialize operation log
LOG_FILE="${SESSION_DIR}/operation.log.md"
cat > "${LOG_FILE}" << EOF
# Browser Operation Log

- **Session**: ${SESSION_NAME}
- **Started**: $(date '+%Y-%m-%d %H:%M:%S')
- **Output Dir**: ${SESSION_DIR}

## Operations

EOF

echo "${SESSION_DIR}"
