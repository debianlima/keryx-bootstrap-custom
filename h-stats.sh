#!/usr/bin/env bash
set +e

MANIFEST="/hive/miners/custom/keryx-miner/h-manifest.conf"
[ -f "$MANIFEST" ] || MANIFEST="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/h-manifest.conf"
. "$MANIFEST" 2>/dev/null || true

LOG="${CUSTOM_LOG_BASENAME:-/var/log/miner/keryx-miner}.log"
VERSION="${CUSTOM_VERSION:-0.3.2-OPoI-bootstrap-v7}"
ALGO="blake3-alph"
now="$(date +%s)"
khs=0
stats="null"
diffTime=999999
stats_raw=""

num_to_khs() {
  awk -v v="$1" -v u="$2" 'BEGIN { gsub(/,/, ".", v); mult=1; if (u ~ /[Tt][Hh]ash|[Tt][Hh]\/s/) mult=1000000000; else if (u ~ /[Gg][Hh]ash|[Gg][Hh]\/s/) mult=1000000; else if (u ~ /[Mm][Hh]ash|[Mm][Hh]\/s/) mult=1000; else if (u ~ /[Kk][Hh]ash|[Kk][Hh]\/s/) mult=1; else if (u ~ /^[Hh]ash|^[Hh]\/s/) mult=0.001; printf "%d", v * mult; }'
}

line_diff() {
  line="$1"
  dt="$(echo "$line" | awk '{print $1, $2}' | sed -E 's/([0-9]{2}:[0-9]{2}:[0-9]{2})(\.[0-9]+)?([+-][0-9]{2}:?[0-9]{2}|Z)?/\1/')"
  ts="$(date -d "$dt" +%s 2>/dev/null || echo 0)"
  [ "$ts" -gt 0 ] && echo $(( now - ts < 0 ? ts - now : now - ts )) || echo 999999
}

if [ -f "$LOG" ]; then
  stats_raw="$(grep -Ei 'Current hashrate is|Current hashrate:|Total hashrate|hashrate' "$LOG" | tail -n 1)"
fi

if [ -n "$stats_raw" ]; then
  diffTime="$(line_diff "$stats_raw")"
  val="$(echo "$stats_raw" | grep -Eoi '[0-9]+([\.,][0-9]+)?[[:space:]]*([KMGT]?hash/s|[KMGT]?hash|[KMGT]?H/s)' | tail -n 1 | awk '{print $1}')"
  unit="$(echo "$stats_raw" | grep -Eoi '[0-9]+([\.,][0-9]+)?[[:space:]]*([KMGT]?hash/s|[KMGT]?hash|[KMGT]?H/s)' | tail -n 1 | awk '{print $2}')"
  if [ -n "$val" ] && [ "$diffTime" -lt 240 ]; then khs="$(num_to_khs "$val" "$unit")"; fi
fi

if [ "$khs" = "0" ] && [ -f "$LOG" ]; then
  alive_raw="$(grep -Ei 'KERYX-BOOTSTRAP|KERYX-HIVEOS|download|downloading|prefetch|model|loading|inference|starting|iniciando|baixando|bootstrap|fast-models|huggingface' "$LOG" | tail -n 1)"
  if [ -n "$alive_raw" ]; then
    alive_diff="$(line_diff "$alive_raw")"
    if [ "$alive_diff" -lt 900 ]; then khs=1; diffTime="$alive_diff"; stats_raw="$alive_raw"; fi
  fi
fi

hs_array="[$khs]"
temp_json="[]"; fan_json="[]"; bus_json="[]"

if command -v jq >/dev/null 2>&1 && [ -n "${GPU_STATS_JSON:-}" ] && [ -f "$GPU_STATS_JSON" ]; then
  temp_json="$(jq -c '[.[]?.temp // 0]' "$GPU_STATS_JSON" 2>/dev/null || echo '[]')"
  fan_json="$(jq -c '[.[]?.fan // 0]' "$GPU_STATS_JSON" 2>/dev/null || echo '[]')"
  bus_json="$(jq -c '[.[]?.busids // empty | split(":")[0] | tonumber? // 0]' "$GPU_STATS_JSON" 2>/dev/null || echo '[]')"
fi

if command -v jq >/dev/null 2>&1; then
  stats="$(jq -nc --argjson hs "$hs_array" --arg hs_units "khs" --arg algo "$ALGO" --arg ver "$VERSION" --argjson bus_numbers "$bus_json" --argjson temp "$temp_json" --argjson fan "$fan_json" '{hs:$hs, hs_units:$hs_units, algo:$algo, ver:$ver, bus_numbers:$bus_numbers, temp:$temp, fan:$fan}')"
else
  stats="{\"hs\":$hs_array,\"hs_units\":\"khs\",\"algo\":\"$ALGO\",\"ver\":\"$VERSION\"}"
fi

echo "Log file : $LOG"
echo "Time since last relevant log entry : $diffTime"
echo "Raw stats : $stats_raw"
echo "KHS : $khs"
echo "Output : $stats"
