# shellcheck shell=bash
# catalog.sh — 机型ID 命名规范表 (model-ID naming catalog)
#
# Sourced by catcher.bash. Defines, for each subsystem, a map from a
# *canonical key* (a normalized, hardware-independent description of the
# config) to the catalog ID, plus a reverse map ID -> human spec.
#
# Canonical-key conventions (must match what detect.sh produces):
#   CPU   "<Vendor> <SKU>|<sockets>"        e.g. "Intel 6530|2"
#   GPU   "<token>|<count>"                 token = family+variant+mem, e.g. "RTX5090|8"
#   MEM   "<sizeGB>|<dimm_count>"           e.g. "64|32"
#   NIC   "<spd>*<n>[+<spd>*<n>...]"        speeds in Gbps, segments sorted ASCENDING, merged per speed
#   DISK  "<label>*<n>[+...]"               labels normalized, segments sorted ASCENDING by capacity, merged per size
#
# Everything is data; matching logic lives in idgen.sh. Keep this file pure
# declarations so it is trivial to audit against the source spec.

# ---------------------------------------------------------------------------
# GPU   (token|count -> ID).  Token captures family + PCIe/SXM(nvlink) + mem,
# because e.g. A100-PCIe-40G, A100-PCIe-80G and A100-SXM-80G are different IDs.
# detect.sh maps the nvidia-smi product string to one of these tokens.
# ---------------------------------------------------------------------------
declare -gA GPU_ID=(
  ["RTX5090|8"]=G90        # 5090-PCIe-32GB *8
  ["B200|8"]=G92           # B200-nvlink181G *8
  ["B300|8"]=G94           # B300-nvlink288G *8
  ["L20|1"]=G80            # L20 *1
  ["H100-SXM-80G|8"]=G81   # H100-nvlink80G *8
  ["L40|8"]=G82            # L40 *8
  ["L40|4"]=G83            # L40 *4
  ["L40S|8"]=G84           # L40S *8
  ["L40S|4"]=G85           # L40S *4
  ["H20-96G|8"]=G86        # H20-nvlink96G *8
  ["H20-141G|8"]=G87       # H20-nvlink141G *8
  ["H200-141G|8"]=G88      # H200-nvlink141G *8
  ["A100-PCIE-40G|4"]=G70  # A100-PCIe40G *4
  ["A100-SXM-80G|8"]=G71   # A100-nvlink80G *8
  ["A100-SXM-40G|8"]=G72   # A100-nvlink40G *8
  ["A800-SXM-80G|8"]=G73   # A800-nvlink80G *8
  ["A100-PCIE-80G|8"]=G74  # A100-PCIe80G *8
  ["A100-PCIE-40G|8"]=G75  # A100-PCIe40G *8
  ["A100-PCIE-80G|4"]=G76  # A100-PCIe80G *4
  ["A10|1"]=G77            # A10 *1
  ["A10|8"]=G78            # A10 *8
  ["A10|4"]=G79            # A10 *4
  ["V100-PCIE-16G|1"]=G50  # V100-PCIe-16G *1
  ["V100-SXM2|8"]=G51      # V100-SXM2 *8
  ["V100S-PCIE-32G|6"]=G53 # V100S-PCIe 32G *6
  ["2080Ti|8"]=G61         # 2080Ti *8
)
declare -gA GPU_DESC=(
  [G90]="5090 *8"      [G92]="B200 *8"     [G94]="B300 *8"
  [G80]="L20 *1"       [G81]="H100 *8"     [G82]="L40 *8"
  [G83]="L40 *4"       [G84]="L40S *8"     [G85]="L40S *4"
  [G86]="H20 96G *8"   [G87]="H20 141G *8" [G88]="H200 *8"
  [G70]="A100-PCIe 40G *4" [G71]="A100 80G *8" [G72]="A100 40G *8"
  [G73]="A800 80G *8"  [G74]="A100-PCIe 80G *8" [G75]="A100-PCIe 40G *8"
  [G76]="A100-PCIe 80G *4" [G77]="A10 *1"  [G78]="A10 *8" [G79]="A10 *4"
  [G50]="V100-PCIe 16G *1" [G51]="V100-SXM2 *8" [G53]="V100S-PCIe 32G *6"
  [G61]="2080Ti *8"
)

# ---------------------------------------------------------------------------
# CPU   ("<Vendor> <SKU>|<sockets>" -> ID)
# ---------------------------------------------------------------------------
declare -gA CPU_ID=(
  ["Intel 6745P|2"]=I61 ["Intel 6767P|2"]=I62 ["Intel 6530P|2"]=I63
  ["Intel 6960P|2"]=I64 ["Intel 6982P|1"]=I65 ["Intel 6982P|2"]=I66
  ["Intel 8558P|2"]=I51 ["Intel 5520+|2"]=I52 ["Intel 4516Y+|2"]=I53
  ["Intel 6548Y+|2"]=I54 ["Intel 8562Y+|2"]=I55 ["Intel 8558|2"]=I56
  ["Intel 6530|2"]=I57 ["Intel 8575C|2"]=I58
  ["Intel 6430|2"]=I41 ["Intel 8468|2"]=I42 ["Intel 8468V|2"]=I43
  ["Intel 6444Y|2"]=I44 ["Intel 5418Y|2"]=I45 ["Intel 6418H|2"]=I46
  ["Intel 6448H|2"]=I47 ["Intel 8480+|2"]=I48 ["Intel 8457C|2"]=I49
  ["Intel 8358|2"]=I31 ["Intel 6330|2"]=I32 ["Intel 8358P|2"]=I33
  ["Intel 6348|2"]=I34 ["Intel 8374C|2"]=I35 ["Intel 6326|2"]=I36
  ["Intel 6354|2"]=I37 ["Intel 5318Y|2"]=I38 ["Intel 6346|2"]=I39
  ["Intel 6342|2"]=I3A
  ["Intel 6230|2"]=I21 ["Intel 4210|2"]=I22 ["Intel 6226R|2"]=I23
  ["Intel 4214|2"]=I24 ["Intel 6258R|2"]=I25
  ["AMD 9575F|2"]=A51 ["AMD 9375F|2"]=A52 ["AMD 9755|2"]=A53
  ["AMD 9354|2"]=A41 ["AMD 9334|2"]=A42 ["AMD 9274F|2"]=A43 ["AMD 9374F|2"]=A44
  ["AMD 7713|2"]=A31 ["AMD 74F3|2"]=A32 ["AMD 7443|2"]=A33
  ["AMD 7352|2"]=A21 ["AMD 7402|2"]=A22 ["AMD 7742|2"]=A23 ["AMD 7702|2"]=A24
)
declare -gA CPU_DESC=(
  [I61]="Intel 6745P *2" [I62]="Intel 6767P *2" [I63]="Intel 6530P *2"
  [I64]="Intel 6960P *2" [I65]="Intel 6982P *1" [I66]="Intel 6982P *2"
  [I51]="Intel 8558P *2" [I52]="Intel 5520+ *2" [I53]="Intel 4516Y+ *2"
  [I54]="Intel 6548Y+ *2" [I55]="Intel 8562Y+ *2" [I56]="Intel 8558 *2"
  [I57]="Intel 6530 *2" [I58]="Intel 8575C *2"
  [I41]="Intel 6430 *2" [I42]="Intel 8468 *2" [I43]="Intel 8468V *2"
  [I44]="Intel 6444Y *2" [I45]="Intel 5418Y *2" [I46]="Intel 6418H *2"
  [I47]="Intel 6448H *2" [I48]="Intel 8480+ *2" [I49]="Intel 8457C *2"
  [I31]="Intel 8358 *2" [I32]="Intel 6330 *2" [I33]="Intel 8358P *2"
  [I34]="Intel 6348 *2" [I35]="Intel 8374C *2" [I36]="Intel 6326 *2"
  [I37]="Intel 6354 *2" [I38]="Intel 5318Y *2" [I39]="Intel 6346 *2"
  [I3A]="Intel 6342 *2"
  [I21]="Intel 6230 *2" [I22]="Intel 4210 *2" [I23]="Intel 6226R *2"
  [I24]="Intel 4214 *2" [I25]="Intel 6258R *2"
  [A51]="AMD 9575F *2" [A52]="AMD 9375F *2" [A53]="AMD 9755 *2"
  [A41]="AMD 9354 *2" [A42]="AMD 9334 *2" [A43]="AMD 9274F *2" [A44]="AMD 9374F *2"
  [A31]="AMD 7713 *2" [A32]="AMD 74F3 *2" [A33]="AMD 7443 *2"
  [A21]="AMD 7352 *2" [A22]="AMD 7402 *2" [A23]="AMD 7742 *2" [A24]="AMD 7702 *2"
)

# CPU SKU -> memory generation (DDR4/DDR5). Used so describe-from-ID can print
# "DDR4 64G*32" even though the M-code itself doesn't encode the DDR gen.
# Rule of thumb: Cascade Lake (62xx/52xx/42xx) & Ice Lake (I3x) & AMD Rome/Milan
# (7xxx) are DDR4; Sapphire/Emerald/Granite Rapids (I4x/I5x/I6x) & AMD Genoa/
# Turin (9xxx) are DDR5. detect mode overrides this with the real dmidecode type.
declare -gA CPU_MEMGEN=(
  [I61]=DDR5 [I62]=DDR5 [I63]=DDR5 [I64]=DDR5 [I65]=DDR5 [I66]=DDR5
  [I51]=DDR5 [I52]=DDR5 [I53]=DDR5 [I54]=DDR5 [I55]=DDR5 [I56]=DDR5 [I57]=DDR5 [I58]=DDR5
  [I41]=DDR5 [I42]=DDR5 [I43]=DDR5 [I44]=DDR5 [I45]=DDR5 [I46]=DDR5 [I47]=DDR5 [I48]=DDR5 [I49]=DDR5
  [I31]=DDR4 [I32]=DDR4 [I33]=DDR4 [I34]=DDR4 [I35]=DDR4 [I36]=DDR4 [I37]=DDR4 [I38]=DDR4 [I39]=DDR4 [I3A]=DDR4
  [I21]=DDR4 [I22]=DDR4 [I23]=DDR4 [I24]=DDR4 [I25]=DDR4
  [A51]=DDR5 [A52]=DDR5 [A53]=DDR5 [A41]=DDR5 [A42]=DDR5 [A43]=DDR5 [A44]=DDR5
  [A31]=DDR4 [A32]=DDR4 [A33]=DDR4 [A21]=DDR4 [A22]=DDR4 [A23]=DDR4 [A24]=DDR4
)

# ---------------------------------------------------------------------------
# Memory   ("<sizeGB>|<count>" -> ID)
# NOTE: M60 and M61 BOTH map to 64G*8 in the source spec (a collision). We keep
# both in *_DESC but generation prefers M60; M61 is treated as its alias.
# ---------------------------------------------------------------------------
declare -gA MEM_ID=(
  ["8|3"]=M31  ["8|4"]=M32
  ["16|10"]=M41 ["16|16"]=M42
  ["32|8"]=M51 ["32|16"]=M52 ["32|24"]=M53 ["32|32"]=M54 ["32|12"]=M55
  ["64|8"]=M60 ["64|12"]=M62 ["64|16"]=M63 ["64|24"]=M64 ["64|32"]=M65
  ["96|32"]=M75
)
declare -gA MEM_DESC=(
  [M31]="8G *3"  [M32]="8G *4"
  [M41]="16G *10" [M42]="16G *16"
  [M51]="32G *8" [M52]="32G *16" [M53]="32G *24" [M54]="32G *32" [M55]="32G *12"
  [M60]="64G *8" [M61]="64G *8" [M62]="64G *12" [M63]="64G *16" [M64]="64G *24" [M65]="64G *32"
  [M75]="96G *32"
)

# ---------------------------------------------------------------------------
# Network   (canonical speed-group -> ID).  Speeds in Gbps, ascending, merged.
# N14 in the source is empty and intentionally omitted.
# ---------------------------------------------------------------------------
declare -gA NIC_ID=(
  ["10*2"]=N11
  ["25*2"]=N12
  ["100*2"]=N13
  ["25*2+200*1"]=N20
  ["10*2+100*2"]=N21
  ["10*2+200*2"]=N22
  ["25*2+200*2"]=N23
  ["25*2+400*2"]=N24
  ["25*2+400*4"]=N25
  ["25*2+100*2"]=N26
  ["25*2+400*8"]=N27
  ["25*2+400*3"]=N28
  ["25*2+200*4"]=N29
  ["25*2+100*8"]=N2A
  ["100*2+200*2"]=N2B
  ["25*2+200*1+400*8"]=N31
  ["100*2+200*18"]=N32      # source: 100*2 + 200*2 + 200*16 (typo "200Gbos"); merged 200*18
  ["100*2+200*2+800*8"]=N33
  ["1*2+10*6"]=N41          # source: 1*2 + 10*2 + 10*2 + 10*2 ; merged 10*6
  ["1*2+10*2+25*4"]=N42
)
declare -gA NIC_DESC=(
  [N11]="10Gbps *2" [N12]="25Gbps *2" [N13]="100Gbps *2"
  [N20]="25Gbps *2 + 200Gbps *1" [N21]="10Gbps *2 + 100Gbps *2"
  [N22]="10Gbps *2 + 200Gbps *2" [N23]="25Gbps *2 + 200Gbps *2"
  [N24]="25Gbps *2 + 400Gbps *2" [N25]="25Gbps *2 + 400Gbps *4"
  [N26]="25Gbps *2 + 100Gbps *2" [N27]="25Gbps *2 + 400Gbps *8"
  [N28]="25Gbps *2 + 400Gbps *3" [N29]="25Gbps *2 + 200Gbps *4"
  [N2A]="25Gbps *2 + 100Gbps *8" [N2B]="100Gbps *2 + 200Gbps *2"
  [N31]="25Gbps *2 + 200Gbps *1 + 400Gbps *8"
  [N32]="100Gbps *2 + 200Gbps *2 + 200Gbps *16"
  [N33]="100Gbps *2 + 200Gbps *2 + 800Gbps *8"
  [N41]="1Gbps *2 + 10Gbps *2 + 10Gbps *2 + 10Gbps *2"
  [N42]="1Gbps *2 + 10Gbps *2 + 25Gbps *4"
)
# Per-ID InfiniBand generation override for the high-speed ports, where the
# source examples pin it (200G can be HDR *or* NDR200). Key "<Nid>:<spd>".
# Anything not listed falls back to NIC_IBGEN_DEFAULT by speed in idgen.sh.
declare -gA NIC_IBGEN=(
  ["N20:200"]=NDR   # example: I31G82N20... -> "NDR 200G单口网卡*1"
  ["N23:200"]=HDR   # example: I31G82N23... -> "HDR 200G单口网卡*2"
)

# ---------------------------------------------------------------------------
# Disk   (canonical tier-group -> ID).  Sizes normalized, segments ascending by
# capacity and merged per size. Media (SSD/HDD) is descriptive only (kept in
# DISK_DESC); matching is by size+count because that is all most IDs encode.
# ---------------------------------------------------------------------------
declare -gA DISK_ID=(
  ["480G*1"]=S01
  ["480G*2"]=S02
  ["960G*2"]=S03
  ["1.2T*2"]=S04
  ["800G*2"]=S05
  ["1.7T*1"]=S06
  ["4T*8"]=S07
  ["4T*10"]=S08
  ["1.92T*2"]=S09
  ["960G*2+3.84T*2"]=S10
  ["480G*2+1.92T*3"]=S11
  ["960G*2+1.92T*2"]=S12
  ["960G*2+3.84T*4"]=S13
  ["960G*2+3.84T*3"]=S14
  ["960G*2+3.84T*6"]=S15
  ["960G*2+10T*2"]=S16
  ["960G*2+3.84T*10"]=S17
  ["1.92T*2+3.84T*8"]=S18
  ["960G*2+1.92T*6"]=S19
  ["2.4T*8+3.84T*3"]=S1A
  ["960G*2+12T*12"]=S1B
  ["960G*2+7.68T*16"]=S1C
  ["960G*2+7.68T*10"]=S1D
  ["960G*2+7.68T*4"]=S1F
  ["3.84T*2+8T*3"]=S21
  ["960G*2+2.4T*8+3.84T*6"]=S22
  ["900G*3+1.92T*3"]=S23                  # NOTE: source lists S23 twice; see S23b
  ["900G*3+1.92T*3+2.4T*8"]=S23           # second S23 variant -> same ID
  ["800G*2+2.4T*6+3.84T*4"]=S24
  ["1.2T*3+1.92T*3"]=S25
  ["1.2T*3+3.84T*3+7.68T*3"]=S26
  ["1.2T*3+1.92T*4"]=S27                  # source: 1.2T*3 + 1.92T*2 + 1.92T*2 ; merged 1.92T*4
  ["480G*2+2.4T*8+3.84T*4"]=S28
  ["2.4T*8+3.84T*8"]=S29
  ["800G*2+2.4T*4+3.84T*2"]=S2A
)
declare -gA DISK_DESC=(
  [S01]="480G *1" [S02]="480G *2" [S03]="960G *2" [S04]="1.2T *2" [S05]="800G *2"
  [S06]="1.7TB" [S07]="4TB *8" [S08]="4TB *10" [S09]="1.92TB *2"
  [S10]="960G *2 + 3.84T *2" [S11]="480G *2 + 1.92T *3" [S12]="960G *2 + 1.92T *2"
  [S13]="960G *2 + 3.84T *4" [S14]="960G *2 + 3.84T *3" [S15]="960G *2 + 3.84T *6"
  [S16]="960G *2 + 10T *2" [S17]="960G *2 + 3.84T *10" [S18]="1.92T *2 + 3.84T *8"
  [S19]="960G *2 + 1.92T *6" [S1A]="3.84T *3 + 2.4T *8" [S1B]="960G *2 + 12T *12"
  [S1C]="960G *2 + 7.68T *16" [S1D]="960G *2 + 7.68T *10" [S1F]="960G *2 + 7.68T *4"
  [S21]="8T *3 + 3.84T *2" [S22]="960G *2 + 3.84T *6 + 2.4T *8"
  [S23]="900G *3 + 1.92T *3 (+ 2.4T *8)" [S24]="800G *2 + 2.4T *6 + 3.84T *4"
  [S25]="1.2TB *3 + 1.92TB *3" [S26]="1.2TB *3 + 7.68TB *3 + 3.84TB *3"
  [S27]="1.2TB *3 + 1.92TB *2 + 1.92TB *2"
  [S28]="480GB *2 + SSD 3.84T *4 + HDD 2.4T *8"
  [S29]="HDD 2.4T *8 + SSD 3.84T *8" [S2A]="800G *2 + SSD 3.84T *2 + HDD 2.4T *4"
)

# Marketed disk-size buckets: decimal GB -> canonical label. detect.sh snaps a
# raw byte size to the nearest bucket (tolerance handled in idgen.sh).
# (A "960GB" SSD reports ~894GiB; a "3.84TB" SSD ~3576GiB, etc.)
declare -gA DISK_LABEL=(
  [480]="480G" [800]="800G" [900]="900G" [960]="960G"
  [1200]="1.2T" [1600]="1.6T" [1700]="1.7T" [1920]="1.92T"
  [2400]="2.4T" [3200]="3.2T" [3840]="3.84T" [4000]="4T"
  [7680]="7.68T" [8000]="8T" [10000]="10T" [12000]="12T"
)
# ascending list of bucket sizes (GB) for nearest-match
DISK_BUCKETS=(480 800 900 960 1200 1600 1700 1920 2400 3200 3840 4000 7680 8000 10000 12000)

# Media override for describe-from-ID (when there is no live ROTA reading).
# Only the tiers the source spec explicitly tags as HDD need listing; the rest
# default to SSD. Key "<Sid>|<label>". detect mode overrides this with ROTA.
declare -gA DISK_MEDIA_SPEC=(
  ["S28|2.4T"]=HDD ["S29|2.4T"]=HDD ["S2A|2.4T"]=HDD
)
