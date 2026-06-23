# shellcheck shell=bash
# detect.sh — probe the real hardware and emit *canonical keys* matching catalog.sh.
#
# Each detect_* function sets global variables (so the caller can read both the
# canonical key used for matching AND a human "raw" string + any caveats):
#   CPU:  CPU_KEY  CPU_RAW  CPU_NOTE
#   GPU:  GPU_KEY  GPU_RAW  GPU_NOTE
#   MEM:  MEM_KEY  MEM_RAW  MEM_DDR  MEM_NOTE
#   DISK: DISK_KEY DISK_RAW DISK_NOTE  + DISK_MEDIA[label]
#   NET:  NIC_KEY  NIC_RAW  NIC_NOTE   + ETH_GROUPS[spd] IB_GROUPS[spd] IB_GEN[spd]
#
# Comments explain what each command reads at the hardware level.

# Run a command with root privileges if we are not already root (non-interactive
# sudo only — on the physical host the operator runs `sudo ./catcher.bash`).
_priv() {
  if [ "$(id -u)" -eq 0 ]; then "$@"
  elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then sudo -n "$@"
  else return 127
  fi
}

# ===========================================================================
# CPU  — lscpu reads CPUID + /proc/cpuinfo: the silicon's self-reported model.
# ===========================================================================
detect_cpu() {
  CPU_KEY=""; CPU_RAW=""; CPU_NOTE=""
  if ! command -v lscpu >/dev/null 2>&1; then CPU_NOTE="lscpu not found"; return; fi
  local out vendor model sockets sku
  out="$(lscpu 2>/dev/null)"
  vendor="$(printf '%s\n' "$out" | awk -F: '/^Vendor ID/{gsub(/^[ \t]+/,"",$2);print $2}')"
  model="$(printf '%s\n'  "$out" | awk -F: '/^Model name/{gsub(/^[ \t]+/,"",$2);print $2; exit}')"
  sockets="$(printf '%s\n' "$out" | awk -F: '/^Socket\(s\)/{gsub(/[ \t]/,"",$2);print $2}')"
  [ -z "$sockets" ] && sockets=1
  CPU_RAW="$model (${sockets} socket)"

  case "$vendor" in
    *Intel*|*GenuineIntel*)
      # Strip marketing noise, then grab the SKU: 4 digits + optional letters + optional '+'
      #   "INTEL(R) XEON(R) GOLD 6530"      -> 6530
      #   "INTEL(R) XEON(R) PLATINUM 8480+" -> 8480+      "...6548Y+" -> 6548Y+
      local clean
      clean="$(printf '%s' "$model" | sed -E 's/\(R\)|\(TM\)//g; s/@.*//')"
      sku="$(printf '%s' "$clean" | grep -oE '[0-9]{4}[A-Z]*\+?' | head -n1)"
      [ -n "$sku" ] && CPU_KEY="Intel ${sku}|${sockets}"
      ;;
    *AMD*|*AuthenticAMD*)
      # AMD EPYC SKU is the token right after "EPYC": 7713 / 74F3 / 9575F ...
      sku="$(printf '%s' "$model" | awk '{for(i=1;i<=NF;i++) if($i=="EPYC"){print $(i+1); exit}}')"
      [ -z "$sku" ] && sku="$(printf '%s' "$model" | grep -oE '[0-9]{2}[0-9A-Z]{2}[A-Z]?' | head -n1)"
      [ -n "$sku" ] && CPU_KEY="AMD ${sku}|${sockets}"
      ;;
    *) CPU_NOTE="unknown CPU vendor: $vendor" ;;
  esac
  [ -z "$CPU_KEY" ] && [ -z "$CPU_NOTE" ] && CPU_NOTE="could not parse SKU from: $model"
}

# ===========================================================================
# GPU  — nvidia-smi queries the NVIDIA driver (NVML); no CUDA toolkit needed.
# We read the product name + VRAM to disambiguate variants (PCIe vs SXM, 40/80G).
# ===========================================================================
_gpu_token() {            # _gpu_token "<name>" "<mem_MiB>" -> token on stdout
  local n; n="$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')"
  local mem="${2:-0}"
  local bus="SXM"; case "$n" in *PCIE*|*PCIE*) bus="PCIE";; esac
  local g80=0; [ "$mem" -ge 70000 ] 2>/dev/null && g80=1   # >=~80G
  case "$n" in
    *RTX*5090*)             echo "RTX5090" ;;
    *B200*)                 echo "B200" ;;
    *B300*)                 echo "B300" ;;
    *H200*)                 echo "H200-141G" ;;
    *H100*)                 echo "H100-SXM-80G" ;;          # only SXM-80G in catalog
    *H20*)  if [ "$mem" -ge 130000 ] 2>/dev/null; then echo "H20-141G"; else echo "H20-96G"; fi ;;
    *L40S*)                 echo "L40S" ;;
    *L40*)                  echo "L40" ;;
    *L20*)                  echo "L20" ;;
    *A800*)                 echo "A800-SXM-80G" ;;
    *A100*) if [ "$g80" -eq 1 ]; then echo "A100-${bus}-80G"; else echo "A100-${bus}-40G"; fi ;;
    *V100S*)                echo "V100S-PCIE-32G" ;;
    *V100*) if [ "$bus" = "PCIE" ]; then echo "V100-PCIE-16G"; else echo "V100-SXM2"; fi ;;
    *2080*TI*|*2080TI*)     echo "2080Ti" ;;
    *A10\ *|*\ A10|*"A10"*)  case "$n" in *A100*|*A10G*) echo "RAW:$1";; *) echo "A10";; esac ;;
    *)                      echo "RAW:$1" ;;
  esac
}

detect_gpu() {
  GPU_KEY=""; GPU_RAW=""; GPU_NOTE=""
  if ! command -v nvidia-smi >/dev/null 2>&1; then
    # No NVIDIA driver -> maybe a CPU-only or non-NVIDIA box.
    if lspci 2>/dev/null | grep -qi nvidia; then GPU_NOTE="NVIDIA PCI device present but nvidia-smi missing"; fi
    return
  fi
  local q; q="$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits 2>/dev/null)"
  [ -z "$q" ] && { GPU_NOTE="nvidia-smi returned no GPUs"; return; }
  local count=0 token first_token="" mixed=0 name mem
  while IFS=, read -r name mem; do
    name="$(printf '%s' "$name" | sed -E 's/^[ \t]+|[ \t]+$//g')"
    mem="$(printf '%s' "$mem"  | tr -dc '0-9')"
    token="$(_gpu_token "$name" "${mem:-0}")"
    count=$((count+1))
    if [ -z "$first_token" ]; then first_token="$token"; GPU_RAW="$name"
    elif [ "$token" != "$first_token" ]; then mixed=1; fi
  done <<< "$q"
  GPU_RAW="${GPU_RAW} *${count}"
  [ "$mixed" -eq 1 ] && GPU_NOTE="mixed GPU models detected; using first"
  case "$first_token" in
    RAW:*) GPU_NOTE="GPU model not in catalog: ${first_token#RAW:} *${count}"; GPU_KEY="" ;;
    *)     GPU_KEY="${first_token}|${count}" ;;
  esac
}

# ===========================================================================
# MEM  — dmidecode reads the firmware SMBIOS/DMI tables (per-DIMM layout).
# /proc/meminfo only gives the total, which can't tell 16x64G from 32x32G.
# ===========================================================================
detect_mem() {
  MEM_KEY=""; MEM_RAW=""; MEM_DDR=""; MEM_NOTE=""
  if ! command -v dmidecode >/dev/null 2>&1; then MEM_NOTE="dmidecode not found (need root tool)"; return; fi
  local dmi
  dmi="$(_priv dmidecode -t memory 2>/dev/null)"
  if [ -z "$dmi" ]; then
    local tot; tot="$(awk '/MemTotal/{printf "%.0f", $2/1024/1024}' /proc/meminfo 2>/dev/null)"
    MEM_NOTE="dmidecode needs root (run: sudo ./catcher.bash). Total≈${tot}GB only."
    MEM_RAW="${tot}GB total"
    return
  fi
  MEM_DDR="$(printf '%s\n' "$dmi" | awk -F: '/^[ \t]*Type:/{gsub(/[ \t]/,"",$2); if($2 ~ /^DDR/){print $2; exit}}')"
  # Collect each populated module's size in GB (skip "No Module Installed").
  local sizes; sizes="$(printf '%s\n' "$dmi" | awk '
    /^[ \t]*Size:/ {
      if ($0 ~ /No Module|Not Installed|Unknown/) next
      v=$2; u=$3
      if (u ~ /GB/) printf "%d\n", v
      else if (u ~ /MB/) printf "%d\n", v/1024
    }')"
  [ -z "$sizes" ] && { MEM_NOTE="no populated DIMMs parsed"; return; }
  local count uniqsize nsizes
  count="$(printf '%s\n' "$sizes" | grep -c .)"
  # dominant size (mode); note if mixed
  uniqsize="$(printf '%s\n' "$sizes" | sort -n | uniq -c | sort -rn | awk 'NR==1{print $2}')"
  nsizes="$(printf '%s\n' "$sizes" | sort -u | grep -c .)"
  [ "$nsizes" -gt 1 ] && MEM_NOTE="mixed DIMM sizes detected; using dominant ${uniqsize}G"
  MEM_KEY="${uniqsize}|${count}"
  MEM_RAW="${MEM_DDR:+$MEM_DDR }${uniqsize}G *${count}"
}

# ===========================================================================
# DISK — lsblk reads /sys/block. ROTA: 0=SSD/NVMe, 1=spinning HDD.
# Sizes are raw BYTES (decimal) snapped to marketed buckets (960G, 3.84T ...).
# ===========================================================================
_snap_disk() {            # _snap_disk <bytes> -> "label|gb" or "" if no bucket within 8%
  local bytes="$1" gb best="" bestd="" b d
  gb=$(( bytes / 1000000000 ))     # decimal GB
  for b in "${DISK_BUCKETS[@]}"; do
    d=$(( gb>b ? gb-b : b-gb ))
    if [ -z "$bestd" ] || [ "$d" -lt "$bestd" ]; then bestd="$d"; best="$b"; fi
  done
  [ -z "$best" ] && { echo ""; return; }
  # tolerance: within 8% of the bucket
  if [ "$(( bestd * 100 ))" -le "$(( best * 8 ))" ]; then echo "${DISK_LABEL[$best]}|$best"; else echo ""; fi
}

detect_disk() {
  DISK_KEY=""; DISK_RAW=""; DISK_NOTE=""
  declare -gA DISK_MEDIA=()
  if ! command -v lsblk >/dev/null 2>&1; then DISK_NOTE="lsblk not found"; return; fi
  declare -A cnt=() gbof=()
  local raid=0 raw_parts=() name bytes type rota model line label gb
  while read -r name bytes type rota model; do
    case "$name" in loop*|zram*|sr*|fd*|dm-*|rbd*) continue;; esac
    [ "$type" = "disk" ] || continue
    case "$model" in *Logical*Volume*|*LOGICAL*VOLUME*|*Virtual*Disk*|*MR9*|*PERC*|*AVAGO*) raid=1;; esac
    local snap; snap="$(_snap_disk "$bytes")"
    if [ -z "$snap" ]; then
      raw_parts+=("$(( bytes/1000000000 ))G(unmatched)")
      DISK_NOTE="${DISK_NOTE}; size $(( bytes/1000000000 ))GB not in catalog buckets"
      continue
    fi
    label="${snap%|*}"; gb="${snap#*|}"
    cnt[$label]=$(( ${cnt[$label]:-0} + 1 ))
    gbof[$label]="$gb"
    if [ "$rota" = "1" ]; then
      [ "${DISK_MEDIA[$label]:-SSD}" = "SSD" ] && DISK_MEDIA[$label]="HDD"
    else
      DISK_MEDIA[$label]="${DISK_MEDIA[$label]:-SSD}"
    fi
  done < <(lsblk -dnb -o NAME,SIZE,TYPE,ROTA,MODEL 2>/dev/null)

  # Build canonical key: segments sorted ASCENDING by capacity, "label*count".
  local key="" k
  while read -r k; do
    [ -z "$k" ] && continue
    label="${k#*|}"
    key="${key:+$key+}${label}*${cnt[$label]}"
    raw_parts+=("${DISK_MEDIA[$label]} ${label}*${cnt[$label]}")
  done < <(for label in "${!cnt[@]}"; do echo "${gbof[$label]}|$label"; done | sort -n | awk -F'|' '{print $1"|"$2}')

  DISK_KEY="$key"
  DISK_RAW="$(IFS='; '; echo "${raw_parts[*]}")"
  [ "$raid" -eq 1 ] && DISK_NOTE="RAID/logical volume present — physical disk count may be masked (boot pair behind RAID1 shows as one volume).${DISK_NOTE}"
  DISK_NOTE="${DISK_NOTE#; }"
}

# ===========================================================================
# NET  — physical ports only (those with a /sys/class/net/<i>/device PCI link).
# Ethernet speed from /sys/class/net/<i>/speed (Mb/s). InfiniBand rate + gen
# (HDR/NDR) from /sys/class/infiniband/<dev>/ports/<n>/rate, e.g. "200 Gb/sec (4X HDR)".
# ===========================================================================
detect_net() {
  NIC_KEY=""; NIC_RAW=""; NIC_NOTE=""
  declare -gA ETH_GROUPS=() IB_GROUPS=() IB_GEN=()
  local down=0 i dev spd g rate gen

  # --- Ethernet ports (skip IB netdevs; those are counted via /sys/class/infiniband) ---
  local -A ibnetdev=()
  if [ -d /sys/class/infiniband ]; then
    for d in /sys/class/infiniband/*; do [ -e "$d" ] || continue; :; done
  fi
  for i in /sys/class/net/*; do
    dev="$(basename "$i")"
    [ -e "$i/device" ] || continue                  # physical PCI port only
    # skip if this netdev is InfiniBand (type 32) — handled below
    [ "$(cat "$i/type" 2>/dev/null)" = "32" ] && continue
    spd="$(cat "$i/speed" 2>/dev/null)"
    if ! [[ "$spd" =~ ^[0-9]+$ ]] || [ "$spd" -le 0 ]; then
      # link down: try ethtool, else count as unknown
      if command -v ethtool >/dev/null 2>&1; then
        # indent-/field-agnostic: ethtool indents with a TAB; grab the first number
        # on the Speed: line ("Speed: Unknown!" yields none -> stays down).
        spd="$(ethtool "$dev" 2>/dev/null | awk '/Speed:/{if(match($0,/[0-9]+/)){print substr($0,RSTART,RLENGTH);exit}}')"
      fi
    fi
    if [[ "$spd" =~ ^[0-9]+$ ]] && [ "$spd" -gt 0 ]; then
      g=$(( spd / 1000 ))                            # Mb/s -> Gbps
      ETH_GROUPS[$g]=$(( ${ETH_GROUPS[$g]:-0} + 1 ))
    else
      down=$(( down + 1 ))
    fi
  done

  # --- InfiniBand ports ---
  if [ -d /sys/class/infiniband ]; then
    for d in /sys/class/infiniband/*; do
      [ -d "$d/ports" ] || continue
      for p in "$d"/ports/*; do
        [ -e "$p/rate" ] || continue
        # RoCE (link_layer Ethernet) is counted as ethernet, not IB
        local ll; ll="$(cat "$p/link_layer" 2>/dev/null)"
        rate="$(cat "$p/rate" 2>/dev/null)"          # "200 Gb/sec (4X HDR)"
        g="$(printf '%s' "$rate" | grep -oE '^[0-9]+')"
        [ -z "$g" ] && continue
        gen="$(printf '%s' "$rate" | grep -oE '(EDR|FDR|HDR|NDR|XDR)' | head -n1)"
        if [ "$ll" = "Ethernet" ]; then
          ETH_GROUPS[$g]=$(( ${ETH_GROUPS[$g]:-0} + 1 ))
        else
          IB_GROUPS[$g]=$(( ${IB_GROUPS[$g]:-0} + 1 ))
          [ -n "$gen" ] && IB_GEN[$g]="$gen"
        fi
      done
    done
  fi

  # --- merge eth+ib by speed (ascending) into the canonical NIC key ---
  declare -A allspd=()
  for g in "${!ETH_GROUPS[@]}"; do allspd[$g]=$(( ${allspd[$g]:-0} + ETH_GROUPS[$g] )); done
  for g in "${!IB_GROUPS[@]}";  do allspd[$g]=$(( ${allspd[$g]:-0} + IB_GROUPS[$g] )); done
  local key="" raw=""
  while read -r g; do
    [ -z "$g" ] && continue
    key="${key:+$key+}${g}*${allspd[$g]}"
    raw="${raw:+$raw + }${g}Gbps*${allspd[$g]}"
  done < <(for g in "${!allspd[@]}"; do echo "$g"; done | sort -n)
  NIC_KEY="$key"
  NIC_RAW="$raw"
  [ -z "$NIC_RAW" ] && NIC_RAW="(no physical NIC link detected)"
  [ "$down" -gt 0 ] && NIC_NOTE="${down} physical port(s) link-down; speed unknown, not counted"
}
