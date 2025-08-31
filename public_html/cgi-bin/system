#!/bin/bash
echo "Content-type: application/json"
echo ""

# Average CPU usage
cpu=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$3+$4)*100/($2+$3+$4+$5)} END {print usage}')
cpu_int=${cpu%.*}

# Memory usage
read total used <<< $(free -b | awk 'NR==2{printf "%d %d",$2,$3}')
mem_percent=$((used*100/total))

# Top 10 processes
processes=$(ps -eo pid,pcpu,pmem,comm --sort=-pcpu | head -n 10 | awk '{
  gsub(/"/,""); 
  printf "{\"pid\":\"%s\",\"pcpu\":\"%s\",\"pmem\":\"%s\",\"cmd\":\"%s\"},",$1,$2,$3,$4
}')
processes="[${processes%,}]"

# Timestamp
ts=$(date +%s)

cat <<EOF
{
  "timestamp": $ts,
  "cpu": $cpu_int,
  "mem": $mem_percent,
  "processes": $processes
}
EOF
