#!/usr/bin/env bats

# Bats tests for tests/staging/initialize_env.bats
# Framework: Bats (bats-core)
# These tests source the script under test and stub external commands via PATH.

setup() {
  # Create a temp bin for stubs and prepend to PATH
  STUB_DIR="${BATS_TEST_TMPDIR}/stubbin"
  mkdir -p "${STUB_DIR}"
  PATH="${STUB_DIR}:$PATH"

  # Stub uname to provide deterministic kernel version
  cat > "${STUB_DIR}/uname" <<'STUB'
#!/usr/bin/env bash
if [[ "${1:-}" == "-r" ]]; then
  echo "5.10.0-fake"
else
  # Fallback minimal behavior
  /usr/bin/env uname "$@"
fi
STUB
  chmod +x "${STUB_DIR}/uname"

  # Stub ip with mode controlled by FAKE_IP_MODE env var:
  # - route_present: has default route on eth0, IPv4 192.168.1.100/24
  # - no_route: no default route
  cat > "${STUB_DIR}/ip" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
mode="${FAKE_IP_MODE:-route_present}"

if [[ "$mode" == "route_present" ]]; then
  # ip -4 route ls
  if [[ "${1:-}" == "-4" && "${2:-}" == "route" ]]; then
    echo "default via 192.168.1.1 dev eth0 proto dhcp src 192.168.1.100 metric 100"
    exit 0
  fi
  # ip -4 addr show dev eth0
  if [[ "${1:-}" == "-4" && "${2:-}" == "addr" && "${3:-}" == "show" && "${4:-}" == "dev" ]]; then
    if [[ "${5:-}" == "eth0" ]]; then
      printf '2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500\n    inet 192.168.1.100/24 brd 192.168.1.255 scope global dynamic eth0\n'
      exit 0
    fi
  fi
elif [[ "$mode" == "no_route" ]]; then
  if [[ "${1:-}" == "-4" && "${2:-}" == "route" ]]; then
    # No default route output
    exit 0
  fi
  if [[ "${1:-}" == "-4" && "${2:-}" == "addr" ]]; then
    # No addr entries
    exit 0
  fi
fi

# For any other calls, behave quietly
exit 0
STUB
  chmod +x "${STUB_DIR}/ip"

  # Source the script under test (sourcing avoids triggering its CLI entrypoint)
  source "${BATS_TEST_DIRNAME}/initialize_env.bats"
}

teardown() {
  true
}

@test "initialize_env help prints usage via all help aliases" {
  run initialize_env help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: initialize_env"* ]]

  run initialize_env -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: initialize_env"* ]]

  run initialize_env --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: initialize_env"* ]]
}

@test "initialize_env default initializes and exports key variables (route present)" {
  FAKE_IP_MODE=route_present
  run bash -lc 'initialize_env; env | sort'
  [ "$status" -eq 0 ]

  # Confirm exported path variables exist
  [[ "$output" == *"BIN_ROOT="* ]]
  [[ "$output" == *"LIB_ROOT="* ]]
  [[ "$output" == *"WEB_ROOT="* ]]
  [[ "$output" == *"DOC_ROOT="* ]]
  [[ "$output" == *"SHARE_ROOT="* ]]

  # Confirm system/network exports exist
  [[ "$output" == *"DISTRO="* ]]
  [[ "$output" == *"KERNELID=5.10.0-fake"* ]]

  # Confirm network derivations under route_present
  [[ "$output" == *"DEFAULT_ADAPTER=eth0"* ]]
  [[ "$output" == *"LOCALIPADD=192.168.1.100"* ]]
  [[ "$output" == *"LOCALSUBNET=192.168.1.0/24"* ]]

  # Validate BIN_ROOT equals the directory of the source file
  expected_bin_root="$(cd "${BATS_TEST_DIRNAME}" && pwd)"
  # Recompute BIN_ROOT in current shell after initialize_env
  initialize_env
  [ "$BIN_ROOT" = "$expected_bin_root" ]
  [ "$LIB_ROOT" = "${expected_bin_root}/../LIB" ]
  [ "$WEB_ROOT" = "${expected_bin_root}/../html" ]
  [ "$DOC_ROOT" = "${expected_bin_root}/../doc" ]
  [ "$SHARE_ROOT" = "${expected_bin_root}/../share" ]
}

@test "initialize_env honors environment overrides: BACKTITLE and VENDOR->TITLE; handles empty values with defaults" {
  # BACKTITLE set explicitly
  BACKTITLE="Custom Back" VENDOR="AcmeCorp" FAKE_IP_MODE=route_present run bash -lc 'initialize_env; echo "::${BACKTITLE}::${TITLE}::"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"::Custom Back::AcmeCorp configuration utility::"* ]]

  # BACKTITLE empty should fall back to default, VENDOR empty should fall back to 'Armbian'
  BACKTITLE="" VENDOR="" FAKE_IP_MODE=route_present run bash -lc 'initialize_env; echo "::${BACKTITLE}::${TITLE}::"'
  [ "$status" -eq 0 ]
  # Default BACKTITLE string and default TITLE prefix expected
  [[ "$output" == *"::Contribute: https://github.com/armbian/configng::Armbian configuration utility::"* ]]
}

@test "initialize_env handles absence of default route gracefully (empty adapter/ip/subnet)" {
  FAKE_IP_MODE=no_route run bash -lc 'initialize_env; echo "A=${DEFAULT_ADAPTER:-unset} I=${LOCALIPADD:-unset} S=${LOCALSUBNET:-unset}"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"A= I= S="* ]]
}

@test "initialize_env show prints structured sections and reflects network values (route present)" {
  FAKE_IP_MODE=route_present run initialize_env show
  [ "$status" -eq 0 ]

  # Headers
  [[ "$output" == *"=== Environment Variables ==="* ]]
  [[ "$output" == *"[Paths]"* ]]
  [[ "$output" == *"[System]"* ]]
  [[ "$output" == *"[UI]"* ]]
  [[ "$output" == *"[Network]"* ]]
  [[ "$output" == *"[OS Files]"* ]]
  [[ "$output" == *"=== OS Release File Contents ==="* ]]
  [[ "$output" == *"=== OS Info File Contents ==="* ]]

  # Selected values
  [[ "$output" == *"DEFAULT_ADAPTER : eth0"* ]]
  [[ "$output" == *"LOCALIPADD      : 192.168.1.100"* ]]
  [[ "$output" == *"LOCALSUBNET     : 192.168.1.0/24"* ]]
  [[ "$output" == *"KERNELID     : 5.10.0-fake"* ]]

  # OS Info section: allow either branch depending on host environment
  echo "$output" | grep -Eq '(\[OS Info File: /etc/os-release\]|OS info file not found or not readable: /etc/os-release)'
  # Armbian release branch: allow either presence or not readable
  echo "$output" | grep -Eq '(\[Armbian Release File: /etc/armbian-release\]|Armbian release file not found or not readable: /etc/armbian-release)'
}

@test "initialize_env with unknown argument still initializes env (default branch)" {
  FAKE_IP_MODE=route_present run bash -lc 'initialize_env foobar; echo "OK:${DEFAULT_ADAPTER}:${LOCALIPADD}:${LOCALSUBNET}"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK:eth0:192.168.1.100:192.168.1.0/24"* ]]
}