#!/bin/bash
echo "Content-type: application/json"
echo ""

# Helpers
json_array() {
    local arr=("$@")
    local jq_input
    jq_input=$(printf '%s\n' "${arr[@]}" | jq -R . | jq -s .)
    echo "$jq_input"
}

json_object() {
    local key="$1"; shift
    local value="$1"; shift
    jq -n --arg k "$key" --arg v "$value" '{($k):$v}'
}

# System
system_info=$(uname -a)
os_release=()
while IFS= read -r line; do os_release+=("$line"); done < /etc/os-release 2>/dev/null
uptime_info=$(uptime -p)

# Bash
bash_version=$(bash --version | head -n1)
shells=()
while IFS= read -r line; do shells+=("$line"); done < /etc/shells

# CPU / Memory / Disk
cpu_info=()
while IFS= read -r line; do cpu_info+=("$line"); done < <(lscpu 2>/dev/null || head -n 10 /proc/cpuinfo)
mem_info=()
while IFS= read -r line; do mem_info+=("$line"); done < <(free -h | tail -n +2)
disk_info=()
while IFS= read -r line; do disk_info+=("$line"); done < <(df -h | head -n 10)

# Environment
env_vars=()
while IFS= read -r line; do env_vars+=("$line"); done < <(env)

# Tools
tools=()
for cmd in git curl python3 node gcc make; do
    path=$(which "$cmd" 2>/dev/null || echo "not found")
    tools+=("{\"$cmd\":\"$path\"}")
done
tools_json=$(printf '%s\n' "${tools[@]}" | jq -s '.')

# Networking
hostname_ip=$(hostname -I 2>/dev/null)
connections=()
while IFS= read -r line; do connections+=("$line"); done < <(netstat -tunlp 2>/dev/null | head -n 10)

# Compose JSON safely with jq
jq -n \
    --arg system "$system_info" \
    --arg uptime "$uptime_info" \
    --arg bash_version "$bash_version" \
    --arg hostname_ip "$hostname_ip" \
    --argjson os_release "$(json_array "${os_release[@]}")" \
    --argjson shells "$(json_array "${shells[@]}")" \
    --argjson cpu "$(json_array "${cpu_info[@]}")" \
    --argjson memory "$(json_array "${mem_info[@]}")" \
    --argjson disk "$(json_array "${disk_info[@]}")" \
    --argjson environment "$(json_array "${env_vars[@]}")" \
    --argjson tools "$tools_json" \
    --argjson connections "$(json_array "${connections[@]}")" \
    '{
        system: $system,
        os_release: $os_release,
        uptime: $uptime,
        bash: {version: $bash_version, shells: $shells},
        cpu_memory_disk: {cpu: $cpu, memory: $memory, disk: $disk},
        environment: $environment,
        tools: $tools,
        networking: {hostname_ip: $hostname_ip, connections: $connections}
    }'
