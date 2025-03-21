#!/bin/bash

CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}')
MEM_USAGE=$(free | grep Mem | awk '{print ($3/$2) * 100.0}')

THRESHOLD=75.0

if (( $(echo "$CPU_USAGE > $THRESHOLD" | bc -l) )) || (( $(echo "$MEM_USAGE > $THRESHOLD" | bc -l) )); then
    echo "[WARNING] High usage detected: CPU=$CPU_USAGE%, RAM=$MEM_USAGE%"
    ./scale_to_oci.sh
else
    echo "[OK] CPU=$CPU_USAGE%, RAM=$MEM_USAGE%"
fi
