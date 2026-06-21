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
VERSION="${CUSTOM_VERSION:-0.3.2-OPoI-bootstrap-v21}"
ALGO="${CUSTOM_ALGO:-blake3-alph}"
now="$(date +%s)"

gpu_count=0
if [ -f "$LOG" ]; then
  gpu_count="$(grep -Eo 'Device #[0-9]+' "$LOG" | tail -n 80 | sed 's/[^0-9]//g' | sort -n | uniq | wc -l | tr -d ' ')"
fi
case "$gpu_count" in ''|*[!0-9]*) gpu_count=0 ;; esac

if [ "$gpu_count" -lt 1 ] && command -v jq >/dev/null 2>&1 && [ -n "${GPU_STATS_JSON:-}" ] && [ -f "$GPU_STATS_JSON" ]; then
  gpu_count="$(jq 'length' "$GPU_STATS_JSON" 2>/dev/null || echo 0)"
fi
case "$gpu_count" in ''|*[!0-9]*) gpu_count=0 ;; esac

if [ "$gpu_count" -lt 1 ] && command -v nvidia-smi >/dev/null 2>&1; then
  gpu_count="$(nvidia-smi -L 2>/dev/null | grep -c '^GPU ' || echo 0)"
fi
case "$gpu_count" in ''|*[!0-9]*) gpu_count=0 ;; esac
[ "$gpu_count" -gt 0 ] || gpu_count=1

total_value=0
hs_units="mhs"
stats_raw=""
diffTime=999999

line_diff() {
  line="$1"
  dt="$(printf '%s\n' "$line" | grep -Eo '[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?(Z|[+-][0-9]{2}:?[0-9]{2})?' | head -n 1)"
  ts="$(date -d "$dt" +%s 2>/dev/null || echo 0)"
  [ "$ts" -gt 0 ] && echo $(( now - ts < 0 ? ts - now : now - ts )) || echo 999999
}

hash_to_mhs() {
  awk -v v="$1" -v u="$2" 'BEGIN{gsub(/,/,".",v); gsub(/[[:space:]]/,"",u); u=toupper(u); m=1; if(u~/^P/)m=1000000000; else if(u~/^T/)m=1000000; else if(u~/^G/)m=1000; else if(u~/^M/)m=1; else if(u~/^K/)m=0.001; else m=0.000001; printf "%.6f", v*m}'
}

parse_hash_line() {
  line="$1"
  m="$(printf '%s\n' "$line" | grep -Eio '[0-9]+([\.,][0-9]+)?[[:space:]]*[KMGTPE]?[[:space:]]*(H/s|Hash/s|Hashes/s|hash/s|hashes/s)' | tail -n 1)"
  [ -n "$m" ] || return 1
  val="$(printf '%s\n' "$m" | grep -Eo '[0-9]+([\.,][0-9]+)?' | head -n 1)"
  unit="$(printf '%s\n' "$m" | sed -E 's/^[0-9]+([\.,][0-9]+)?[[:space:]]*//; s/[[:space:]]//g')"
  [ -n "$val" ] || return 1
  total_value="$(hash_to_mhs "$val" "$unit")"
  hs_units="mhs"
  stats_raw="$line"
  diffTime="$(line_diff "$line")"
  return 0
}

if [ -f "$LOG" ]; then
  current_line="$(grep -Ei 'Current hashrate is|Current hashrate:' "$LOG" | tail -n 1)"
  if [ -n "$current_line" ]; then
    parse_hash_line "$current_line"
  fi
fi

if [ "$total_value" = "0" ] && [ -f "$LOG" ]; then
  last_device_line="$(grep -Ei 'Device #[0-9]+.*(H/s|Hash/s|hash/s|Mhash/s|Ghash/s|T/hash)' "$LOG" | tail -n 1)"
  if [ -n "$last_device_line" ]; then
    parse_hash_line "$last_device_line"
    total_value="$(awk -v per="$total_value" -v n="$gpu_count" 'BEGIN{printf "%.6f", per*n}')"
    stats_raw="SOMADO por GPU: $last_device_line"
  fi
fi

if [ "$total_value" = "0" ] && [ -f "$LOG" ]; then
  alive_raw="$(grep -Ei 'KERYX-BOOTSTRAP|KERYX-HIVEOS|download|downloading|prefetch|model|loading|iniciando|baixando|bootstrap|retry' "$LOG" | tail -n 1)"
  if [ -n "$alive_raw" ]; then
    alive_diff="$(line_diff "$alive_raw")"
    if [ "$alive_diff" -lt 900 ]; then
      total_value=1
      hs_units="khs"
      diffTime="$alive_diff"
      stats_raw="$alive_raw"
    fi
  fi
fi

hs_json="$(awk -v total="$total_value" -v n="$gpu_count" 'BEGIN{if(n<1)n=1; per=total/n; printf "["; for(i=1;i<=n;i++){if(i>1)printf ","; printf "%.6f", per} printf "]"}')"
bus_json="$(awk -v n="$gpu_count" 'BEGIN{if(n<1)n=1; printf "["; for(i=0;i<n;i++){if(i>0)printf ","; printf "%d", i} printf "]"}')"

temp_json="[]"; fan_json="[]"
if command -v jq >/dev/null 2>&1 && [ -n "${GPU_STATS_JSON:-}" ] && [ -f "$GPU_STATS_JSON" ]; then
  temp_json="$(jq -c '[.[]?.temp // 0]' "$GPU_STATS_JSON" 2>/dev/null || echo '[]')"
  fan_json="$(jq -c '[.[]?.fan // 0]' "$GPU_STATS_JSON" 2>/dev/null || echo '[]')"
elif command -v nvidia-smi >/dev/null 2>&1; then
  temp_json="$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | awk 'BEGIN{printf "["}{if(NR>1)printf ","; printf "%d",$1}END{printf "]"}')"
  fan_json="$(nvidia-smi --query-gpu=fan.speed --format=csv,noheader,nounits 2>/dev/null | awk 'BEGIN{printf "["}{gsub(/[^0-9]/,"",$1); if(NR>1)printf ","; printf "%d",$1}END{printf "]"}')"
fi

if command -v jq >/dev/null 2>&1; then
  stats="$(jq -nc --argjson hs "$hs_json" --arg hs_units "$hs_units" --arg algo "$ALGO" --arg ver "$VERSION" --argjson bus_numbers "$bus_json" --argjson temp "$temp_json" --argjson fan "$fan_json" --arg total "$total_value" --arg gpu_count "$gpu_count" '{hs:$hs,hs_units:$hs_units,algo:$algo,ver:$ver,bus_numbers:$bus_numbers,temp:$temp,fan:$fan,keryx_total:$total,keryx_gpu_count:$gpu_count}')"
else
  stats="{\"hs\":$hs_json,\"hs_units\":\"$hs_units\",\"algo\":\"$ALGO\",\"ver\":\"$VERSION\"}"
fi

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  echo "Log file : $LOG"
  echo "GPU count : $gpu_count"
  echo "Raw stats : $stats_raw"
  echo "Total hashrate value : $total_value"
  echo "Hashrate units : $hs_units"
  echo "HS array : $hs_json"
  echo "Output : $stats"
else
  echo "$stats"
fi
