#!/usr/bin/env bash
# Benchmark R HTTP frameworks on the same /ping and /ping-text routes.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SERVERS="$ROOT/servers"
RESULTS="$ROOT/results"
mkdir -p "$RESULTS"

WRK_THREADS=${WRK_THREADS:-4}
WRK_CONNECTIONS=${WRK_CONNECTIONS:-50}
WRK_DURATION=${WRK_DURATION:-30s}
WRK_ARGS=(-t"$WRK_THREADS" -c"$WRK_CONNECTIONS" -d"$WRK_DURATION")

DROGONR_THREADS=${DROGONR_THREADS:-4}
DROGONR_WORKERS=${DROGONR_WORKERS:-1}
PLUMBER2_MIRAI_DAEMONS=${PLUMBER2_MIRAI_DAEMONS:-5}
RESTRSERVE_JIT_LEVEL=${RESTRSERVE_JIT_LEVEL:-0}
RESTRSERVE_PRECOMPILE=${RESTRSERVE_PRECOMPILE:-false}
RESTRSERVE_RSERVE_PORT=${RESTRSERVE_RSERVE_PORT:-}

STAMP="$(date +%Y%m%d-%H%M%S)"
declare -A PIDS=()
declare -A PORTS=(
  [drogonR-native]=8080
  [drogonR-plumber-shim]=8083
  [plumber]=8081
  [plumber2]=8084
  [plumber2-mirai]=8086
  [RestRserve]=8085
)
declare -A SCRIPTS=(
  [drogonR-native]=drogonR-native.R
  [drogonR-plumber-shim]=drogonR-plumber-shim.R
  [plumber]=plumber.R
  [plumber2]=plumber2.R
  [plumber2-mirai]=plumber2-mirai.R
  [RestRserve]=restrserve.R
)
declare -A LABELS=(
  [drogonR-native]="drogonR native"
  [drogonR-plumber-shim]="drogonR plumber-shim"
  [plumber]="plumber"
  [plumber2]="plumber2"
  [plumber2-mirai]="plumber2 mirai async"
  [RestRserve]="RestRserve"
)
declare -A OPTIONS=(
  [drogonR-native]="DROGONR_THREADS=${DROGONR_THREADS}; DROGONR_WORKERS=${DROGONR_WORKERS}"
  [drogonR-plumber-shim]="DROGONR_THREADS=${DROGONR_THREADS}; DROGONR_WORKERS=${DROGONR_WORKERS}"
  [plumber]="single R process; no harness threading option"
  [plumber2]="sync handlers; no mirai daemons"
  [plumber2-mirai]="async=TRUE; PLUMBER2_MIRAI_DAEMONS=${PLUMBER2_MIRAI_DAEMONS}"
  [RestRserve]="Rserve HTTP backend; forked request processing; RESTRSERVE_JIT_LEVEL=${RESTRSERVE_JIT_LEVEL}; RESTRSERVE_PRECOMPILE=${RESTRSERVE_PRECOMPILE}; RESTRSERVE_RSERVE_PORT=${RESTRSERVE_RSERVE_PORT:-auto}"
)
VARIANTS=(drogonR-native drogonR-plumber-shim plumber plumber2 plumber2-mirai RestRserve)

require_commands() {
  local missing=()
  local cmd
  for cmd in Rscript curl wrk awk; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: missing required command(s): ${missing[*]}" >&2
    echo "Debian/Ubuntu: sudo apt-get install curl wrk" >&2
    echo "macOS:         brew install curl wrk" >&2
    exit 127
  fi
}

cleanup() {
  for name in "${!PIDS[@]}"; do
    local pid="${PIDS[$name]}"
    [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
  done
  sleep 0.5
  for name in "${!PIDS[@]}"; do
    local pid="${PIDS[$name]}"
    [[ -n "$pid" ]] && kill -9 "$pid" 2>/dev/null || true
  done
  if command -v fuser >/dev/null 2>&1; then
    for port in "${PORTS[@]}"; do
      fuser -k "${port}/tcp" >/dev/null 2>&1 || true
    done
  fi
}
trap cleanup EXIT

wait_ready() {
  local url=$1 name=$2 log=$3
  for _ in $(seq 1 60); do
    curl -fs "$url" >/dev/null 2>&1 && return 0
    sleep 0.5
  done
  echo "TIMEOUT: $name did not respond at $url within 30s" >&2
  echo "--- $log ---" >&2
  tail -200 "$log" >&2 || true
  exit 1
}

start_server() {
  local name=$1 script=${SCRIPTS[$name]} port=${PORTS[$name]}
  local log="$RESULTS/${name}-server-${STAMP}.log"
  echo "==> starting $name on :$port"
  DROGONR_THREADS="$DROGONR_THREADS" \
  DROGONR_WORKERS="$DROGONR_WORKERS" \
  PLUMBER2_MIRAI_DAEMONS="$PLUMBER2_MIRAI_DAEMONS" \
  RESTRSERVE_JIT_LEVEL="$RESTRSERVE_JIT_LEVEL" \
  RESTRSERVE_PRECOMPILE="$RESTRSERVE_PRECOMPILE" \
  RESTRSERVE_RSERVE_PORT="$RESTRSERVE_RSERVE_PORT" \
    Rscript "$SERVERS/$script" "$port" > "$log" 2>&1 &
  PIDS["$name"]=$!
  wait_ready "http://127.0.0.1:${port}/ping" "$name" "$log"
}

run_one() {
  local name=$1 route=$2 kind=$3 port=${PORTS[$name]}
  local out="$RESULTS/${name}-${kind}-${STAMP}.txt"
  echo "==> wrk ${WRK_ARGS[*]} http://127.0.0.1:${port}${route}  ($name $kind)"
  {
    echo "# $name $kind  $(date -Iseconds)"
    echo "# wrk ${WRK_ARGS[*]} http://127.0.0.1:${port}${route}"
    wrk "${WRK_ARGS[@]}" "http://127.0.0.1:${port}${route}"
  } | tee "$out"
  echo
}

wrk_rps() {
  awk '/Requests\/sec:/ { print $2; exit }' "$1"
}

wrk_latency() {
  awk '/Latency/ { print $2; exit }' "$1"
}

csv_quote() {
  local s=${1//\"/\"\"}
  printf '"%s"' "$s"
}

csv_row() {
  local first=1
  for field in "$@"; do
    if [[ $first -eq 0 ]]; then printf ','; fi
    csv_quote "$field"
    first=0
  done
  printf '\n'
}

pkg_version() {
  local pkg=$1
  Rscript -e "if (requireNamespace('$pkg', quietly=TRUE)) cat(as.character(packageVersion('$pkg'))) else cat(NA_character_)" 2>/dev/null || true
}

machine_value() {
  local key=$1
  case "$key" in
    host) uname -srmo 2>/dev/null || uname -a ;;
    cpu) lscpu 2>/dev/null | awk -F: '/Model name/ { sub(/^[[:space:]]+/, "", $2); print $2; exit }' ;;
    logical_cpus) nproc 2>/dev/null || printf 'unknown' ;;
    memory) awk '/MemTotal/ { printf "%.1f GiB", $2/1024/1024 }' /proc/meminfo 2>/dev/null || printf 'unknown' ;;
    os) . /etc/os-release 2>/dev/null && printf '%s' "${PRETTY_NAME:-unknown}" || printf 'unknown' ;;
    r_version) Rscript -e 'cat(R.version.string)' ;;
  esac
}

write_csv_results() {
  local out="$RESULTS/comparison-${STAMP}.csv"
  local latest="$RESULTS/latest.csv"
  local generated_at host cpu logical_cpus memory os r_version packages wrk_args
  generated_at="$(date -Iseconds)"
  host="$(machine_value host)"
  cpu="$(machine_value cpu)"
  logical_cpus="$(machine_value logical_cpus)"
  memory="$(machine_value memory)"
  os="$(machine_value os)"
  r_version="$(machine_value r_version)"
  packages="drogonR=$(pkg_version drogonR); plumber=$(pkg_version plumber); plumber2=$(pkg_version plumber2); mirai=$(pkg_version mirai); RestRserve=$(pkg_version RestRserve); Rserve=$(pkg_version Rserve)"
  wrk_args="${WRK_ARGS[*]}"

  {
    csv_row run_id generated_at variant label route kind port requests_per_sec latency_avg \
      wrk_args server_options host cpu logical_cpus memory os r_version package_versions raw_file
    for name in "${VARIANTS[@]}"; do
      for spec in "/ping json" "/ping-text text"; do
        # shellcheck disable=SC2086
        set -- $spec
        local route="$1"
        local kind="$2"
        local raw="$RESULTS/${name}-${kind}-${STAMP}.txt"
        csv_row "$STAMP" "$generated_at" "$name" "${LABELS[$name]}" "$route" "$kind" "${PORTS[$name]}" \
          "$(wrk_rps "$raw")" "$(wrk_latency "$raw")" "$wrk_args" "${OPTIONS[$name]}" "$host" "$cpu" "$logical_cpus" \
          "$memory" "$os" "$r_version" "$packages" "$raw"
      done
    done
  } > "$out"

  cp "$out" "$latest"
  echo "==> csv comparison: $out"
  echo "==> latest csv: $latest"
}

require_commands

for name in "${VARIANTS[@]}"; do
  start_server "$name"
done

for name in "${VARIANTS[@]}"; do
  run_one "$name" /ping json
  run_one "$name" /ping-text text
done

write_csv_results

echo "==> results in $RESULTS"
