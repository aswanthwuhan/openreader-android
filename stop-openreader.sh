#!/bin/bash
# stop-openreader.sh
echo "Stopping OpenReader..."
kill -9 $(pgrep proot) 2>/dev/null
fuser -k 3004/tcp 2>/dev/null
fuser -k 8333/tcp 2>/dev/null
fuser -k 8081/tcp 2>/dev/null
fuser -k 4222/tcp 2>/dev/null
echo "All services stopped."
