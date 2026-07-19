#!/bin/bash
# Append an operation entry to the session log
# Usage: ./append-log.sh <session_dir> <command> <result> [status]

SESSION_DIR="$1"
COMMAND="$2"
RESULT="$3"
STATUS="${4:-ok}"

LOG_FILE="${SESSION_DIR}/operation.log.md"

cat >> "${LOG_FILE}" << EOF
### $(date '+%H:%M:%S') — \`${COMMAND}\`

- **Status**: ${STATUS}
- **Result**: ${RESULT}

EOF
