#!/bin/bash

#========================================================================
# hybryde-sysinfo.sh — Multi-tab system information (V5)
# V5 fixes:
#   - inxi     : generated into a tmpfile (30s timeout) — no more direct pipe
#                → eliminates inxi process accumulation and freezing
#   - Modules  : same pattern, launched in parallel to not block launch_tabs
#   - TMPFILES : global list, cleaned via trap EXIT
#   - Refresh  : kill + sleep + kill -9 without blocking wait
#========================================================================

#----------------------------------------------------
# Global cleanup of temporary files
#----------------------------------------------------
TMPFILES=()

cleanup_tmpfiles() {
    rm -f "${TMPFILES[@]}" 2>/dev/null
}
trap cleanup_tmpfiles EXIT

new_tmpfile() {
    local f
    f=$(mktemp)
    TMPFILES+=("$f")
    echo "$f"
}

#----------------------------------------------------
# Utility functions
#----------------------------------------------------
function show_mod_info {
    TXT="$(modinfo "$1" 2>/dev/null | sed 's/&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g')"
    yad --title="Module information" \
        --window-icon="application-x-addon" \
        --button="Close:0" \
        --width=500 \
        --image="application-x-addon" --text="$TXT"
}
export -f show_mod_info

function safe_cmd {
    "$@" 2>/dev/null || echo "N/A"
}
export -f safe_cmd

#----------------------------------------------------
# Unigine Heaven path
#----------------------------------------------------
HEAVEN_PATH="$HOME/PS4/BENCH/Unigine_Heaven-4.0/heaven"

#----------------------------------------------------
# Create temporary benchmark scripts
#----------------------------------------------------

# CPU Benchmark — dedicated yad window
cat > /tmp/hyb-cpu-bench.sh << 'BENCH_EOF'
#!/bin/bash
TMPFILE=$(mktemp)
{
    echo "=== CPU Benchmark Hybryde ==="
    echo "Date : $(date)"
    echo ""
    if command -v sysbench >/dev/null 2>&1; then
        echo "--- Sysbench CPU (max-prime=20000) ---"
        sysbench cpu --cpu-max-prime=20000 run 2>&1
    else
        echo "⚠  sysbench non installé (sudo apt install sysbench)"
    fi
    echo ""
    echo "--- Throughput gzip (200 Mo) ---"
    GZIP_SCORE=$(dd if=/dev/zero bs=1M count=200 2>/dev/null | gzip -c | wc -c)
    echo "gzip score: $GZIP_SCORE compressed bytes"
    echo ""
    echo "--- Hash SHA1 (200 Mo) ---"
    SHA_RESULT=$(dd if=/dev/zero bs=1M count=200 2>/dev/null | sha1sum)
    echo "SHA1: $SHA_RESULT"
} > "$TMPFILE" 2>&1
yad --title="CPU Benchmark" \
    --width=650 --height=480 \
    --text-info --scroll \
    --filename="$TMPFILE" \
    --button="Close:0"
rm -f "$TMPFILE"
BENCH_EOF
chmod +x /tmp/hyb-cpu-bench.sh

# Sysbench in terminal
cat > /tmp/hyb-sysbench-term.sh << 'SYS_EOF'
#!/bin/bash
echo "=== Sysbench CPU (max-prime=20000) ==="
echo ""
if command -v sysbench >/dev/null 2>&1; then
    sysbench cpu --cpu-max-prime=20000 run
else
    echo "⚠  sysbench non installé : sudo apt install sysbench"
fi
echo ""
read -r -p "Done — Press Enter to close..."
SYS_EOF
chmod +x /tmp/hyb-sysbench-term.sh

# Stress-ng in terminal
cat > /tmp/hyb-stress-term.sh << 'STRESS_EOF'
#!/bin/bash
echo "=== Stress CPU — stress-ng --cpu 4 (60s) ==="
echo "Ctrl+C pour arrêter prématurément"
echo ""
if command -v stress-ng >/dev/null 2>&1; then
    stress-ng --cpu 4 --timeout 60 --metrics-brief
else
    echo "⚠  stress-ng non installé : sudo apt install stress-ng"
fi
echo ""
read -r -p "Done — Press Enter to close..."
STRESS_EOF
chmod +x /tmp/hyb-stress-term.sh

# Main benchmark launcher script
cat > /tmp/hyb-bench-run.sh << RUNEOF
#!/bin/bash
HEAVEN_PATH="$HEAVEN_PATH"
case "\$*" in
    *"CPU Benchmark"*)  /tmp/hyb-cpu-bench.sh ;;
    *"Sysbench CPU"*)   xfce4-terminal -e /tmp/hyb-sysbench-term.sh ;;
    *"Stress CPU"*)     xfce4-terminal -e /tmp/hyb-stress-term.sh ;;
    *"vkcube"*)         vkcube & ;;
    *"vkmark"*)         vkmark & ;;
    *"glxgears"*)       glxgears & ;;
    *"glmark2"*)        glmark2 & ;;
    *"es2gears"*)       es2gears_x11 & ;;
    *"Heaven"*)         cd "\$(dirname "\$HEAVEN_PATH")" && "\$HEAVEN_PATH" & ;;
esac
RUNEOF
chmod +x /tmp/hyb-bench-run.sh

#----------------------------------------------------
# Clean kill of plug tabs (without blocking wait)
#----------------------------------------------------
kill_tabs() {
    local pids=("$@")
    [ "${#pids[@]}" -eq 0 ] && return

    # SIGTERM first
    kill "${pids[@]}" 2>/dev/null

    # Wait up to 2s for processes to die
    local deadline=$(( $(date +%s) + 2 ))
    while [ "$(date +%s)" -lt "$deadline" ]; do
        local alive=0
        for pid in "${pids[@]}"; do
            kill -0 "$pid" 2>/dev/null && { alive=1; break; }
        done
        [ "$alive" -eq 0 ] && break
        sleep 0.2
    done

    # Force-kill stubborn processes
    kill -9 "${pids[@]}" 2>/dev/null

    # Reap any zombies (non-blocking)
    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null &
    done
}

#----------------------------------------------------
# Launch all plug tabs
# $1 = current yad KEY
# Fills the global TAB_PIDS array
#----------------------------------------------------
launch_tabs() {
    local KEY="$1"
    TAB_PIDS=()

    #-----------------------------------------------------------------
    # FREEZE FIX: generate slow content into tmpfiles
    # IN PARALLEL from the start, before launching the yad tab windows.
    # We wait for their PIDs just before launching the relevant tabs.
    #-----------------------------------------------------------------

    # inxi -F — launched in background with strict timeout
    local INXI_TMP
    INXI_TMP=$(new_tmpfile)
    local INXI_GEN_PID=0
    if command -v inxi >/dev/null 2>&1; then
        timeout 30 inxi -F -c 0 > "$INXI_TMP" 2>/dev/null &
        INXI_GEN_PID=$!
    else
        echo "inxi unavailable (sudo apt install inxi)" > "$INXI_TMP"
    fi

    # Modules — launched in background (can be slow on some systems)
    local MOD_TMP
    MOD_TMP=$(new_tmpfile)
    local MOD_GEN_PID
    (
        echo "=== Loaded modules (kernel live) ==="
        echo ""
        if [[ -s /proc/modules ]]; then
            cat /proc/modules
        else
            echo "No module loaded actuellement"
        fi

        echo ""
        echo "====================================="
        echo "=== Modules dans initramfs détectés ==="
        echo "====================================="
        echo ""

        local FOUND_INIT=0
        for img in \
            /system/boot/initramfs.cpio.gz \
            /system/boot/initramfs.gz \
            /mnt/sda1/initramfs.cpio.gz \
            /mnt/sda1/initramfs.gz \
            /mnt/sda1/initrd.img \
            /boot/initrd.img*; do
            if [[ -f "$img" ]]; then
                FOUND_INIT=1
                echo "--- $img ---"
                zcat "$img" 2>/dev/null | cpio -t 2>/dev/null | grep '\.ko' \
                    || echo "Cannot read or no modules found"
                echo ""
            fi
        done
        [[ $FOUND_INIT -eq 0 ]] && echo "No initramfs found"

        echo ""
        echo "====================================="
        echo "=== Kernel détecté (bzImage) ==="
        echo "====================================="
        echo ""
        for k in /system/boot/bzImage /mnt/sda1/bzImage /boot/vmlinuz*; do
            [[ -f "$k" ]] && echo "Kernel found: $k"
        done

        echo ""
        echo "====================================="
        echo "=== Modules disponibles (/lib/modules) ==="
        echo "====================================="
        echo ""
        KVER="$(uname -r)"
        MOD_DIR=""

        # 1. Chemin exact
        if [[ -d "/lib/modules/$KVER" ]]; then
            MOD_DIR="/lib/modules/$KVER"
        else
            # 2. Chercher un dossier dont le nom commence par la version numérique
            #    ex : 7.0.4 -> matche 7.0.4.src-KHEOPS-FullLTO-v2.1-60Hz
            KNUM="$(echo "$KVER" | grep -oP '^\d+\.\d+\.\d+')"
            if [[ -n "$KNUM" ]]; then
                FOUND="$(find /lib/modules -maxdepth 1 -type d -name "${KNUM}*" 2>/dev/null | head -n1)"
                [[ -n "$FOUND" ]] && MOD_DIR="$FOUND"
            fi
        fi

        # 3. Lister tous les dossiers disponibles dans tous les cas
        echo "Kernel courant    : $KVER"
        echo "Dossiers presents dans /lib/modules :"
        ls /lib/modules/ 2>/dev/null | sed 's/^/  /' || echo "  (vide ou inaccessible)"
        echo ""

        if [[ -n "$MOD_DIR" ]]; then
            echo "Dossier utilise   : $MOD_DIR"
            echo ""
            KO_COUNT=$(find "$MOD_DIR" -name "*.ko" 2>/dev/null | wc -l)
            echo "Modules .ko trouves : $KO_COUNT"
            echo ""
            find "$MOD_DIR" -name "*.ko" 2>/dev/null | head -n 80 | sed 's|.*/||'
            [[ "$KO_COUNT" -gt 80 ]] && echo "" && echo "(affiche : 80 / $KO_COUNT)"
        else
            # Detecter si c'est un kernel monolithique (lsmod vide)
            LSMOD_COUNT=$(lsmod 2>/dev/null | tail -n +2 | wc -l)
            if [[ "$LSMOD_COUNT" -eq 0 ]]; then
                echo ">>> Kernel monolithique (CONFIG_MODULES minimal)"
                echo "    Aucun module charge (lsmod vide) - tout est compile en dur dans le bzImage."
                echo "    Normal pour un kernel PS4."
                echo ""
                # Afficher les rares =m s'ils existent
                if [[ -f /proc/config.gz ]]; then
                    MOD_M=$(zcat /proc/config.gz 2>/dev/null | grep "=m$")
                    if [[ -n "$MOD_M" ]]; then
                        echo "Modules optionnels (=m dans config, non encore installes) :"
                        echo "$MOD_M" | sed 's/^/  /'
                        echo ""
                        echo "Pour les installer depuis le repertoire source du kernel :"
                        echo "  make -j\$(nproc) modules"
                        echo "  sudo make modules_install"
                    else
                        echo "Aucun module =m dans la config : kernel 100% monolithique."
                    fi
                fi
            else
                echo "Aucun dossier /lib/modules/$KVER"
                echo "   -> make modules_install n'a pas encore ete execute"
                echo "   -> Depuis le repertoire source du kernel :"
                echo "      make -j\$(nproc) modules && sudo make modules_install"
            fi
            echo ""
            for ALTMOD in /system/boot/modules /mnt/sda1/lib/modules; do
                if [[ -d "$ALTMOD" ]]; then
                    echo "Dossier alternatif trouve : $ALTMOD"
                    find "$ALTMOD" -name "*.ko" 2>/dev/null | head -n 40 | sed 's|.*/||'
                    echo ""
                fi
            done
        fi

        echo ""
        echo "====================================="
        echo "=== Drivers actifs (lspci -k) ==="
        echo "====================================="
        echo ""
        if command -v lspci >/dev/null 2>&1; then
            lspci -k
        else
            echo "lspci unavailable"
        fi

        echo ""
        echo "====================================="
        echo "=== Info kernel modules config ==="
        echo "====================================="
        echo ""
        if [[ -f /proc/config.gz ]]; then
            zcat /proc/config.gz | grep CONFIG_MODULES
        else
            echo "config.gz unavailable"
        fi
    ) > "$MOD_TMP" 2>/dev/null &
    MOD_GEN_PID=$!

    #### Tab 1 — CPU ####
    safe_cmd lscpu | sed -r "s/:[ ]*/\n/" \
    | yad --plug="$KEY" --tabnum=1 \
          --list --no-selection \
          --column="Parameter" --column="Valeur" &
    TAB_PIDS+=($!)

    #### Tab 2 — Memory ####
    safe_cmd free -h | awk 'NR==1{next} {printf "%s\n%s\n%s\n", $1,$2,$3}' \
    | yad --plug="$KEY" --tabnum=2 \
          --list --no-selection \
          --column="Type" --column="Total" --column="Used" &
    TAB_PIDS+=($!)

    #### Tab 3 — Disks ####
    safe_cmd df -T | tail -n +2 \
        | awk '{printf "%s\n%s\n%s\n%s\n%s\n%s\n", $1,$7,$2,$3,$4,$6}' \
    | yad --plug="$KEY" --tabnum=3 \
          --list --no-selection \
          --column="Device" --column="Mount point" --column="Type" \
          --column="Total:sz" --column="Libre:sz" --column="Utilisation:bar" &
    TAB_PIDS+=($!)

    #### Tab 4 — I/O ####
    safe_cmd iostat -x 1 1 | tail -n +4 \
        | awk '{printf "%s\n%s\n%s\n%s\n%s\n", $1,$2,$3,$4,$10}' \
    | yad --plug="$KEY" --tabnum=4 \
          --list --no-selection \
          --column="Device" --column="tps" --column="KB lect/s" \
          --column="KB écrit/s" --column="%Util" &
    TAB_PIDS+=($!)

    #### Tab 5 — Processes ####
    ps aux --sort=-%mem | head -n 10 \
        | awk '{printf "%s\n%s\n%s\n%s\n", $1,$3,$4,$11}' \
    | yad --plug="$KEY" --tabnum=5 \
          --list --no-selection \
          --column="User" --column="CPU%" --column="MEM%" --column="Commande" &
    TAB_PIDS+=($!)

    #### Tab 6 — Load ####
    echo -e "Charge\n$(uptime | awk -F'load average:' '{print $2}')" \
        | sed 's/,/\n/g' \
    | yad --plug="$KEY" --tabnum=6 \
          --list --no-selection \
          --column="Metric" --column="Valeur" &
    TAB_PIDS+=($!)

    #### Tab 7 — GPU ####
    # timeout on glxinfo which can block on some configs
    {
        safe_cmd lspci | grep -i vga
        timeout 10 glxinfo 2>/dev/null | grep "OpenGL renderer" || true
    } | sed -r "s/: /\n/" \
    | yad --plug="$KEY" --tabnum=7 \
          --list --no-selection \
          --column="Type" --column="Valeur" &
    TAB_PIDS+=($!)

    #### Tab 8 — USB ####
    safe_cmd lsusb \
    | yad --plug="$KEY" --tabnum=8 \
          --list --no-selection \
          --column="USB Devices" &
    TAB_PIDS+=($!)

    #### Tab 9 — Network ####
    safe_cmd hostname -I | tr ' ' '\n' \
    | yad --plug="$KEY" --tabnum=9 \
          --list --no-selection \
          --column="IP Address" &
    TAB_PIDS+=($!)

    #### Tab 10 — PCI ####
    if command -v lspci >/dev/null 2>&1; then
        lspci -vmm | grep -E "^(Slot|Class|Vendor|Device|Rev):" | cut -f2 \
        | yad --plug="$KEY" --tabnum=10 \
              --list --no-selection \
              --column="ID" --column="Classe" \
              --column="Vendor" --column="Device" \
              --column="Rev." &
    else
        yad --plug="$KEY" --tabnum=10 \
            --text="lspci unavailable" &
    fi
    TAB_PIDS+=($!)

    #### Tab 11 — Modules ####
    # Wait for generation to finish (already launched in parallel above)
    wait "$MOD_GEN_PID" 2>/dev/null
    yad --plug="$KEY" --tabnum=11 \
        --text-info --scroll \
        --width=900 --height=550 \
        --filename="$MOD_TMP" &
    TAB_PIDS+=($!)

    #### Tab 12 — Sensors ####
    if command -v sensors >/dev/null 2>&1; then
        sensors | sed -r "s/: /\n/" \
        | yad --plug="$KEY" --tabnum=12 \
              --list --no-selection \
              --column="Sensor" --column="Valeur" &
    else
        yad --plug="$KEY" --tabnum=12 \
            --text="sensors unavailable (sudo apt install lm-sensors)" &
    fi
    TAB_PIDS+=($!)

    #### Tab 13 — inxi -F ####
    # FREEZE FIX: wait for inxi generation to finish (launched in parallel),
    # then pass the resulting file to yad via --filename.
    # No more direct pipe → no more orphan inxi process accumulation.
    wait "$INXI_GEN_PID" 2>/dev/null
    yad --plug="$KEY" --tabnum=13 \
        --text="<b>inxi -F</b> — use ⟳ Refresh inxi (bottom of window) to reload" \
        --text-info --scroll \
        --width=800 --height=500 \
        --filename="$INXI_TMP" &
    TAB_PIDS+=($!)

    #### Tab 14 — Benchmark ####
    yad --plug="$KEY" --tabnum=14 \
        --list \
        --dclick-action='/tmp/hyb-bench-run.sh %s' \
        --print-column=2 \
        --no-headers \
        --column="🚀  Double-click to launch" \
        --column="CMD":HD \
        "── CPU ──────────────────────────────────"   "" \
        "🔲  CPU Benchmark (dedicated window)"          "/tmp/hyb-cpu-bench.sh" \
        "⚡  Sysbench CPU (terminal)"                 "xfce4-terminal -e /tmp/hyb-sysbench-term.sh" \
        "💪  CPU Stress — stress-ng (terminal)"       "xfce4-terminal -e /tmp/hyb-stress-term.sh" \
        "── GPU / OpenGL / Vulkan ────────────────"   "" \
        "🔵  vkcube — Vulkan rotating cube"           "vkcube" \
        "🔷  vkmark — Vulkan benchmark"               "vkmark" \
        "🟢  glxgears — Quick OpenGL test"           "glxgears" \
        "🟡  glmark2 — OpenGL benchmark"              "glmark2" \
        "🔶  es2gears — OpenGL ES"                    "es2gears_x11" \
        "⛪  Unigine Heaven"                          "$HEAVEN_PATH" \
        &
    TAB_PIDS+=($!)
}

#----------------------------------------------------
# Main loop — supports ⟳ Refresh inxi
# Exit code 10 = refresh
# Any other code  = close
#----------------------------------------------------
while true; do
    KEY=$RANDOM
    TAB_PIDS=()

    launch_tabs "$KEY"

    TXT="<b>Hardware information — Hybryde System Info V5</b>\n\n"
    TXT+="OS: $(safe_cmd lsb_release -ds) — $(hostname)\n"
    TXT+="Kernel: $(uname -sr)\n"
    TXT+="Uptime: $(uptime -p)\n"
    TXT+="CPU Load:$(uptime | awk -F'load average:' '{print $2}')"

    yad --notebook \
        --window-icon="dialog-information" \
        --width=900 --height=600 \
        --title="Hybryde System Info (V5)" \
        --image="/usr/share/hybryde/logos/hybryde-sm.png" \
        --image-on-top \
        --text="$TXT" \
        --key="$KEY" \
        --tab="CPU" \
        --tab="Memory" \
        --tab="Disks" \
        --tab="I/O" \
        --tab="Processes" \
        --tab="Load" \
        --tab="GPU" \
        --tab="USB" \
        --tab="Network" \
        --tab="PCI" \
        --tab="Modules" \
        --tab="Sensors" \
        --tab="inxi -F" \
        --tab="Benchmark" \
        --active-tab=1 \
        --button="⟳ Refresh inxi:10" \
        --button="Close:1"
    EXIT=$?

    # FREEZE FIX: kill plug tabs with kill_tabs (timeout + kill -9)
    # instead of blocking wait on potentially orphaned processes
    kill_tabs "${TAB_PIDS[@]}"

    # Code 10 = ⟳ Refresh → loop again
    [ "$EXIT" -eq 10 ] || break
done

# Cleanup temporary benchmark scripts
rm -f /tmp/hyb-cpu-bench.sh \
      /tmp/hyb-sysbench-term.sh \
      /tmp/hyb-stress-term.sh \
      /tmp/hyb-bench-run.sh

# TMPFILES are cleaned by the EXIT trap
