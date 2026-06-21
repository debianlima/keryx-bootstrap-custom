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
VERSION="${CUSTOM_VERSION:-0.3.2-OPoI-bootstrap-v22}"
ALGO="${CUSTOM_ALGO:-blake3-alph}"
maxDelay=180
time_now="$(date +%s)"

stats_raw=""
diffTime=999999
khs=0
stats="null"

hash_to_khs() {
  awk -v v="$1" -v u="$2" 'BEGIN{
    gsub(/,/,".",v)
    gsub(/[[:space:]]/,"",u)
    u=toupper(u)
    m=1
    if(u~/^P/)m=1000000000000
    else if(u~/^T/)m=1000000000
    else if(u~/^G/)m=1000000
    else if(u~/^M/)m=1000
    else if(u~/^K/)m=1
    else m=0.001
    printf "%.0f", v*m
  }'
}

parse_hash_line_to_khs() {
  line="$1"
  m="$(printf '%s\n' "$line" | grep -Eio '[0-9]+([\.,][0-9]+)?[[:space:]]*[KMGTPE]?[[:space:]]*(H/s|Hash/s|Hashes/s|hash/s|hashes/s)' | tail -n 1)"
  [ -n "$m" ] || return 1
  val="$(printf '%s\n' "$m" | grep -Eo '[0-9]+([\.,][0-9]+)?' | head -n 1)"
  unit="$(printf '%s\n' "$m" | sed -E 's/^[0-9]+([\.,][0-9]+)?[[:space:]]*//; s/[[:space:]]//g')"
  [ -n "$val" ] || return 1
  hash_to_khs "$val" "$unit"
}

line_timestamp() {
  line="$1"
  dt="$(printf '%s\n' "$line" | grep -Eo '[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?(Z|[+-][0-9]{2}:?[0-9]{2})?' | head -n 1)"
  date -d "$dt" +%s 2>/dev/null || echo 0
}

read_gpu_arrays() {
  busids=(); brands=(); temps=(); fans=()
  if command -v jq >/dev/null 2>&1 && [ -n "${GPU_STATS_JSON:-}" ] && [ -f "$GPU_STATS_JSON" ]; then
    mapfile -t busids < <(jq -r 'if type=="object" and (.busids|type=="array") then .busids[] elif type=="array" then .[]?.busids // empty else empty end' "$GPU_STATS_JSON" 2>/dev/null)
    mapfile -t brands < <(jq -r 'if type=="object" and (.brand|type=="array") then .brand[] elif type=="array" then .[]?.brand // empty else empty end' "$GPU_STATS_JSON" 2>/dev/null)
    mapfile -t temps  < <(jq -r 'if type=="object" and (.temp|type=="array") then .temp[] elif type=="array" then .[]?.temp // 0 else empty end' "$GPU_STATS_JSON" 2>/dev/null)
    mapfile -t fans   < <(jq -r 'if type=="object" and (.fan|type=="array") then .fan[] elif type=="array" then .[]?.fan // 0 else empty end' "$GPU_STATS_JSON" 2>/dev/null)
  fi
}

bus_to_num() {
  b="$1"
  hex="$(printf '%s\n' "$b" | sed -E 's/^([A-Fa-f0-9]+):.*$/\1/')"
  case "$hex" in ''|*[!0-9A-Fa-f]*) echo 0 ;; *) echo $((16#$hex)) ;; esac
}

stats_raw="$(grep -Ei 'Current hashrate is|Current hashrate:' "$LOG" 2>/dev/null | tail -n 1)"
time_rep="$(line_timestamp "$stats_raw")"
[ "$time_rep" -gt 0 ] && diffTime="$(( time_now > time_rep ? time_now - time_rep : time_rep - time_now ))"

if [ -n "$stats_raw" ] && [ "$diffTime" -lt "$maxDelay" ]; then
  total_hashrate="$(parse_hash_line_to_khs "$stats_raw" || echo 0)"
  khs="$total_hashrate"

  read_gpu_arrays

  active_ids="$(grep -Eo 'Device #[0-9]+' "$LOG" 2>/dev/null | tail -n 120 | sed 's/[^0-9]//g' | sort -n | uniq)"
  [ -n "$active_ids" ] || active_ids="$(seq 0 $((${#busids[@]} > 0 ? ${#busids[@]} - 1 : 0)) 2>/dev/null)"

  hash_arr=(); busid_arr=(); fan_arr=(); temp_arr=()

  for i in $active_ids; do
    gpu_raw="$(grep -Ei "Device #$i .*: .*([KMGTPE]?hash/s|[KMGTPE]?H/s)" "$LOG" 2>/dev/null | tail -n 1)"
    hashrate="$(parse_hash_line_to_khs "$gpu_raw" || echo 0)"
    [ "$hashrate" = "0" ] && hashrate="$(awk -v t="$total_hashrate" -v n="$(printf '%s\n' "$active_ids" | wc -w)" 'BEGIN{if(n<1)n=1; printf "%.0f", t/n}')"

    hash_arr+=("$hashrate")
    if [ ${#busids[@]} -gt "$i" ]; then busid_arr+=("$(bus_to_num "${busids[$i]}")"); else busid_arr+=("$i"); fi
    if [ ${#temps[@]} -gt "$i" ]; then temp_arr+=("${temps[$i]}"); else temp_arr+=(0); fi
    if [ ${#fans[@]} -gt "$i" ]; then fan_arr+=("${fans[$i]}"); else fan_arr+=(0); fi
  done

  if command -v jq >/dev/null 2>&1; then
    hash_json="$(printf '%s\n' "${hash_arr[@]}" | jq -cs '.')"
    bus_numbers="$(printf '%s\n' "${busid_arr[@]}" | jq -cs '.')"
    fan_json="$(printf '%s\n' "${fan_arr[@]}" | jq -cs '.')"
    temp_json="$(printf '%s\n' "${temp_arr[@]}" | jq -cs '.')"
    uptime=$(( time_now - $(stat -c %Y "$CUSTOM_CONFIG_FILENAME" 2>/dev/null || echo "$time_now") ))
    stats="$(jq -nc --argjson hs "$hash_json" --arg ver "$VERSION" --argjson bus_numbers "$bus_numbers" --argjson fan "$fan_json" --argjson temp "$temp_json" --arg uptime "$uptime" --arg algo "$ALGO" '{hs:$hs,hs_units:"khs",algo:$algo,ver:$ver,uptime:$uptime,bus_numbers:$bus_numbers,temp:$temp,fan:$fan}')"
  else
    stats="{\"hs\":[${hash_arr[*]}],\"hs_units\":\"khs\",\"algo\":\"$ALGO\",\"ver\":\"$VERSION\"}"
  fi
else
  khs=0
  stats="null"
fi

echo "Log file : $LOG"
echo "Time since last log entry : $diffTime"
echo "Raw stats : $stats_raw"
echo "KHS : $khs"
echo "Output : $stats"

[[ -z "$khs" ]] && khs=0
[[ -z "$stats" ]] && stats="null"
