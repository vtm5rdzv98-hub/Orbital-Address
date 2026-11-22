#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

case "${1:-}" in
  '') role=viewer; username=reviewer ;;
  --operator) role=operator; username=demo-operator ;;
  *) printf 'Usage: bash tools/demo.sh [--operator]\n' >&2; exit 2 ;;
esac
if (( $# > 1 )); then
  printf 'Usage: bash tools/demo.sh [--operator]\n' >&2
  exit 2
fi

if [[ ! -d telemetry-bridge/node_modules/jose ]]; then
  printf 'Install the bridge dependencies with npm ci --prefix telemetry-bridge.\n' >&2
  exit 1
fi

# Supply the pinned Three.js browser runtime excluded from source control.
bash tools/prepare-three.sh

site_url=http://127.0.0.1:8090
bridge_url=http://127.0.0.1:8080
state=$(mktemp -d /tmp/orbital-address-demo.XXXXXXXX)
pids=()

cleanup() {
  if [[ ${pids[0]+started} ]]; then
    kill "${pids[@]}" 2>/dev/null || true
    wait "${pids[@]}" 2>/dev/null || true
  fi
  rm -rf -- "$state"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

demo_password=$(node -e "process.stdout.write(require('node:crypto').randomBytes(12).toString('base64url'))")
printf '%s\n' "$demo_password" |
  node telemetry-bridge/tools/auth-user.mjs "$state/auth.json" "$username" "$role" >/dev/null

command_token=''
target_host=''
target_port=''
if [[ $role == operator ]]; then
  command_token=$(node -e "process.stdout.write(require('node:crypto').randomBytes(24).toString('base64url'))")
  target_host=127.0.0.1
  target_port=3341
fi

# Start from a clean environment so local or production settings cannot enter the demo.
env -i PATH="$PATH" AUTH_ENABLED=true AUTH_ALLOW_LOCAL_HTTP=true AUTH_ORIGIN="$site_url" \
  AUTH_CONFIG_PATH="$state/auth.json" HTTP_BIND_ADDRESS=127.0.0.1 UDP_BIND_ADDRESS=127.0.0.1 \
  HEX_DEVICE_ID=portfolio-simulator RECORDING_DB_PATH="$state/demo.sqlite" \
  COMMAND_TOKEN="$command_token" COMMAND_TARGET_HOST="$target_host" COMMAND_TARGET_PORT="$target_port" \
  node telemetry-bridge/server.js >"$state/bridge.log" 2>&1 &
pids+=("$!")

env -i PATH="$PATH" node tools/link-tools/site_dev_server.mjs --bridge "$bridge_url" --port 8090 \
  >"$state/site.log" 2>&1 &
pids+=("$!")

ready=0
for attempt in {1..50}; do
  if ! kill -0 "${pids[@]}" 2>/dev/null; then
    break
  fi
  if grep -Fqx '[UDP] listening on 127.0.0.1:3333' "$state/bridge.log" &&
    grep -Fqx "[HTTP] listening on $bridge_url" "$state/bridge.log" &&
    grep -Fqx "site on $site_url/" "$state/site.log"; then
    ready=1
    break
  fi
  sleep 0.1
done
if [[ $ready != 1 ]]; then
  printf 'The demo could not start. Check that TCP 8080/8090 and UDP 3333 are free.\n' >&2
  cat "$state/bridge.log" "$state/site.log" >&2
  exit 1
fi

env -i PATH="$PATH" node tools/link-tools/synth_sender.mjs --target 127.0.0.1:3333 \
  --bind 127.0.0.1 --source-port "${target_port:-0}" --count 0 --period 1000 --wiggle --v6 \
  >"$state/simulator.log" 2>&1 &
pids+=("$!")

if [[ $role == operator ]]; then
  if ! printf '%s\n' "$demo_password" |
    env -i PATH="$PATH" node tools/seed-operator-demo.mjs "$username" "$target_port"; then
    printf 'The operator demo could not initialize. Check that UDP port %s is free.\n' "$target_port" >&2
    tail -n 15 "$state/simulator.log" >&2
    exit 1
  fi
fi

printf '\nOpen %s and select Dashboard.\nUsername: %s\nPassword: %s\n' "$site_url" "$username" "$demo_password"
if [[ $role == operator ]]; then
  printf 'Command token: %s\n' "$command_token"
  printf 'Start in Programming or load the INA226 bench check in Branch Definition.\n'
fi
printf 'Telemetry and device responses are simulated. Press Ctrl+C to stop.\n\n'
while kill -0 "${pids[@]}" 2>/dev/null; do
  sleep 1
done
printf 'A demo process exited. Recent service output follows.\n' >&2
tail -n 15 "$state/bridge.log" "$state/site.log" "$state/simulator.log" >&2
exit 1
