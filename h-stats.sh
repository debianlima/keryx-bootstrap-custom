#!/usr/bin/env bash
set +e

load_hiveos_flight_sheet() {
  [ -f /hive-config/rig.conf ] && . /hive-config/rig.conf 2>/dev/null || true
  [ -f /hive-config/wallet.conf ] && . /hive-config/wallet.conf 2>/dev/null || true
}

load_hiveos_flight_sheet

MANIFEST="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/h-manifest.conf"
. "$MANIFEST" 2>/dev/null || true

LOG="${CUSTOM_LOG_BASENAME:-/var/log/miner/keryx-miner}.log"
VERSION="${CUSTOM_VERSION:-0.3.2-OPoI-bootstrap-v19}"
ALGO="${CUSTOM_ALGO:-blake3-alph}"
now="$(date +%s)"
hs_value=0
hs_units="ghs"
stats_raw=""
diffTime=999999

line_diff() {
  line="$1"
  dt="$(printf '%s\n' "$line" | grep -Eo '[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?(Z|[+-][0-9]{2}:?[0-9]{2})?' | head -n 1)"
  ts="$(date -d "$dt" +%s 2>/dev/null || echo 0)"
  [ "$ts" -gt 0 ] && echo $(( now - ts < 0 ? ts - now : now - ts )) || echo 999999
}

hash_to_ghs() {
  val="$1"
  unit="$2"
  awk -v v="$val" -v u="$unit" 'BEGIN {
    gsub(/,/, ".", v)
    gsub(/[[:space:]]/, "", u)
    u=toupper(u)
    mult=1
    if (u ~ /^P/) mult=1000000
    else if (u ~ /^T/) mult=1000
    else if (u ~ /^G/) mult=1
    else if (u ~ /^M/) mult=0.001
    else if (u ~ /^K/) mult=0.000001
    else mult=0.000000001
    printf "%.6f", v * mult
  }'
}

extract_hash_match() {
  line="$1"
  # Aceita formatos como: 1.23 GH/s, 1.23 GHash/s, 1.23 Ghash/s, 1234 MH/s.
  printf '%s\n' "$line" \
    | grep -Eio '[0-9]+([\.,][0-9]+)?[[:space:]]*[KMGTPE]?[[:space:]]*(H/s|Hash/s|Hashes/s|hash/s|hashes/s)' \
    | tail -n 1
}

parse_hashrate_from_log() {
  [ -f "$LOG" ] || return 1

  # Primeiro procura linhas explicitamente relacionadas a hashrate.
  while IFS= read -r line; do
    m="$(extract_hash_match "$line")"
    [ -n "$m" ] || continue

    val="$(printf '%s\n' "$m" | grep -Eo '[0-9]+([\.,][0-9]+)?' | head -n 1)"
    unit="$(printf '%s\n' "$m" | sed -E 's/^[0-9]+([\.,][0-9]+)?[[:space:]]*//; s/[[:space:]]//g')"
    [ -n "$val" ] || continue

    hs_value="$(hash_to_ghs "$val" "$unit")"
    hs_units="ghs"
    stats_raw="$line"
    diffTime="$(line_diff "$line")"
    return 0
  done <<EOF
$(grep -Ei 'hashrate|hash rate|GH/s|GHash/s|Ghash/s|MH/s|MHash/s|KH/s|KHash/s|TH/s|THash/s' "$LOG" | tail -n 80 | tac)
EOF

  return 1
}

if parse_hashrate_from_log; then
  :
else
  # Fallback apenas para manter o HiveOS vendo atividade durante bootstrap/download/prefetch.
  # Nao usamos isso como hashrate real. Quando o minerador imprimir GH/s, o parser acima assume.
  if [ -f "$LOG" ]; then
    alive_raw="$(grep -Ei 'KERYX-BOOTSTRAP|KERYX-HIVEOS|download|downloading|prefetch|model|loading|inference|starting|iniciando|baixando|bootstrap|fast-models|huggingface|retry|DIAGNOSTICO' "$LOG" | tail -n 1)"
    if [ -n "$alive_raw" ]; then
      alive_diff="$(line_diff "$alive_raw")"
      if [ "$alive_diff" -lt 900 ]; then
        hs_value=1
        hs_units="khs"
        diffTime="$alive_diff"
        stats_raw="$alive_raw"
      fi
    fi
  fi
fi

temp_json="[]"; fan_json="[]"; bus_json="[]"
if command -v jq >/dev/null 2>&1 && [ -n "${GPU_STATS_JSON:-}" ] && [ -f "$GPU_STATS_JSON" ]; then
  temp_json="$(jq -c '[.[]?.temp // 0]' "$GPU_STATS_JSON" 2>/dev/null || echo '[]')"
  fan_json="$(jq -c '[.[]?.fan // 0]' "$GPU_STATS_JSON" 2>/dev/null || echo '[]')"
  bus_json="$(jq -c '[.[]?.busids // empty | split(":")[0] | tonumber? // 0]' "$GPU_STATS_JSON" 2>/dev/null || echo '[]')"
fi

if command -v jq >/dev/null 2>&1; then
  stats="$(jq -nc --argjson hs "[$hs_value]" --arg hs_units "$hs_units" --arg algo "$ALGO" --arg ver "$VERSION" --argjson bus_numbers "$bus_json" --argjson temp "$temp_json" --argjson fan "$fan_json" '{hs:$hs, hs_units:$hs_units, algo:$algo, ver:$ver, bus_numbers:$bus_numbers, temp:$temp, fan:$fan}')"
else
  stats="{\"hs\":[$hs_value],\"hs_units\":\"$hs_units\",\"algo\":\"$ALGO\",\"ver\":\"$VERSION\"}"
fi

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  echo "Log file : $LOG"
  echo "Time since last relevant log entry : $diffTime"
  echo "Raw stats : $stats_raw"
  echo "Hashrate value : $hs_value"
  echo "Hashrate units : $hs_units"
  echo "Output : $stats"
else
  echo "$stats"
fi
