#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ! -d telemetry-bridge/node_modules/jose ]]; then
  printf 'Install the bridge dependencies with npm ci --prefix telemetry-bridge.\n' >&2
  exit 1
fi

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
  node telemetry-bridge/tools/auth-user.mjs "$state/auth.json" reviewer viewer >/dev/null

# Start from a clean environment so local or production settings cannot enter the demo.
env -i PATH="$PATH" AUTH_ENABLED=true AUTH_ALLOW_LOCAL_HTTP=true AUTH_ORIGIN="$site_url" \
  AUTH_CONFIG_PATH="$state/auth.json" HTTP_BIND_ADDRESS=127.0.0.1 UDP_BIND_ADDRESS=127.0.0.1 \
  HEX_DEVICE_ID=portfolio-simulator RECORDING_DB_PATH="$state/demo.sqlite" \
  node telemetry-bridge/server.js &
pids+=("$!")

env -i PATH="$PATH" node tools/link-tools/site_dev_server.mjs --bridge "$bridge_url" --port 8090 &
pids+=("$!")

ready=0
for attempt in {1..50}; do
  if ! kill -0 "${pids[@]}" 2>/dev/null; then
    break
  fi
  if curl --fail --silent --noproxy '*' --max-time 1 "$site_url/telemetry/auth/status" |
    grep -Eq '"enabled":[[:space:]]*true'; then
    ready=1
    break
  fi
  sleep 0.1
done
if [[ $ready != 1 ]]; then
  printf 'The demo could not start. Check that TCP 8080/8090 and UDP 3333 are free.\n' >&2
  exit 1
fi

env -i PATH="$PATH" node tools/link-tools/synth_sender.mjs --target 127.0.0.1:3333 \
  --bind 127.0.0.1 --count 0 --period 1000 --wiggle --v6 &
pids+=("$!")

printf '\nOpen %s and select Dashboard.\nUsername: reviewer\nPassword: %s\n' "$site_url" "$demo_password"
printf 'Telemetry is simulated. Press Ctrl+C to stop.\n\n'
while kill -0 "${pids[@]}" 2>/dev/null; do
  sleep 1
done
printf 'A demo process exited. See the output above.\n' >&2
exit 1
