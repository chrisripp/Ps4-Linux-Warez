#!/bin/bash

#========================================================================
# hybryde-ps4-tools.sh — Hybryde PS4 Tools
# Multi-tab YAD interface for PS4 Linux tools
# Version : 1.1 — 2026
# By triki1
#========================================================================

preview_pdf() {
    local FILE="${1/#\~/$HOME}"

    if [ ! -f "$FILE" ]; then
        yad_err "File not found:\n<tt>$FILE</tt>"
        return
    fi

    local TMPTXT TMPIMG IMG_FILE
    TMPTXT=$(mktemp)
    TMPIMG=$(mktemp --suffix=.png)

    # Extract text (fast, page 1 only)
    if command -v pdftotext >/dev/null 2>&1; then
        pdftotext -l 1 "$FILE" "$TMPTXT" 2>/dev/null
    else
        echo "pdftotext not installed (sudo apt install poppler-utils)" > "$TMPTXT"
    fi

    # Generate image preview (page 1)
    if command -v pdftoppm >/dev/null 2>&1; then
        pdftoppm -f 1 -l 1 -png "$FILE" "${TMPIMG%.png}" 2>/dev/null
        IMG_FILE="${TMPIMG%.png}-1.png"
    fi

    yad --title="PDF Preview — $(basename "$FILE")" \
        --width=640 --height=480 \
        --center \
        --text-info --scroll \
        --filename="$TMPTXT" \
        ${IMG_FILE:+--image="$IMG_FILE" --image-on-top} \
        --button="📂 Open in viewer:0" \
        --button="Close:1"

    local ret=$?
    rm -f "$TMPTXT" "$TMPIMG"* 2>/dev/null

    # "Open" button → launch default PDF reader
    [ $ret -eq 0 ] && xdg-open "$FILE" >/dev/null 2>&1 &
}
export -f preview_pdf


KEY=$RANDOM
LOGO="/usr/share/hybryde/logos/hybryde-sm.png"
CONF_DIR="$HOME/.config/hybryde/ps4tools"
mkdir -p "$CONF_DIR"

#--- Git / Orbis ---
PROJECT_DIR="$HOME/PROJECT-PS4"
KERNELS_DIR="$PROJECT_DIR/kernels"
ORBIS_DIR="$PROJECT_DIR/orbis"
export PROJECT_DIR KERNELS_DIR ORBIS_DIR
mkdir -p "$KERNELS_DIR"   # orbis created only at installation (do_git_orbis)

#--- DionKill download directories ---
DL_KERNELS_DIR="$PROJECT_DIR/system/kernels"
DL_INITRAMFS_DIR="$PROJECT_DIR/system/initramfs"
DL_DISTROS_DIR="$PROJECT_DIR/system/distros"
mkdir -p "$DL_KERNELS_DIR" "$DL_INITRAMFS_DIR" "$DL_DISTROS_DIR"
export DL_KERNELS_DIR DL_INITRAMFS_DIR DL_DISTROS_DIR
# ── Inter-dialog state files ──────────────────────────────────────────
TAR_EXCLUDES_FILE="$CONF_DIR/tar-excludes.txt"
TAR_NAME_FILE="$CONF_DIR/tar-name.txt"
TAR_CMD_FILE="$CONF_DIR/tar-cmd.txt"
IMG_PATH_FILE="$CONF_DIR/img-path.txt"
EXT_SRC_FILE="$CONF_DIR/extract-src.txt"
EXT_DST_FILE="$CONF_DIR/extract-dst.txt"
BUILD_CMD_FILE="$CONF_DIR/build-cmd.txt"

# ── Default values ────────────────────────────────────────────────────
[ ! -f "$TAR_NAME_FILE" ]     && echo "ps4linux.tar.xz" > "$TAR_NAME_FILE"
[ ! -f "$TAR_EXCLUDES_FILE" ] && printf "/var/cache\n"   > "$TAR_EXCLUDES_FILE"
[ ! -f "$BUILD_CMD_FILE" ]    && echo "./mesa-build.py --apt-auto 1 --incremental 0 --git-pull 1 --llvm=off --gallium-drivers=radeonsi,r600 --vulkan-drivers=amd --buildopencl 0" > "$BUILD_CMD_FILE"

# ── Terminal detection ─────────────────────────────────────────────────
TERM_BIN="xterm"
for t in xfce4-terminal gnome-terminal mate-terminal xterm; do
    command -v "$t" &>/dev/null && TERM_BIN="$t" && break
done

#========================================================================
# UTILITIES
#========================================================================

run_in_term() {
    local title="$1" cmd="$2"
    # Tmpscript to avoid quoting issues in complex commands
    local tmpscript
    tmpscript=$(mktemp /tmp/hyb-term-XXXX.sh)
    printf '#!/bin/bash\n%s\necho\nread -rp "[Press Enter to close]"\nrm -f "%s"\n' \
        "$cmd" "$tmpscript" > "$tmpscript"
    chmod +x "$tmpscript"
    case "$TERM_BIN" in
        xfce4-terminal) xfce4-terminal --title="$title" -e "bash $tmpscript" ;;
        gnome-terminal) gnome-terminal --title="$title" -- bash "$tmpscript" ;;
        mate-terminal)  mate-terminal  --title="$title" -e "bash $tmpscript" ;;
        *)              xterm -title "$title" -e bash "$tmpscript" ;;
    esac
}
export -f run_in_term

run_sudo_in_term() {
    local title="$1" cmd="$2"
    case "$TERM_BIN" in
        xfce4-terminal) xfce4-terminal --title="$title" -e "bash -c 'sudo bash -c \"$cmd\"; echo; read -rp \"[Entrée pour fermer]\"; exit'" ;;
        gnome-terminal) gnome-terminal --title="$title" -- bash -c "sudo bash -c \"$cmd\"; echo; read -rp '[Press Enter to close]'; exit" ;;
        mate-terminal)  mate-terminal  --title="$title" -e "bash -c 'sudo bash -c \"$cmd\"; echo; read -rp \"[Entrée pour fermer]\"; exit'" ;;
        *)              xterm -title "$title" -e bash -c "sudo bash -c \"$cmd\"; echo; read -rp '[Press Enter to close]'; exit" ;;
    esac
}
export -f run_sudo_in_term

yad_err() {
    yad --center --borders=10 --window-icon="dialog-error" \
        --title="Error" --image="dialog-error" \
        --text="$1" --button="OK:0" --width=420
}
export -f yad_err

yad_info() {
    yad --center --borders=10 --window-icon="dialog-information" \
        --title="Information" --image="dialog-information" \
        --text="$1" --button="OK:0" --width=500
}
export -f yad_info

yad_confirm() {
    yad --center --borders=10 --window-icon="dialog-question" \
        --title="Confirmation" --image="dialog-question" \
        --text="$1" --button="No:1" --button="Yes:0" --width=500
}
export -f yad_confirm

export KEY LOGO TERM_BIN CONF_DIR
export TAR_EXCLUDES_FILE TAR_NAME_FILE TAR_CMD_FILE
export IMG_PATH_FILE EXT_SRC_FILE EXT_DST_FILE BUILD_CMD_FILE

#========================================================================
# UNIFIED COLOR PALETTE
#========================================================================
C_TITRE='#4FC3F7'      # PS4 blue — main titles
C_SECTION='#90A4AE'    # Slate grey — section separators
C_OK='#81C784'         # Green — success / available
C_WARN='#FFB74D'       # Orange — warning
C_ERR='#EF9A9A'        # Soft red — error
C_KERNEL='#C5E1A5'     # Light green — kernel
C_MESA='#FFCC80'       # Light orange — Mesa
C_SYS='#CE93D8'        # Purple — system/storage
C_HUB='#80CBC4'        # Cyan — hub/community
C_GOLD='#FFD54F'       # Gold — credits
export C_TITRE C_SECTION C_OK C_WARN C_ERR C_KERNEL C_MESA C_SYS C_HUB C_GOLD

#========================================================================
# PERSISTENT CONFIGURATION
#========================================================================
PS4_CONF="$CONF_DIR/config.conf"
# Default values if missing
if [ ! -f "$PS4_CONF" ]; then
    cat > "$PS4_CONF" << 'CONFEOF'
# Hybryde PS4 Tools — persistent configuration
PS4_IP=192.168.1.xxx
PS4_FW=11.00
MESA_SRC_DIR=~/mesa-git
LIBDRM_SRC_DIR=~/libdrm-git
NOTIFY_ENABLED=yes
LOG_ENABLED=yes
CONFEOF
fi
# Load config (ignore errors)
# shellcheck source=/dev/null
source "$PS4_CONF" 2>/dev/null || true
export PS4_CONF PS4_IP PS4_FW NOTIFY_ENABLED LOG_ENABLED

#========================================================================
# CENTRALIZED LOGS
#========================================================================
LOG_DIR="$HOME/.cache/hybryde/ps4tools"
LOG_FILE="$LOG_DIR/ps4-tools.log"
mkdir -p "$LOG_DIR"
export LOG_DIR LOG_FILE

log_entry() {
    # log_entry "MODULE" "message"
    [ "${LOG_ENABLED:-yes}" = "no" ] && return
    local module="$1" msg="$2"
    printf '[%s] [%-14s] %s\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" "$module" "$msg" \
        >> "$LOG_FILE" 2>/dev/null
}
export -f log_entry

do_show_logs() {
    if [ ! -f "$LOG_FILE" ] || [ ! -s "$LOG_FILE" ]; then
        yad_info "📋 No logs available yet.\n\n<small><tt>$LOG_FILE</tt></small>"
        return
    fi
    # Show the last 500 lines in yad --text-info
    local tmplog
    tmplog=$(mktemp /tmp/hyb-log-XXXX.txt)
    tail -500 "$LOG_FILE" > "$tmplog"
    yad --center --borders=10 \
        --title="📋 PS4 Tools Logs" \
        --text-info --filename="$tmplog" \
        --width=900 --height=540 \
        --button="🗑 Clear logs:2" \
        --button="📂 Open file:3" \
        --button="Close:1"
    local ret=$?
    rm -f "$tmplog"
    case $ret in
        2) > "$LOG_FILE"
           log_entry "LOGS" "Log cleared by user"
           yad_info "✓ Logs cleared." ;;
        3) xdg-open "$LOG_FILE" & ;;
    esac
}
export -f do_show_logs

do_open_settings() {
    local out
    out=$(yad --center --borders=10 --title="⚙  PS4 Tools Preferences" \
        --form \
        --text="<big><b><span foreground='${C_TITRE}'>⚙  Préférences</span></b></big>\n<small>Saved in <tt>$PS4_CONF</tt></small>\n" \
        --field="PS4 IP address:":TEXT         "${PS4_IP:-192.168.1.xxx}" \
        --field="PS4 Firmware:":TEXT                 "${PS4_FW:-11.00}" \
        --field="Mesa source directory:":DIR           "${MESA_SRC_DIR:-$HOME/mesa-git}" \
        --field="libdrm source directory:":DIR         "${LIBDRM_SRC_DIR:-$HOME/libdrm-git}" \
        --field="System notifications (notify-send):":CHK "${NOTIFY_ENABLED:-yes}" \
        --field="Logging (logs):":CHK          "${LOG_ENABLED:-yes}" \
        --button="Cancel:1" --button="💾 Save:0" \
        --width=560)
    [ $? -ne 0 ] || [ -z "$out" ] && return
    IFS='|' read -r _ip _fw _mesa _libdrm _notif _logs <<< "$out"
    cat > "$PS4_CONF" << CONFEOF
# Hybryde PS4 Tools — persistent configuration
PS4_IP=${_ip}
PS4_FW=${_fw}
MESA_SRC_DIR=${_mesa}
LIBDRM_SRC_DIR=${_libdrm}
NOTIFY_ENABLED=$( [ "$_notif" = "TRUE" ] && echo yes || echo no )
LOG_ENABLED=$( [ "$_logs"  = "TRUE" ] && echo yes || echo no )
CONFEOF
    source "$PS4_CONF" 2>/dev/null || true
    export PS4_IP PS4_FW MESA_SRC_DIR LIBDRM_SRC_DIR NOTIFY_ENABLED LOG_ENABLED
    log_entry "CONFIG" "Preferences saved (IP=$_ip FW=$_fw)"
    yad_info "✓ Preferences saved."
}
export -f do_open_settings

#========================================================================
# SYSTEM NOTIFICATIONS
#========================================================================
notify_ps4() {
    # notify_ps4 "Title" "Message" ["ok"|"warn"|"err"]
    [ "${NOTIFY_ENABLED:-yes}" = "no" ] && return
    command -v notify-send >/dev/null 2>&1 || return
    local title="$1" msg="$2" level="${3:-ok}"
    local icon
    case "$level" in
        ok)   icon="emblem-default" ;;
        warn) icon="dialog-warning" ;;
        err)  icon="dialog-error" ;;
        *)    icon="dialog-information" ;;
    esac
    notify-send --icon="$icon" --app-name="PS4 Tools" \
        "PS4 Tools — $title" "$msg" 2>/dev/null &
}
export -f notify_ps4

#========================================================================
# GLOBAL DEPENDENCY CHECK
#========================================================================
DEPS_STATUS_FILE="$LOG_DIR/deps-status.txt"
export DEPS_STATUS_FILE

do_check_deps_full() {
    # Generates $DEPS_STATUS_FILE and returns a readable summary
    local ok=() warn=() fail=()
    _chk() {
        local label="$1" cmd="${2:-$1}" pkg="${3:-$1}"
        if command -v "$cmd" >/dev/null 2>&1; then
            ok+=("$label")
        else
            fail+=("$label (sudo apt install $pkg)")
        fi
    }
    _chk "curl"         curl        curl
    _chk "wget"         wget        wget
    _chk "git"          git         git
    _chk "python3"      python3     python3
    _chk "yad"          yad         yad
    _chk "clang"        clang       clang
    _chk "lld"          ld.lld      lld
    _chk "llvm-ar"      llvm-ar     llvm
    _chk "make"         make        make
    _chk "rsync"        rsync       rsync
    _chk "nmap"         nmap        nmap
    _chk "filezilla"    filezilla   filezilla
    _chk "cryptsetup"   cryptsetup  cryptsetup
    _chk "notify-send"  notify-send libnotify-bin
    _chk "glxinfo"      glxinfo     mesa-utils
    _chk "vulkaninfo"   vulkaninfo  vulkan-tools

    {
        echo "CHECKED=$(date '+%Y-%m-%d %H:%M:%S')"
        printf 'OK=%s\n'   "${#ok[@]}"
        printf 'FAIL=%s\n' "${#fail[@]}"
        for f in "${fail[@]}"; do echo "MISSING=$f"; done
    } > "$DEPS_STATUS_FILE"

    # Dialog de rapport
    local report_ok report_fail
    report_ok=$(printf '  <span foreground="%s">✓</span>  %s\n' "$C_OK" "${ok[@]}" 2>/dev/null | paste -sd'\n' || printf '%s\n' "${ok[@]}" | sed "s/^/  ✓  /")
    report_fail=$(printf '%s\n' "${fail[@]}" | sed "s/^/  ✗  /")

    local txt="<b>Dependencies checked — $(date '+%H:%M')</b>\n\n"
    txt+="<b><span foreground='${C_OK}'>✓ Available (${#ok[@]})</span></b>\n"
    for x in "${ok[@]}";   do txt+="  <span foreground='${C_OK}'>✓</span>  $x\n"; done
    txt+="\n"
    if [ ${#fail[@]} -gt 0 ]; then
        txt+="<b><span foreground='${C_ERR}'>✗ Missing (${#fail[@]})</span></b>\n"
        for x in "${fail[@]}"; do txt+="  <span foreground='${C_ERR}'>✗</span>  $x\n"; done
    else
        txt+="<span foreground='${C_OK}'><b>✓ All dependencies are present!</b></span>\n"
    fi

    yad --center --borders=10 \
        --title="Dependency check" \
        --text="$txt" \
        --image="dialog-information" \
        --button="OK:0" --width=560

    log_entry "DEPS" "Check: ${#ok[@]} OK, ${#fail[@]} missinges"
}
export -f do_check_deps_full

# Silent check at startup (generates DEPS_STATUS_FILE in background)
{
    ok=0; fail=0
    for cmd in curl wget git python3 yad clang ld.lld llvm-ar make rsync cryptsetup; do
        command -v "$cmd" >/dev/null 2>&1 && ((ok++)) || ((fail++))
    done
    echo "CHECKED=$(date '+%Y-%m-%d %H:%M:%S')" > "$DEPS_STATUS_FILE"
    echo "OK=$ok"   >> "$DEPS_STATUS_FILE"
    echo "FAIL=$fail" >> "$DEPS_STATUS_FILE"
} &

#========================================================================
# TAB 1 — Compile Mesa
#========================================================================

do_edit_script() {
    command -v geany &>/dev/null || {
        yad_err "Geany is not installed.\n<b>sudo apt install geany</b>"
        return
    }
    local script
    script=$(yad --center --borders=10 \
        --title="Select a script to edit" \
        --file --filename="$HOME/" \
        --file-filter="Scripts | *.sh *.py *.bash *.pl" \
        --button="Cancel:1" --button="Open in Geany:0" \
        --width=860 --height=540)
    [ $? -ne 0 ] || [ -z "$script" ] && return
    [ ! -f "$script" ] && yad_err "Fichier introuvable." && return
    geany "$script" &
}
export -f do_edit_script

do_patch_mesa() {
    local mesa_dir="$HOME/mesa-git"
    [ ! -d "$mesa_dir" ] && yad_err "Folder not found: <tt>$mesa_dir</tt>\nVérifiez que les sources Mesa sont clonées." && return

    local patch
    patch=$(yad --center --borders=10 \
        --title="Select Mesa patch" \
        --file --filename="$mesa_dir/" \
        --file-filter="Patches | *.patch *.diff" \
        --button="Cancel:1" --button="Select:0" \
        --width=860 --height=540)
    [ $? -ne 0 ] || [ -z "$patch" ] && return
    [ ! -f "$patch" ] && yad_err "Fichier patch introuvable." && return

    local pname drylog
    pname=$(basename "$patch")
    drylog="$CONF_DIR/mesa-dryrun.log"

    run_in_term "Dry-run Mesa — $pname" \
        "cd '$mesa_dir' && patch -p1 --dry-run < '$patch' 2>&1 | tee '$drylog'; echo; echo '=== Dry-run complete ==='; read -rp '[Press Enter to continue]'"

    yad_confirm "Dry-run terminé.\nLog : <tt>$drylog</tt>\n\nAppliquer le patch <b>$pname</b> au dépôt Mesa ?" || return
    run_in_term "Appliquer patch Mesa — $pname" \
        "cd '$mesa_dir' && patch -p1 < '$patch'"
}
export -f do_patch_mesa

do_patch_libdrm() {
    local drm_dir="$HOME/libdrm-git"
    [ ! -d "$drm_dir" ] && yad_err "Folder not found: <tt>$drm_dir</tt>\nVérifiez que les sources libdrm sont clonées." && return

    local patch
    patch=$(yad --center --borders=10 \
        --title="Select libdrm patch" \
        --file --filename="$drm_dir/" \
        --file-filter="Patches | *.patch *.diff" \
        --button="Cancel:1" --button="Select:0" \
        --width=860 --height=540)
    [ $? -ne 0 ] || [ -z "$patch" ] && return
    [ ! -f "$patch" ] && yad_err "Fichier patch introuvable." && return

    local pname drylog
    pname=$(basename "$patch")
    drylog="$CONF_DIR/libdrm-dryrun.log"

    run_in_term "Dry-run libdrm — $pname" \
        "cd '$drm_dir' && patch -p1 --dry-run < '$patch' 2>&1 | tee '$drylog'; echo; echo '=== Dry-run complete ==='; read -rp '[Press Enter to continue]'"

    yad_confirm "Dry-run terminé.\nLog : <tt>$drylog</tt>\n\nAppliquer le patch <b>$pname</b> au dépôt libdrm ?" || return
    run_in_term "Appliquer patch libdrm — $pname" \
        "cd '$drm_dir' && patch -p1 < '$patch'"
}
export -f do_patch_libdrm

do_build_mesa() {
    local build_script="$HOME/mesa-build.py"
    [ ! -f "$build_script" ] && yad_err "Script introuvable : <tt>$build_script</tt>" && return
    run_in_term "Build Mesa" "cd '$HOME' && python3 '$HOME/mesa-build.py'"
}
export -f do_build_mesa


do_get_mesa_build_baryluk() {
    local dest="$HOME/mesa-build.py"
    local gist_url="https://gist.github.com/baryluk/1041204eff4cc4fad6f1508afe67b562"
    local raw_url="https://gist.githubusercontent.com/baryluk/1041204eff4cc4fad6f1508afe67b562/raw/mesa-build.py"

    # Si le fichier existe déjà, proposer de mettre à jour ou d'annuler
    if [ -f "$dest" ]; then
        yad_confirm "mesa-build.py already exists:\n<tt>$dest</tt>\n\nUpdate from baryluk's gist?" || return
    fi

    if ! command -v curl >/dev/null 2>&1; then
        yad_err "curl is required.\n<b>sudo apt install curl</b>"
        return
    fi

    local tmpscript
    tmpscript=$(mktemp /tmp/hyb-baryluk-XXXX.sh)
    cat > "$tmpscript" << BEOF
#!/bin/bash
echo '=== Downloading mesa-build.py (baryluk) ==='
echo "Source  : $raw_url"
echo "Cible   : $dest"
echo ''

curl -L --progress-bar "$raw_url" -o "$dest"
if [ \$? -ne 0 ] || [ ! -s "$dest" ]; then
    echo ''
    echo '✗ Download failed'
    echo "  Check your connection or open manually:"
    echo "  $gist_url"
    rm -f "$dest"
    read -rp '[Press Enter to close]'
    exit 1
fi

chmod +x "$dest"
echo ''
echo "✓ mesa-build.py téléloaded et rendu exécutable"
echo "  Emplacement : $dest"
echo ''
echo '--- Script beginning (first 10 lines) ---'
head -10 "$dest"
echo '...'
echo ''
echo "Utilisation : cd ~/mesa-git && python3 $dest [options]"
echo ''
read -rp '[Press Enter to close]'
BEOF
    chmod +x "$tmpscript"
    case "$TERM_BIN" in
        xfce4-terminal) xfce4-terminal --title="🔧 mesa-build.py (baryluk)" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
        gnome-terminal) gnome-terminal --title="🔧 mesa-build.py (baryluk)" -- bash -c "$tmpscript; rm -f $tmpscript" ;;
        mate-terminal)  mate-terminal  --title="🔧 mesa-build.py (baryluk)" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
        *)              xterm -title "🔧 mesa-build.py (baryluk)" -e bash -c "$tmpscript; rm -f $tmpscript" ;;
    esac

    sleep 1
    [ -f "$dest" ] && \
        yad_info "✓ mesa-build.py installed:\n<tt>$dest</tt>\n\n<small>Original gist: $gist_url</small>"
}
export -f do_get_mesa_build_baryluk
do_manual_build() {
    local last_cmd
    last_cmd=$(cat "$BUILD_CMD_FILE" 2>/dev/null)
    [ -z "$last_cmd" ] && last_cmd="./mesa-build.py"

    local out
    out=$(yad --center --borders=10 \
        --title="Manual Mesa command" \
        --form \
        --text="<b>Commande de build Mesa</b>\n\nLe répertoire de travail sera : <tt>~/mesa-git</tt>\nModifiez la commande puis cliquez sur Lancer.\n" \
        --field="Command:":TEXT "$last_cmd" \
        --button="Cancel:1" --button="🚀 Launch:0" \
        --width=840 --height=220)
    [ $? -ne 0 ] || [ -z "$out" ] && return

    local cmd
    cmd=$(echo "$out" | cut -d'|' -f1)
    echo "$cmd" > "$BUILD_CMD_FILE"
    run_in_term "Build Mesa (manuel)" "cd '$HOME' && $cmd"
}
export -f do_manual_build

tab_mesa() { : ; }   # stub — integrated in tab_mesa_dev

#========================================================================
# TAB 1 — Dashboard
#========================================================================

tab_dashboard() {
    # ── Statuses computed at launch time ────────────────────────────
    # Compiled kernel
    local k_status k_label
    k_label=$(ls -t "$KERNELS_DIR"/linux-ps4-*/arch/x86/boot/bzImage 2>/dev/null | head -1)
    if [ -n "$k_label" ]; then
        k_status="<span foreground='${C_OK}'>✓ $(basename "$(dirname "$(dirname "$(dirname "$k_label")")")")</span>"
    elif ls -t "$KERNELS_DIR"/*/arch/x86/boot/bzImage 2>/dev/null | head -1 | grep -q .; then
        k_status="<span foreground='${C_OK}'>✓ bzImage found</span>"
    else
        k_status="<span foreground='${C_WARN}'>— no compiled kernel</span>"
    fi

    # Mesa
    local mesa_status
    if command -v glxinfo >/dev/null 2>&1; then
        local mv; mv=$(glxinfo 2>/dev/null | awk '/OpenGL version/{print $4}' | head -1)
        [ -n "$mv" ] && mesa_status="<span foreground='${C_OK}'>✓ Mesa $mv</span>" \
                     || mesa_status="<span foreground='${C_WARN}'>Mesa installed (glxinfo)</span>"
    else
        mesa_status="<span foreground='${C_SECTION}'>— glxinfo unavailable</span>"
    fi

    # PROJECT-PS4 disk space
    local disk_status
    if [ -d "$PROJECT_DIR" ]; then
        local avail used
        avail=$(df -h "$PROJECT_DIR" 2>/dev/null | awk 'NR==2{print $4}')
        used=$(df -h  "$PROJECT_DIR" 2>/dev/null | awk 'NR==2{print $3}')
        disk_status="<span foreground='${C_OK}'>✓ $used utilisés — $avail libres</span>"
    else
        disk_status="<span foreground='${C_WARN}'>$PROJECT_DIR not created</span>"
    fi

    # PS4 reachable (quick ping)
    local net_status
    if [[ "${PS4_IP:-}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        if ping -c1 -W1 "$PS4_IP" >/dev/null 2>&1; then
            net_status="<span foreground='${C_OK}'>✓ PS4 reachable — $PS4_IP</span>"
        else
            net_status="<span foreground='${C_ERR}'>✗ PS4 offline — $PS4_IP</span>"
        fi
    else
        net_status="<span foreground='${C_SECTION}'>— IP not configured (Preferences)</span>"
    fi

    # PS4 SSD mounted
    local ssd_status
    if mount 2>/dev/null | grep -q "ps4hdd"; then
        ssd_status="<span foreground='${C_OK}'>✓ PS4 SSD mounted at /ps4hdd</span>"
    else
        ssd_status="<span foreground='${C_SECTION}'>— PS4 SSD not mounted</span>"
    fi

    # Dependencies (result of silent startup check)
    local dep_ok dep_fail dep_status
    dep_ok=$(  grep  '^OK='   "$DEPS_STATUS_FILE" 2>/dev/null | cut -d= -f2)
    dep_fail=$(grep  '^FAIL=' "$DEPS_STATUS_FILE" 2>/dev/null | cut -d= -f2)
    if [ "${dep_fail:-0}" -gt 0 ] 2>/dev/null; then
        dep_status="<span foreground='${C_WARN}'>⚠  $dep_fail missing out of $(( ${dep_ok:-0} + ${dep_fail:-0} ))</span>"
    else
        dep_status="<span foreground='${C_OK}'>✓ All present (${dep_ok:-?})</span>"
    fi

    yad --plug="$KEY" --tabnum=1 \
        --form --scroll \
        --image="$LOGO" --image-on-top \
        --text="<big><b><span foreground='${C_TITRE}'>🏠 Dashboard</span></b></big>
<small>Hybryde PS4 Tools v2.0 — $(date '+%d/%m/%Y %H:%M')</small>\n" \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ System status ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</span></b>":LBL "" \
        --field="  🐧 Kernel     : $k_status":LBL "" \
        --field="  🔧 Mesa       : $mesa_status":LBL "" \
        --field="  💽 SSD PS4   : $ssd_status":LBL "" \
        --field="  🌐 Réseau     : $net_status":LBL "" \
        --field="  💾 Stockage   : $disk_status":LBL "" \
        --field="  📦 Dépendances: $dep_status":LBL "" \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ Quick actions ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</span></b>":LBL "" \
        --field="  🚀 Compile kernel (Full LTO Jaguar)":BTN       'bash -c "do_kernel_compile_lto"' \
        --field="  🔧 Compile Mesa (mesa-build.py)":BTN              'bash -c "do_build_mesa"' \
        --field="  🎮 Ps4-Linux-Warez (triki1) download manager":BTN  'bash -c "do_warez_dl_manager"' \
        --field="  ⬇  DionKill download manager":BTN  'bash -c "do_dl_manager"' \
        --field="  📡 Deploy via FTP → PS4 (/data/linux/boot/)":BTN 'bash -c "do_ftp_transfer"' \
        --field="  💾 Prepare a PS4 boot USB drive":BTN           'bash -c "do_prepare_usb"' \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ Tools &amp; Preferences ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</span></b>":LBL "" \
        --field="  ✅ Check dependencies (full detail)":BTN 'bash -c "do_check_deps_full"' \
        --field="  📋 View PS4 Tools logs":BTN                   'bash -c "do_show_logs"' \
        --field="  ⚙  Preferences (PS4 IP, paths, notifications)":BTN 'bash -c "do_open_settings"' \
        --field="  📂 Open PROJECT-PS4/":BTN                        'bash -c "do_open_project_dir"' \
        \
        --field="":LBL "" \
        --field="  <small><tt>Projet  : $PROJECT_DIR</tt></small>":LBL "" \
        --field="  <small><tt>Kernels : $KERNELS_DIR</tt></small>":LBL "" \
        --field="  <small><tt>Logs    : $LOG_FILE</tt></small>":LBL "" \
        \
        "" "" "" "" "" "" "" "" "" "" "" "" \
        &
}

#========================================================================
# TAB 2 — Create tar.xz (do_tar_* functions unchanged)
#========================================================================

do_tar_set_name() {
    local cur
    cur=$(cat "$TAR_NAME_FILE" 2>/dev/null || echo "ps4linux.tar.xz")
    local out
    out=$(yad --center --borders=10 \
        --title="tar.xz name" \
        --form \
        --text="Enter the tar.xz file name:" \
        --field="File name:":TEXT "$cur" \
        --button="Cancel:1" --button="Confirm:0" \
        --width=520)
    [ $? -ne 0 ] || [ -z "$out" ] && return
    local name
    name=$(echo "$out" | cut -d'|' -f1)
    echo "$name" > "$TAR_NAME_FILE"
    yad_info "✓ Name set: <b>$name</b>\nEmplacement final : <tt>/$name</tt>"
}
export -f do_tar_set_name

do_tar_add_exclude() {
    local out
    out=$(yad --center --borders=10 \
        --title="Add exclusion" \
        --form \
        --text="Entrez un chemin à exclure du tar.xz :\n(ex: <tt>/var/cache</tt>  <tt>/proc</tt>  <tt>/tmp</tt>)" \
        --field="Path to exclude:":TEXT "/var/cache" \
        --button="Cancel:1" --button="Add:0" \
        --width=540)
    [ $? -ne 0 ] || [ -z "$out" ] && return
    local entry
    entry=$(echo "$out" | cut -d'|' -f1)
    [ -z "$entry" ] && return
    echo "$entry" >> "$TAR_EXCLUDES_FILE"
    yad_info "✓ Exclusion added: <tt>$entry</tt>"
}
export -f do_tar_add_exclude

do_tar_del_exclude() {
    [ ! -f "$TAR_EXCLUDES_FILE" ] && yad_info "The exclusion list is empty." && return
    local items=()
    while IFS= read -r line; do
        [ -n "$line" ] && items+=("$line")
    done < "$TAR_EXCLUDES_FILE"
    [ "${#items[@]}" -eq 0 ] && yad_info "The exclusion list is empty." && return

    local sel
    sel=$(yad --center --borders=10 \
        --title="Remove exclusion" \
        --list \
        --text="Select the entry to remove:" \
        --column="Chemin à exclure" \
        "${items[@]}" \
        --print-column=1 --separator="" \
        --button="Cancel:1" --button="Delete:0" \
        --width=520 --height=360)
    [ $? -ne 0 ] || [ -z "$sel" ] && return
    local escaped="${sel//\//\\/}"
    sed -i "/^${escaped}$/d" "$TAR_EXCLUDES_FILE"
    yad_info "✓ Removed: <tt>$sel</tt>"
}
export -f do_tar_del_exclude

do_tar_show_excludes() {
    local content
    content=$(cat "$TAR_EXCLUDES_FILE" 2>/dev/null || echo "(empty list)")
    yad --center --borders=10 \
        --title="Current exclusions" \
        --text-info \
        --width=540 --height=340 \
        --button="Close:0" \
        <<< "$content"
}
export -f do_tar_show_excludes

do_tar_generate() {
    local tarname
    tarname=$(cat "$TAR_NAME_FILE" 2>/dev/null || echo "ps4linux.tar.xz")

    local excludes="--exclude=/$tarname"
    if [ -f "$TAR_EXCLUDES_FILE" ]; then
        while IFS= read -r line; do
            [ -n "$line" ] && excludes+=" --exclude=$line"
        done < "$TAR_EXCLUDES_FILE"
    fi

    local cmd="sudo tar -cvf /$tarname $excludes --one-file-system / -I \"xz -9\""
    echo "$cmd" > "$TAR_CMD_FILE"

    yad_info "<b>Generated command:</b>\n\n<tt>$cmd</tt>\n\n📦 Final file: <tt>/$tarname</tt>\n\nClick <b>🚀 Start creation</b> to execute."
}
export -f do_tar_generate

do_tar_run() {
    [ ! -f "$TAR_CMD_FILE" ] && yad_err "No commande générée.\nCliquez d'abord sur <b>Générer la commande</b>." && return
    local cmd tarname
    cmd=$(cat "$TAR_CMD_FILE")
    tarname=$(cat "$TAR_NAME_FILE" 2>/dev/null || echo "ps4linux.tar.xz")

    yad_confirm "Lancer la création de l'archive ?\n\n<tt>$cmd</tt>\n\n📦 Résultat : <tt>/$tarname</tt>\n\n⚠️  Cette opération peut prendre <b>plusieurs heures</b>." || return
    run_in_term "Création tar.xz PS4" "$cmd"
}
export -f do_tar_run

tab_tar_create() { : ; }   # stub — content integrated in tab_systeme

#========================================================================
# TAB 3 — Create .img

IMG_SRC_PART_FILE="$CONF_DIR/img-src-partition.txt"
IMG_DST_DIR_FILE="$CONF_DIR/img-dst-dir.txt"
IMG_NAME_FILE2="$CONF_DIR/img-name.txt"
export IMG_SRC_PART_FILE IMG_DST_DIR_FILE IMG_NAME_FILE2

do_img_select_partition() {
    local parts=()
    while IFS= read -r line; do
        local dev size fstype mountpoint
        dev=$(echo "$line"        | awk '{print $1}')
        size=$(echo "$line"       | awk '{print $2}')
        fstype=$(echo "$line"     | awk '{print $3}')
        mountpoint=$(echo "$line" | awk '{print $4}')
        [ -z "$dev" ] && continue
        parts+=("/dev/$dev" "${size}  |  ${fstype:-—}  |  ${mountpoint:-—}")
    done < <(lsblk -ln -o NAME,SIZE,FSTYPE,MOUNTPOINT 2>/dev/null \
             | awk 'NF>=1 {print}' \
             | grep -v "^loop")

    if [ "${#parts[@]}" -eq 0 ]; then
        yad_err "No partition détectée.\nVérifiez que le disque est connecté (<tt>lsblk</tt>)."
        return
    fi

    local sel
    sel=$(yad --center --borders=10 \
        --title="Select source partition" \
        --list \
        --text="<b>Sélectionnez la partition à sauvegarder en .img</b>\n\n⚠️  Idéalement, la partition ne doit <b>pas être montée</b> pour une image cohérente." \
        --column="Partition" \
        --column="Size  |  FS  |  Mount point" \
        "${parts[@]}" \
        --print-column=1 --separator="" \
        --button="Cancel:1" --button="Select:0" \
        --width=700 --height=440)
    [ $? -ne 0 ] || [ -z "$sel" ] && return
    sel="${sel//|/}"
    echo "$sel" > "$IMG_SRC_PART_FILE"
    yad_info "✓ Source partition selected:\n<tt>$sel</tt>"
}
export -f do_img_select_partition

do_img_select_dst() {
    local d
    d=$(yad --center --borders=10 \
        --title="Select destination folder" \
        --file --directory --filename="$HOME/" \
        --button="Cancel:1" --button="Select:0" \
        --width=860 --height=540)
    [ $? -ne 0 ] || [ -z "$d" ] && return
    echo "$d" > "$IMG_DST_DIR_FILE"
    yad_info "✓ Destination folder:\n<tt>$d</tt>"
}
export -f do_img_select_dst

do_img_set_name() {
    local cur
    cur=$(cat "$IMG_NAME_FILE2" 2>/dev/null || echo "ps4linux-partition.img")
    local out
    out=$(yad --center --borders=10 \
        --title="Image file name" \
        --form \
        --text="Enter the image file name to create:" \
        --field="Image file name:":TEXT "$cur" \
        --button="Cancel:1" --button="Confirm:0" \
        --width=520)
    [ $? -ne 0 ] || [ -z "$out" ] && return
    local name
    name=$(echo "$out" | cut -d'|' -f1)
    echo "$name" > "$IMG_NAME_FILE2"
    yad_info "✓ Name set: <b>$name</b>"
}
export -f do_img_set_name

do_img_show_sel() {
    local src dst name
    src=$(cat "$IMG_SRC_PART_FILE" 2>/dev/null || echo "— non sélectionné —")
    dst=$(cat "$IMG_DST_DIR_FILE"  2>/dev/null || echo "— non sélectionné —")
    name=$(cat "$IMG_NAME_FILE2"   2>/dev/null || echo "ps4linux-partition.img")
    yad_info "<b>Sélection actuelle :</b>\n\n  💽 Partition source : <tt>$src</tt>\n  📂 Dossier dest.    : <tt>$dst</tt>\n  📄 Nom du fichier   : <b>$name</b>\n\n🗂 Fichier final : <tt>$dst/$name</tt>"
}
export -f do_img_show_sel

do_img_create() {
    local src dst name
    src=$(cat "$IMG_SRC_PART_FILE" 2>/dev/null)
    dst=$(cat "$IMG_DST_DIR_FILE"  2>/dev/null)
    name=$(cat "$IMG_NAME_FILE2"   2>/dev/null || echo "ps4linux-partition.img")

    [ -z "$src" ] && yad_err "No partition source sélectionnée.\nCliquez sur <b>① Sélectionner la partition</b>." && return
    [ ! -b "$src" ] && yad_err "Block device not found:\n<tt>$src</tt>\nMake sure the disk is connected." && return
    [ -z "$dst" ] && yad_err "No dossier de destination sélectionné.\nCliquez sur <b>② Sélectionner le dossier</b>." && return
    [ ! -d "$dst" ] && yad_err "Folder not found:\n<tt>$dst</tt>" && return

    local imgpath="$dst/$name"

    local part_size_human part_size_bytes avail_bytes space_warn=""
    part_size_human=$(lsblk -no SIZE "$src" 2>/dev/null | head -1 | tr -d ' ')
    part_size_bytes=$(lsblk -bno SIZE "$src" 2>/dev/null | head -1 | tr -d ' ')
    avail_bytes=$(df -B1 --output=avail "$dst" 2>/dev/null | tail -1 | tr -d ' ')

    if [ -n "$part_size_bytes" ] && [ -n "$avail_bytes" ]; then
        if [ "$avail_bytes" -lt "$part_size_bytes" ]; then
            local avail_human
            avail_human=$(df -h --output=avail "$dst" 2>/dev/null | tail -1 | tr -d ' ')
            space_warn="\n\n⚠️  <b>Espace insuffisant !</b>\n  Requis     : $part_size_human\n  Available: $avail_human"
        fi
    fi

    local cmd="sudo dd if='$src' of='$imgpath' bs=4M status=progress conv=fsync"

    yad_confirm "Créer l'image complète de la partition ?\n\n  💽 Source  : <tt>$src</tt>  ($part_size_human)\n  📄 Image   : <tt>$imgpath</tt>\n\nCommande :\n<tt>$cmd</tt>${space_warn}\n\n⏱  Cette opération peut prendre plusieurs minutes." || return

    echo "$imgpath" > "$IMG_PATH_FILE"
    run_sudo_in_term "Partition backup → .img" \
        "dd if='$src' of='$imgpath' bs=4M status=progress conv=fsync && echo '' && echo '✓ Image créée :' && ls -lh '$imgpath' || echo '✗ Erreur dd'"
}
export -f do_img_create

do_img_show_path() {
    local p
    p=$(cat "$IMG_PATH_FILE" 2>/dev/null)
    if [ -n "$p" ]; then
        local info
        info=$(ls -lh "$p" 2>/dev/null || echo "(file not found)")
        yad_info "Last .img created:\n\n<tt>$p</tt>\n\n$info"
    else
        yad_info "No .img created yet."
    fi
}
export -f do_img_show_path

tab_img_create() { : ; }   # stub — integrated in tab_systeme

#========================================================================
# TAB 4 — Extract tar.xz

do_ext_select_src() {
    local f
    f=$(yad --center --borders=10 \
        --title="Select tar.xz archive" \
        --file --filename="$HOME/" \
        --file-filter="Archives tar.xz | *.tar.xz *.tar" \
        --button="Cancel:1" --button="Select:0" \
        --width=860 --height=540)
    [ $? -ne 0 ] || [ -z "$f" ] && return
    echo "$f" > "$EXT_SRC_FILE"
    yad_info "✓ Archive selected:\n<tt>$f</tt>"
}
export -f do_ext_select_src

do_ext_select_dst() {
    local d
    d=$(yad --center --borders=10 \
        --title="Select destination partition" \
        --file --directory --filename="/media/$USER/" \
        --button="Cancel:1" --button="Select:0" \
        --width=860 --height=540)
    [ $? -ne 0 ] || [ -z "$d" ] && return
    echo "$d" > "$EXT_DST_FILE"
    yad_info "✓ Destination selected:\n<tt>$d</tt>"
}
export -f do_ext_select_dst

do_ext_show_sel() {
    local src dst
    src=$(cat "$EXT_SRC_FILE" 2>/dev/null || echo "— non sélectionné —")
    dst=$(cat "$EXT_DST_FILE" 2>/dev/null || echo "— non sélectionné —")
    yad_info "<b>Sélection actuelle :</b>\n\n  📁 Archive      : <tt>$src</tt>\n  📂 Destination  : <tt>$dst</tt>"
}
export -f do_ext_show_sel

do_ext_run() {
    local src dst
    src=$(cat "$EXT_SRC_FILE" 2>/dev/null)
    dst=$(cat "$EXT_DST_FILE" 2>/dev/null)

    [ -z "$src" ] && yad_err "No archive sélectionnée.\nCliquez sur <b>① Sélectionner l'archive</b>." && return
    [ ! -f "$src" ] && yad_err "File not found:\n<tt>$src</tt>" && return
    [ -z "$dst" ] && yad_err "No destination sélectionnée.\nCliquez sur <b>② Sélectionner la partition</b>." && return

    local cmd="sudo tar -xvJpf '$src' -C '$dst' --numeric-owner"

    yad_confirm "Lancer l'extraction ?\n\n  📁 Archive     : <tt>$(basename "$src")</tt>\n  📂 Destination : <tt>$dst</tt>\n\n<tt>$cmd</tt>\n\n⚠️  Cette opération peut prendre un long moment." || return

    run_in_term "Décompression tar.xz PS4" "$cmd"
}
export -f do_ext_run

tab_tar_extract() { : ; }   # stub — integrated in tab_systeme

#========================================================================
# TAB 5 — Mount PS4 SSD (SIMPLE VERSION)

PS4_KEY="/key/eap_hdd_key.bin"
PS4_DEV="/dev/sda27"
PS4_MNT="/ps4hdd"

# ── Belize / Aeolia mount ────────────────────────────────────────────
do_mount_ps4_belize() {
    xterm -hold -e bash -c "
echo '--- Mounting PS4 Belize / Aeolia ---'
echo ''
echo '--- cryptsetup ---'
sudo cryptsetup -d /key/eap_hdd_key.bin --cipher aes-xts-plain64 -s 256 --offset 0 --skip 111669149696 create ps4hdd /dev/sd?27
sudo mount -t ufs -o ufstype=ufs2 /dev/mapper/ps4hdd /ps4hdd
sudo chmod -R a+rwX /ps4hdd

echo ''
echo 'OK → SSD mounted at $PS4_MNT'
cd /ps4hdd
ls 
read -p 'Press Enter... You can close this terminal. Use your file manager in /ps4hdd'
"
}

# ── Baikal mount ─────────────────────────────────────────────────────
do_mount_ps4_baikal() {
    xterm -hold -e bash -c "
echo '--- Mounting PS4 Baikal ---'
echo ''
echo '--- cryptsetup ---'
sudo cryptsetup -d $PS4_KEY --cipher aes-xts-plain64 -s 256 --offset 0 create ps4hdd $PS4_DEV
sudo mount -t ufs -o ufstype=ufs2 /dev/mapper/ps4hdd $PS4_MNT
sudo chmod -R a+rwX $PS4_MNT

echo ''
echo 'OK → SSD mounted at $PS4_MNT'
cd /ps4hdd
ls 
read -p 'Press Enter... You can close this terminal. Use your file manager in /ps4hdd'
"
}

# ── Unmount ──────────────────────────────────────────────────────────
do_unmount_ps4() {
    xterm -hold -e bash -c "
echo '--- Unmounting PS4 SSD ---'
echo ''

sudo umount $PS4_MNT 2>/dev/null
sudo cryptsetup remove ps4hdd 2>/dev/null

echo 'OK → unmounted'
read -p 'Press Enter...'
"
}

# ── YAD interface ────────────────────────────────────────────────────
tab_mount_ps4() { : ; }   # stub — integrated in tab_systeme (doublon supprimé)

export -f do_mount_ps4_belize
export -f do_mount_ps4_baikal
export -f do_unmount_ps4
export -f tab_mount_ps4

#========================================================================
# TAB 2 — System & Storage (archives + img + SSD + network)
#========================================================================

tab_systeme() {
    local tar_name
    tar_name=$(cat "$TAR_NAME_FILE" 2>/dev/null || echo "ps4linux.tar.xz")
    local tar_src
    tar_src=$(cat "$EXT_SRC_FILE"  2>/dev/null || echo "— non sélectionné —")
    local tar_dst
    tar_dst=$(cat "$EXT_DST_FILE"  2>/dev/null || echo "— non sélectionné —")

    yad --plug="$KEY" --tabnum=2 \
        --form --scroll \
        --image="/usr/share/hybryde/SquareGlass/WinZip 1.png" --image-on-top \
        --text="<big><b><span foreground='${C_SYS}'>💿 System &amp; Storage</span></b></big>
<span foreground='${C_SECTION}'>tar.xz archives  ·  .img images  ·  PS4 SSD  ·  Network &amp; SSH</span>\n" \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ 📦 Create tar.xz ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</span></b>":LBL "" \
        --field="  <small>Commande : <tt>sudo tar -cvf /[nom] --exclude=... --one-file-system / -I \"xz -9\"</tt></small>":LBL "" \
        --field="  Current name: <b>$tar_name</b>  →  Edit":BTN 'bash -c "do_tar_set_name"' \
        --field="  Add exclusion (--exclude)":BTN            'bash -c "do_tar_add_exclude"' \
        --field="  Remove exclusion":BTN                      'bash -c "do_tar_del_exclude"' \
        --field="  View current exclusions":BTN                'bash -c "do_tar_show_excludes"' \
        --field="  Generate final command":BTN                   'bash -c "do_tar_generate"' \
        --field="  🚀 Start tar.xz creation":BTN             'bash -c "do_tar_run"' \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ 📂 Extract tar.xz ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</span></b>":LBL "" \
        --field="  <small>Commande : <tt>sudo tar -xvJpf [archive] -C [partition] --numeric-owner</tt></small>":LBL "" \
        --field="  Archive: <small>$tar_src</small>":LBL "" \
        --field="  Dest:    <small>$tar_dst</small>":LBL "" \
        --field="  ① Select tar.xz archive":BTN             'bash -c "do_ext_select_src"' \
        --field="  ② Select destination partition":BTN  'bash -c "do_ext_select_dst"' \
        --field="  🚀 Start extraction":BTN                      'bash -c "do_ext_run"' \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ 💿 Create .img image (dd) ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</span></b>":LBL "" \
        --field="  <small>Commande : <tt>sudo dd if=[partition] of=[fichier.img] bs=4M status=progress conv=fsync</tt></small>":LBL "" \
        --field="  ① Select partition to back up":BTN  'bash -c "do_img_select_partition"' \
        --field="  ② Select destination folder":BTN   'bash -c "do_img_select_dst"' \
        --field="  ③ Edit .img file name":BTN          'bash -c "do_img_set_name"' \
        --field="  View current selection":BTN                  'bash -c "do_img_show_sel"' \
        --field="  🚀 Create .img image (dd)":BTN                 'bash -c "do_img_create"' \
        --field="  View last .img created":BTN                   'bash -c "do_img_show_path"' \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ 🔌 PS4 SSD ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</span></b>":LBL "" \
        --field="  Clé : <tt>$PS4_KEY</tt>  ·  Partition : <tt>$PS4_DEV</tt>  ·  Point : <tt>$PS4_MNT</tt>":LBL "" \
        --field="  🚀 Mount PS4 SSD (Belize / Aeolia)":BTN        'bash -c "do_mount_ps4_belize"' \
        --field="  🚀 Mount PS4 SSD (Baikal)":BTN                 'bash -c "do_mount_ps4_baikal"' \
        --field="  ⏏  Unmount PS4 SSD":BTN                        'bash -c "do_unmount_ps4"' \
        --field="  💽 cryptsetup status + mount + lsblk":BTN         'bash -c "do_cryptsetup_status"' \
        --field="  📁 Copy a folder to /ps4hdd (rsync)":BTN  'bash -c "do_rsync_to_ps4hdd"' \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ 🌐 Network &amp; SSH ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</span></b>":LBL "" \
        --field="  🔍 Scan local network (nmap)":BTN           'bash -c "do_net_scan"' \
        --field="  🖥  SSH connection to PS4":BTN               'bash -c "do_ssh_ps4"' \
        --field="  📂 FTP connection to PS4 (FileZilla)":BTN    'bash -c "do_ftp_ps4"' \
        \
        "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" \
        &
}

#========================================================================
# TAB 6 — Help (10 configurable documents)
#
# FIX v1.1: old --list + --dclick-action approach opened
# a yad file selector (Thunar) instead of the PDF.
# New approach: --form with BTN per document → direct call to
# preview_pdf (preview) or xdg-open (default reader).
# Paths are expanded at plug generation time (not in a subshell)
# so no variable scope issues.
#
# ─── Edit names and paths here ──────────────────────────────────────
#========================================================================

AIDE_LABELS=(
    "Create a Multiboot SSD"      # button 1
    "Active Zram"             # button 2
    "TRANSFORM YOUR PS4 INTO A WII" # button 3
    "A developer in your terminal" # button 4
    "CUSTOM BASH"             # button 5
    "Update mesa"             # button 6
    "Doc PS4 Linux 7"             # button 7
    "Doc PS4 Linux 8"             # button 8
    "Doc PS4 Linux 9"             # button 9
    "Doc PS4 Linux 10"            # button 10
)

AIDE_PATHS=(
    "$HOME/Documents/Create a Multiboot SSD2.pdf"   # 1
    "$HOME/Documents/zram-forky-trixie-kali-fat-2G.txt"   # 2
    "$HOME/Documents/TRANSFORM YOUR PS4 INTO A WII.pdf"   # 3
    "$HOME/Documents/A developer in your terminal.pdf"   # 4
    "$HOME/Documents/CUSTOM BASH.pdf"   # 5
    "$HOME/Documents/Mettre a jour Les Distributions TRIKI1.pdf"   # 6
    "$HOME/Documents/MOUNT-hdd-intern-ps4.pdf"   # 7
    "$HOME/Documents/MOUNT-hdd-intern-ps4.pdf"   # 8
    "$HOME/Documents/MOUNT-hdd-intern-ps4.pdf"   # 9
    "$HOME/Documents/MOUNT-hdd-intern-ps4.pdf"   # 10
)
# ──────────────────────────────────────────────────────────────────────

tab_aide() { : ; }   # stub — integrated in tab_hub

#========================================================================
# TAB 7 — Network / Transfer

do_net_scan() {
    local tmpscript
    tmpscript=$(mktemp /tmp/hyb-netscan-XXXX.sh)
    cat > "$tmpscript" << 'EOF'
#!/bin/bash
echo "=== Scan réseau local (nmap -sn) ==="
echo ""
if ! command -v nmap >/dev/null 2>&1; then
    echo "ERREUR : nmap non installé"
    echo "  sudo apt install nmap"
    read -rp "[Press Enter to close]"
    exit 1
fi
IFACE=$(ip route | awk '/^default/ {print $5; exit}')
SUBNET=$(ip route | awk -v ifc="$IFACE" '$0 ~ "scope link" && $0 ~ ("dev "ifc" ") {print $1; exit}')
if [ -z "$SUBNET" ]; then
    SUBNET=$(ip route | awk '/scope link/ {print $1}' | head -1)
fi
echo "Default interface : $IFACE"
echo "Detected subnet    : $SUBNET"
echo ""
echo "(ARP scan via sudo : more reliable for detecting WiFi devices like the PS4)"
echo ""
if [ "$(id -u)" -eq 0 ]; then
    nmap -sn "$SUBNET" 2>/dev/null | grep -E "Nmap scan|Host is up|report for|MAC Address"
else
    sudo nmap -sn "$SUBNET" 2>/dev/null | grep -E "Nmap scan|Host is up|report for|MAC Address"
fi
echo ""
read -rp "[Press Enter to close]"
EOF
    chmod +x "$tmpscript"
    case "$TERM_BIN" in
        xfce4-terminal) xfce4-terminal --title="Network scan" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
        gnome-terminal) gnome-terminal --title="Network scan" -- bash -c "$tmpscript; rm -f $tmpscript" ;;
        mate-terminal)  mate-terminal  --title="Network scan" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
        *)              xterm -title "Network scan" -e bash -c "$tmpscript; rm -f $tmpscript" ;;
    esac
}
export -f do_net_scan

do_rsync_to_ps4hdd() {
    local src
    src=$(yad --center --borders=10 \
        --title="Select source folder to copy" \
        --file --directory --filename="$HOME/" \
        --button="Cancel:1" --button="Select:0" \
        --width=860 --height=540)
    [ $? -ne 0 ] || [ -z "$src" ] && return

    local dst
    dst=$(yad --center --borders=10 \
        --title="Destination on /ps4hdd" \
        --form \
        --text="Destination folder on /ps4hdd:" \
        --field="Destination path:":TEXT "/ps4hdd/game/" \
        --button="Cancel:1" --button="Confirm:0" \
        --width=540)
    [ $? -ne 0 ] || [ -z "$dst" ] && return
    dst=$(echo "$dst" | cut -d'|' -f1)

    yad_confirm "Lancer le transfert rsync ?\n\n  Source : <tt>$src</tt>\n  Dest   : <tt>$dst</tt>\n\n⚠️  Peut prendre plusieurs minutes selon la taille." || return

    local tmpscript
    tmpscript=$(mktemp /tmp/hyb-rsync-XXXX.sh)
    printf '#!/bin/bash\nrsync -av --progress "%s" "%s"\necho ""\nread -rp "[Press Enter to close]"\n' "$src" "$dst" > "$tmpscript"
    chmod +x "$tmpscript"
    case "$TERM_BIN" in
        xfce4-terminal) xfce4-terminal --title="rsync to ps4hdd" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
        gnome-terminal) gnome-terminal --title="rsync to ps4hdd" -- bash -c "$tmpscript; rm -f $tmpscript" ;;
        mate-terminal)  mate-terminal  --title="rsync to ps4hdd" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
        *)              xterm -title "rsync to ps4hdd" -e bash -c "$tmpscript; rm -f $tmpscript" ;;
    esac
}
export -f do_rsync_to_ps4hdd

do_ssh_ps4() {
    local out
    out=$(yad --center --borders=10 \
        --title="SSH to PS4" \
        --form \
        --text="<b>SSH connection to PS4</b>" \
        --field="PS4 IP address:":TEXT "192.168.1.xxx" \
        --field="User:":TEXT "root" \
        --field="SSH port:":NUM "22!1..65535!1" \
        --button="Cancel:1" --button="Connect:0" \
        --width=460)
    [ $? -ne 0 ] || [ -z "$out" ] && return
    local ip user port
    ip=$(echo "$out"   | cut -d'|' -f1)
    user=$(echo "$out" | cut -d'|' -f2)
    port=$(echo "$out" | cut -d'|' -f3)

    local tmpscript
    tmpscript=$(mktemp /tmp/hyb-ssh-XXXX.sh)
    printf '#!/bin/bash\necho "Connexion SSH : %s@%s:%s"\nssh -p "%s" "%s@%s"\nread -rp "[Press Enter to close]"\n' \
        "$user" "$ip" "$port" "$port" "$user" "$ip" > "$tmpscript"
    chmod +x "$tmpscript"
    case "$TERM_BIN" in
        xfce4-terminal) xfce4-terminal --title="SSH PS4 — $ip" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
        gnome-terminal) gnome-terminal --title="SSH PS4 — $ip" -- bash -c "$tmpscript; rm -f $tmpscript" ;;
        mate-terminal)  mate-terminal  --title="SSH PS4 — $ip" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
        *)              xterm -title "SSH PS4 — $ip" -e bash -c "$tmpscript; rm -f $tmpscript" ;;
    esac
}
export -f do_ssh_ps4

do_ftp_ps4() {
    if [ -z "${PS4_IP:-}" ] || [ "$PS4_IP" = "192.168.1.xxx" ]; then
        yad_info "⚠ No PS4 IP address configured.\n\nOpen <b>⚙ Preferences</b> and set your PS4's IP address before connecting via FTP."
        return
    fi
    if ! command -v filezilla >/dev/null 2>&1; then
        yad_info "⚠ FileZilla is not installed.\n\n  sudo apt install filezilla"
        return
    fi
    local out
    out=$(yad --center --borders=10 \
        --title="FTP connection to PS4" \
        --form \
        --text="<b>FTP connection to the PS4</b>\n<small>IP saved in preferences: $PS4_IP\nLeave user blank for anonymous login (typical PS4 homebrew FTP servers)</small>" \
        --field="PS4 IP address:":TEXT       "$PS4_IP" \
        --field="User (optional):":TEXT      "" \
        --field="FTP port:":NUM              "2121!1..65535!1" \
        --button="Cancel:1" --button="📂 Open FileZilla:0" \
        --width=460)
    [ $? -ne 0 ] || [ -z "$out" ] && return
    local ip user port ftp_uri
    ip=$(echo "$out"   | cut -d'|' -f1)
    user=$(echo "$out" | cut -d'|' -f2)
    port=$(echo "$out" | cut -d'|' -f3)

    if [ -n "$user" ]; then
        ftp_uri="ftp://${user}@${ip}:${port}"
    else
        ftp_uri="ftp://${ip}:${port}"
    fi

    log_entry "FTP" "Opening FileZilla to ${ftp_uri}"
    filezilla "$ftp_uri" &
}
export -f do_ftp_ps4

tab_reseau() { : ; }   # stub — integrated in tab_systeme

#========================================================================
# TAB 8 — Diagnostics / Logs

do_diag_prereqs() {
    local tmpscript
    tmpscript=$(mktemp /tmp/hyb-prereqs-XXXX.sh)
    cat > "$tmpscript" << 'EOF'
#!/bin/bash
ok()   { printf "  \e[32m✓\e[0m %-28s %s\n" "$1" "$2"; }
warn() { printf "  \e[33m⚠\e[0m  %-28s %s\n" "$1" "$2"; }
fail() { printf "  \e[31m✗\e[0m %-28s %s\n" "$1" "$2"; }

chk() {
    local pkg="$1" cmd="${2:-$1}" label="${3:-$1}"
    if command -v "$cmd" >/dev/null 2>&1; then
        ok "$label" "($(command -v "$cmd"))"
    else
        fail "$label" "→ sudo apt install $pkg"
    fi
}

echo "=== Prérequis PS4 Linux ==="
echo ""
chk cryptsetup    cryptsetup    "cryptsetup"
chk ufsutils      ufs_util      "ufsutils (ufs_util)"
chk rsync         rsync         "rsync"
chk nmap          nmap          "nmap"
chk filezilla     filezilla     "filezilla"
chk mesa-vulkan-drivers vulkaninfo "vulkan (vulkaninfo)"
chk git           git           "git"
chk python3       python3       "python3"
chk clang         clang         "clang (LTO kernel)"
chk lld           ld.lld        "lld (linker LTO)"
chk llvm          llvm-ar       "llvm-ar"
chk make          make          "make"

echo ""
echo "=== Vulkan ==="
if command -v vulkaninfo >/dev/null 2>&1; then
    vulkaninfo --summary 2>/dev/null | grep -E "deviceName|driverVersion|apiVersion" | head -6
else
    warn "vulkaninfo" "unavailable"
fi

echo ""
echo "=== Driver GPU actif ==="
lspci -k 2>/dev/null | grep -A2 "VGA" | head -6

echo ""
echo "=== Mesa version ==="
if command -v glxinfo >/dev/null 2>&1; then
    glxinfo 2>/dev/null | grep -i "OpenGL version\|renderer" | head -3
else
    warn "glxinfo" "unavailable (sudo apt install mesa-utils)"
fi

echo ""
read -rp "[Press Enter to close]"
EOF
    chmod +x "$tmpscript"
    case "$TERM_BIN" in
        xfce4-terminal) xfce4-terminal --title="Prerequisites diagnostic" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
        gnome-terminal) gnome-terminal --title="Prerequisites diagnostic" -- bash -c "$tmpscript; rm -f $tmpscript" ;;
        mate-terminal)  mate-terminal  --title="Prerequisites diagnostic" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
        *)              xterm -title "Diagnostic Prérequis" -e bash -c "$tmpscript; rm -f $tmpscript" ;;
    esac
}
export -f do_diag_prereqs

do_dmesg_live() {
    local tmpscript
    tmpscript=$(mktemp /tmp/hyb-dmesg-XXXX.sh)
    cat > "$tmpscript" << 'EOF'
#!/bin/bash
echo "=== dmesg temps réel — filtre USB/SCSI/DRM/amdgpu ==="
echo "Ctrl+C pour arrêter"
echo ""
sudo dmesg -w 2>/dev/null | grep --line-buffered -iE "usb|scsi|sd[a-z]|drm|amdgpu|radeon|cryptsetup|ufs|ps4"
EOF
    chmod +x "$tmpscript"
    case "$TERM_BIN" in
        xfce4-terminal) xfce4-terminal --title="dmesg live" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
        gnome-terminal) gnome-terminal --title="dmesg live" -- bash -c "$tmpscript; rm -f $tmpscript" ;;
        mate-terminal)  mate-terminal  --title="dmesg live" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
        *)              xterm -title "dmesg live" -e bash -c "$tmpscript; rm -f $tmpscript" ;;
    esac
}
export -f do_dmesg_live

do_cryptsetup_status() {
    local tmpscript
    tmpscript=$(mktemp /tmp/hyb-cstatus-XXXX.sh)
    cat > "$tmpscript" << 'EOF'
#!/bin/bash
echo "=== cryptsetup status ps4hdd ==="
echo ""
sudo cryptsetup status ps4hdd 2>/dev/null || echo "(mapping ps4hdd inactif)"
echo ""
echo "=== mount | grep ps4 ==="
mount 2>/dev/null | grep -E "ps4|ufs" || echo "(rien monté)"
echo ""
echo "=== lsblk ==="
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT 2>/dev/null
echo ""
read -rp "[Press Enter to close]"
EOF
    chmod +x "$tmpscript"
    case "$TERM_BIN" in
        xfce4-terminal) xfce4-terminal --title="PS4 SSD status" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
        gnome-terminal) gnome-terminal --title="PS4 SSD status" -- bash -c "$tmpscript; rm -f $tmpscript" ;;
        mate-terminal)  mate-terminal  --title="PS4 SSD status" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
        *)              xterm -title "État SSD PS4" -e bash -c "$tmpscript; rm -f $tmpscript" ;;
    esac
}
export -f do_cryptsetup_status

tab_diagnostic() { : ; }   # stub — integrated in tab_mesa_dev

#========================================================================
# TAB 9 — Mesa environment variables

MESA_ENV_FILE="$CONF_DIR/mesa-env.conf"
MESA_PROFILES_DIR="$CONF_DIR/mesa-profiles"
mkdir -p "$MESA_PROFILES_DIR"
export MESA_ENV_FILE MESA_PROFILES_DIR

# Default profile if absent
[ ! -f "$MESA_ENV_FILE" ] && cat > "$MESA_ENV_FILE" << 'ENVEOF'
RADV_DEBUG=
MESA_DEBUG=
AMD_DEBUG=
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/radeon_icd.x86_64.json
mesa_glthread=true
RADV_PERFTEST=
ENVEOF

do_mesa_edit_env() {
    local out
    # Read the current file
    source "$MESA_ENV_FILE" 2>/dev/null

    out=$(yad --center --borders=10 \
        --title="Mesa variables" \
        --form \
        --text="<b>Variables d'environnement Mesa/Vulkan</b>\n<small>Laisser vide = non exporté</small>\n" \
        --field="RADV_DEBUG :":TEXT "${RADV_DEBUG:-}" \
        --field="MESA_DEBUG :":TEXT "${MESA_DEBUG:-}" \
        --field="AMD_DEBUG :":TEXT "${AMD_DEBUG:-}" \
        --field="VK_ICD_FILENAMES :":TEXT "${VK_ICD_FILENAMES:-/usr/share/vulkan/icd.d/radeon_icd.x86_64.json}" \
        --field="mesa_glthread :":CBX "true!false" \
        --field="RADV_PERFTEST :":TEXT "${RADV_PERFTEST:-}" \
        --button="Cancel:1" --button="Save:0" \
        --width=660)
    [ $? -ne 0 ] || [ -z "$out" ] && return

    IFS='|' read -r v_radv v_mesa v_amd v_vk v_glthread v_perf <<< "$out"
    cat > "$MESA_ENV_FILE" << SAVEOF
RADV_DEBUG=$v_radv
MESA_DEBUG=$v_mesa
AMD_DEBUG=$v_amd
VK_ICD_FILENAMES=$v_vk
mesa_glthread=$v_glthread
RADV_PERFTEST=$v_perf
SAVEOF
    yad_info "✓ Variables saved to:\n<tt>$MESA_ENV_FILE</tt>"
}
export -f do_mesa_edit_env

do_mesa_save_profile() {
    local out
    out=$(yad --center --borders=10 \
        --title="Save profile" \
        --form \
        --text="Mesa profile name to save:" \
        --field="Name:":TEXT "profil-debug" \
        --button="Cancel:1" --button="Save:0" \
        --width=400)
    [ $? -ne 0 ] || [ -z "$out" ] && return
    local name; name=$(echo "$out" | cut -d'|' -f1 | tr ' ' '-')
    cp "$MESA_ENV_FILE" "$MESA_PROFILES_DIR/$name.conf"
    yad_info "✓ Profile saved: <b>$name</b>\n<tt>$MESA_PROFILES_DIR/$name.conf</tt>"
}
export -f do_mesa_save_profile

do_mesa_load_profile() {
    local profiles=()
    for f in "$MESA_PROFILES_DIR"/*.conf; do
        [ -f "$f" ] && profiles+=("$(basename "$f" .conf)")
    done
    [ "${#profiles[@]}" -eq 0 ] && yad_info "No saved profiles." && return

    local sel
    sel=$(yad --center --borders=10 \
        --title="Load Mesa profile" \
        --list \
        --text="Select the profile to load:" \
        --column="Profil" \
        "${profiles[@]}" \
        --print-column=1 --separator="" \
        --button="Cancel:1" --button="Load:0" \
        --width=400 --height=300)
    [ $? -ne 0 ] || [ -z "$sel" ] && return
    sel="${sel//|/}"
    cp "$MESA_PROFILES_DIR/$sel.conf" "$MESA_ENV_FILE"
    yad_info "✓ Profile loaded: <b>$sel</b>"
}
export -f do_mesa_load_profile

do_mesa_launch_app() {
    local app
    app=$(yad --center --borders=10 \
        --title="Launch app with Mesa variables" \
        --file --filename="$HOME/" \
        --button="Cancel:1" --button="Launch:0" \
        --width=860 --height=540)
    [ $? -ne 0 ] || [ -z "$app" ] && return
    [ ! -f "$app" ] && yad_err "Fichier introuvable." && return

    local tmpscript
    tmpscript=$(mktemp /tmp/hyb-mesa-launch-XXXX.sh)
    {
        echo "#!/bin/bash"
        echo "echo '=== Active Mesa variables ==='"
        # Export each non-empty variable
        while IFS='=' read -r key val; do
            [[ "$key" =~ ^# ]] && continue
            [ -z "$key" ] && continue
            if [ -n "$val" ]; then
                echo "export ${key}=${val}"
                echo "echo \"  ${key}=${val}\""
            fi
        done < "$MESA_ENV_FILE"
        echo "echo ''"
        echo "echo '=== Launching: $app ==='"
        echo "\"$app\""
        echo "read -rp '[Press Enter to close]'"
    } > "$tmpscript"
    chmod +x "$tmpscript"

    case "$TERM_BIN" in
        xfce4-terminal) xfce4-terminal --title="Mesa Launch" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
        gnome-terminal) gnome-terminal --title="Mesa Launch" -- bash -c "$tmpscript; rm -f $tmpscript" ;;
        mate-terminal)  mate-terminal  --title="Mesa Launch" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
        *)              xterm -title "Mesa Launch" -e bash -c "$tmpscript; rm -f $tmpscript" ;;
    esac
}
export -f do_mesa_launch_app

do_mesa_show_current() {
    local content
    content=$(cat "$MESA_ENV_FILE" 2>/dev/null || echo "(no variables defined)")
    yad --center --borders=10 \
        --title="Current Mesa variables" \
        --text-info --width=560 --height=300 \
        --button="Close:0" \
        <<< "$content"
}
export -f do_mesa_show_current

tab_mesa_env() { : ; }   # stub — integrated in tab_mesa_dev

#========================================================================
# TAB 3 — Mesa & Dev
#========================================================================

tab_mesa_dev() {
    yad --plug="$KEY" --tabnum=3 \
        --form --scroll \
        --image="/usr/share/hybryde/SquareGlass/Download Manager.png" --image-on-top \
        --text="<big><b><span foreground='${C_MESA}'>🔧 Mesa &amp; Dev</span></b></big>
<span foreground='${C_SECTION}'>Mesa / libdrm compilation  ·  Environment variables  ·  Diagnostics</span>\n" \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ 🔧 Compile Mesa (AMD Liverpool / Gladius) ━━━━━━━━━━━━━━━</span></b>":LBL "" \
        --field="  <small>Sources : <tt>~/mesa-git</tt>  et  <tt>~/libdrm-git</tt></small>":LBL "" \
        --field="  Open a script in Geany":BTN              'bash -c "do_edit_script"' \
        --field="  Apply a Mesa .patch":BTN                 'bash -c "do_patch_mesa"' \
        --field="  Apply a libdrm .patch":BTN               'bash -c "do_patch_libdrm"' \
        --field="  🚀 Build Mesa (./mesa-build.py)":BTN          'bash -c "do_build_mesa"' \
        --field="  Manual command (editable before launch)":BTN 'bash -c "do_manual_build"' \
        --field="  ⬇  Download mesa-build.py (baryluk)":BTN  'bash -c "do_get_mesa_build_baryluk"' \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ ⚙  Mesa / Vulkan variables ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</span></b>":LBL "" \
        --field="  <small>RADV_DEBUG, MESA_DEBUG, AMD_DEBUG, mesa_glthread…</small>":LBL "" \
        --field="  ✏  Edit Mesa/Vulkan variables":BTN           'bash -c "do_mesa_edit_env"' \
        --field="  📋 Show current variables":BTN           'bash -c "do_mesa_show_current"' \
        --field="  💾 Save current profile":BTN               'bash -c "do_mesa_save_profile"' \
        --field="  📂 Load a profile":BTN                          'bash -c "do_mesa_load_profile"' \
        --field="  🚀 Launch app with active variables":BTN 'bash -c "do_mesa_launch_app"' \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ 🔍 Diagnostics ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</span></b>":LBL "" \
        --field="  ✅ Check all PS4 Linux prerequisites":BTN      'bash -c "do_diag_prereqs"' \
        --field="  ✅ Check dependencies (full detail)":BTN  'bash -c "do_check_deps_full"' \
        --field="  📋 Live dmesg (USB / DRM / amdgpu)":BTN     'bash -c "do_dmesg_live"' \
        --field="  💽 cryptsetup status + mount + lsblk":BTN         'bash -c "do_cryptsetup_status"' \
        --field="  📋 View PS4 Tools logs":BTN                   'bash -c "do_show_logs"' \
        \
        "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" \
        &
}
export -f tab_mesa_dev

# Integrated documentation — text displayed in the tab
KERNEL_DOC="<b>Kernel optimization for PS4 (Jaguar / GCN 1.1)</b>

<b>Why kernel 5.15.x &gt; 6.x on PS4?</b>
• GPU Sea Islands / GCN 1.1 (Liverpool) — aucun support officiel
• Kernel 5.15 : moins de régressions GCN 1.1, amdgpu plus léger,
  gestion clock/powerplay/fences plus stable
• Kernel 6.x : protections Spectre/Meltdown coûteuses sur Jaguar 1.6 GHz
  → <b>Heaven : 5.15.15 = 1200 pts | 6.15.4 = ~965 pts</b>

<b>menuconfig with LTO visible:</b>  <tt>make LLVM=1 menuconfig</tt>
<b>Jaguar compilation flags:</b>
<tt>-march=btver2 -mtune=btver2 -O3 -fomit-frame-pointer -flto -pipe</tt>

<b>Recommended PS4 bootargs:</b>
<small><tt>amdgpu.cik_support=1 amdgpu.si_support=1 amdgpu.dc=0
mitigations=off nopti spectre_v2=off noibpb noibrs
processor.max_cstate=1 idle=nomwait
amdgpu.lockup_timeout=10000</tt></small>

<b>Key CONFIGs:</b>
<tt>CONFIG_LTO_CLANG_FULL=y
CONFIG_DRM_AMDGPU_CIK=y
CONFIG_DRM_AMDGPU_SI=y
CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE=y</tt>

<b>Mesa Jaguar (COMPILERFLAGS line):</b>
<small><tt>-march=btver2 -mtune=btver2 -O3 -flto={nproc} -g0 -fno-semantic-interposition</tt></small>"

export KERNEL_DOC

KERNEL_SRC_FILE="$CONF_DIR/kernel-src-dir.txt"
[ ! -f "$KERNEL_SRC_FILE" ] && echo "$HOME/linux-kernel" > "$KERNEL_SRC_FILE"
export KERNEL_SRC_FILE

do_kernel_select_src() {
    local d
    d=$(yad --center --borders=10 \
        --title="Kernel source directory" \
        --file --directory --filename="$(cat "$KERNEL_SRC_FILE" 2>/dev/null || echo "$HOME/")" \
        --button="Cancel:1" --button="Select:0" \
        --width=860 --height=540)
    [ $? -ne 0 ] || [ -z "$d" ] && return
    echo "$d" > "$KERNEL_SRC_FILE"
    yad_info "✓ Kernel sources set:\n<tt>$d</tt>"
}
export -f do_kernel_select_src

do_kernel_menuconfig_standard() {
    local src
    src=$(cat "$KERNEL_SRC_FILE" 2>/dev/null || echo "$HOME/linux-kernel")
    [ ! -d "$src" ] && yad_err "Source directory not found:\n<tt>$src</tt>\nClick <b>Select sources</b>." && return

    local tmpscript
    tmpscript=$(mktemp /tmp/hyb-menuconfig-XXXX.sh)
    cat > "$tmpscript" << MEOF
#!/bin/bash
echo "=== menuconfig standard ==="
echo "Sources : $src"
echo ""
cd "$src" || exit 1
make menuconfig
echo ""
read -rp "[Press Enter to close]"
MEOF
    chmod +x "$tmpscript"
    case "$TERM_BIN" in
        xfce4-terminal) xfce4-terminal --title="menuconfig" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
        gnome-terminal) gnome-terminal --title="menuconfig" -- bash -c "$tmpscript; rm -f $tmpscript" ;;
        mate-terminal)  mate-terminal  --title="menuconfig" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
        *)              xterm -title "menuconfig" -e bash -c "$tmpscript; rm -f $tmpscript" ;;
    esac
}
export -f do_kernel_menuconfig_standard

do_kernel_menuconfig_lto() {
    local src
    src=$(cat "$KERNEL_SRC_FILE" 2>/dev/null || echo "$HOME/linux-kernel")
    [ ! -d "$src" ] && yad_err "Source directory not found:\n<tt>$src</tt>\nClick <b>Select sources</b>." && return

    # Check clang/lld
    if ! command -v clang >/dev/null 2>&1 || ! command -v ld.lld >/dev/null 2>&1; then
        yad_err "clang or lld not installed.\n<b>sudo apt install clang lld llvm</b>"
        return
    fi

    local tmpscript
    tmpscript=$(mktemp /tmp/hyb-menuconfig-lto-XXXX.sh)
    cat > "$tmpscript" << MEOF
#!/bin/bash
echo "=== menuconfig LLVM=1 (options LTO visibles) ==="
echo "Sources : $src"
echo "Compilateur : clang $(clang --version 2>/dev/null | head -1)"
echo ""
cd "$src" || exit 1
make LLVM=1 menuconfig
echo ""
read -rp "[Press Enter to close]"
MEOF
    chmod +x "$tmpscript"
    case "$TERM_BIN" in
        xfce4-terminal) xfce4-terminal --title="menuconfig LLVM/LTO" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
        gnome-terminal) gnome-terminal --title="menuconfig LLVM/LTO" -- bash -c "$tmpscript; rm -f $tmpscript" ;;
        mate-terminal)  mate-terminal  --title="menuconfig LLVM/LTO" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
        *)              xterm -title "menuconfig LLVM/LTO" -e bash -c "$tmpscript; rm -f $tmpscript" ;;
    esac
}
export -f do_kernel_menuconfig_lto

do_kernel_compile_lto() {
    local src
    src=$(cat "$KERNEL_SRC_FILE" 2>/dev/null || echo "$HOME/linux-kernel")
    [ ! -d "$src" ] && yad_err "Source directory not found:\n<tt>$src</tt>" && return

    if ! command -v clang >/dev/null 2>&1; then
        yad_err "clang non installé.\n<b>sudo apt install clang lld llvm</b>"
        return
    fi

    local jobs
    jobs=$(nproc)

    # Allow user to adjust the number of jobs
    local out
    out=$(yad --center --borders=10 \
        --title="Full LTO kernel compilation — Jaguar" \
        --form \
        --text="<b>Compilation Full LTO pour PS4 (Jaguar / btver2)</b>\n\n⚠️  <b>Consomme beaucoup de RAM</b> — prévoir 24 Go minimum pour Full LTO.\nAvec 16 Go, utiliser <b>-j2</b> ou <b>-j1</b> pour éviter le freeze.\n" \
        --field="Number of jobs (-j):":NUM "${jobs}!1..$(nproc)!1" \
        --field="Extra flags:":TEXT "" \
        --button="Cancel:1" --button="🚀 Compile:0" \
        --width=600)
    [ $? -ne 0 ] || [ -z "$out" ] && return
    local njobs extra_flags
    njobs=$(echo "$out"      | cut -d'|' -f1)
    extra_flags=$(echo "$out" | cut -d'|' -f2)

    yad_confirm "Lancer la compilation Full LTO kernel ?\n\n  Sources : <tt>$src</tt>\n  Jobs    : <b>-j${njobs}</b>\n\n⚠️  Peut durer <b>plusieurs heures</b>.\nSurveiller la RAM avec <tt>monitor-compilation.sh</tt>." || return

    local tmpscript
    tmpscript=$(mktemp /tmp/hyb-compile-kernel-XXXX.sh)
    cat > "$tmpscript" << CEOF
#!/bin/bash
cd "$src" || exit 1
echo "=== Compilation kernel Full LTO Jaguar ==="
echo "Jobs    : $njobs"
echo "Sources : $src"
echo "Début   : \$(date)"
echo ""
make -j${njobs} \\
    LLVM=1 \\
    KCFLAGS="-march=btver2 -mtune=btver2 -O3 -fomit-frame-pointer -flto -mno-sse4a -mno-xop -mno-tbm -pipe ${extra_flags}" \\
    CC=clang \\
    LD=ld.lld \\
    AR=llvm-ar \\
    NM=llvm-nm \\
    STRIP=llvm-strip \\
    OBJCOPY=llvm-objcopy \\
    OBJDUMP=llvm-objdump \\
    READELF=llvm-readelf \\
    HOSTCC=clang \\
    HOSTCXX=clang++ \\
    HOSTAR=llvm-ar \\
    HOSTLD=ld.lld
echo ""
echo "=== Fin : \$(date) ==="
echo ""
if [ -f arch/x86/boot/bzImage ]; then
    echo "OK  bzImage produit : arch/x86/boot/bzImage"
    echo "  → Copiez-le dans /boot sur votre PS4"
else
    echo "ERREUR : bzImage introuvable"
fi
echo ""
read -rp "[Press Enter to close]"
CEOF
    chmod +x "$tmpscript"
    case "$TERM_BIN" in
        xfce4-terminal) xfce4-terminal --title="Compilation Kernel LTO" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
        gnome-terminal) gnome-terminal --title="Compilation Kernel LTO" -- bash -c "$tmpscript; rm -f $tmpscript" ;;
        mate-terminal)  mate-terminal  --title="Compilation Kernel LTO" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
        *)              xterm -title "Compilation Kernel LTO" -e bash -c "$tmpscript; rm -f $tmpscript" ;;
    esac
}
export -f do_kernel_compile_lto

do_kernel_copy_bzimage() {
    local src
    src=$(cat "$KERNEL_SRC_FILE" 2>/dev/null || echo "$HOME/linux-kernel")
    local bzimage="$src/arch/x86/boot/bzImage"
    [ ! -f "$bzimage" ] && yad_err "bzImage not found:\n<tt>$bzimage</tt>\nCompile the kernel first." && return

    local dst
    dst=$(yad --center --borders=10 \
        --title="Copy bzImage" \
        --form \
        --text="Destination for bzImage copy:" \
        --field="Destination:":TEXT "/boot/bzImage-ps4-lto" \
        --button="Cancel:1" --button="Copy:0" \
        --width=520)
    [ $? -ne 0 ] || [ -z "$dst" ] && return
    dst=$(echo "$dst" | cut -d'|' -f1)

    local tmpscript
    tmpscript=$(mktemp /tmp/hyb-cpbz-XXXX.sh)
    cat > "$tmpscript" << CPEOF
#!/bin/bash
echo "Copying bzImage..."
sudo cp "$bzimage" "$dst" && echo "OK - bzImage copied: $dst" || echo "ERROR copying"
echo ""
ls -lh "$dst" 2>/dev/null
echo ""
read -rp "[Press Enter to close]"
CPEOF
    chmod +x "$tmpscript"
    case "$TERM_BIN" in
        xfce4-terminal) xfce4-terminal --title="Copie bzImage" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
        gnome-terminal) gnome-terminal --title="Copie bzImage" -- bash -c "$tmpscript; rm -f $tmpscript" ;;
        mate-terminal)  mate-terminal  --title="Copie bzImage" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
        *)              xterm -title "Copie bzImage" -e bash -c "$tmpscript; rm -f $tmpscript" ;;
    esac
}
export -f do_kernel_copy_bzimage

do_kernel_show_doc() {
    # Display full documentation as plain text in yad --text-info
    local doc_text
    doc_text="Optimisation kernel 6.15.4 — PS4 Jaguar / GCN 1.1
=======================================================================

WHY IS THE 6.x KERNEL SLOWER ON PS4?
=======================================================================
La PS4 utilise un GPU Sea Islands / GCN 1.1 (Liverpool).
No kernel Linux ne supporte officiellement ce matériel.

(1) Driver AMD (amdgpu) non adapté pour GCN1.1
    - Kernel 5.15.x : moins de régressions GCN1.1, amdgpu plus léger,
      gestion clock/powerplay/fences plus stable.
    - Kernel 6.x : modifications IRQ, memory barriers, power management,
      VM scheduler qui améliorent RDNA/Vega mais dégradent les vieux GCN.

(2) Protections sécurité (Spectre, Meltdown, Retpoline, IBPB, IBRS)
    - Coûtent des cycles sur Jaguar 1.6 GHz.
    - Kernel 5.15 en active moins → FPS plus élevés.
    - Heaven : 5.15.15 = 1200 pts | 6.15.4 = ~965 pts
    - Gain potentiel : +20 à +40 % sur certains benchmarks.

=======================================================================
MENUCONFIG WITH LTO OPTIONS VISIBLE
=======================================================================
Sans LLVM=1, les options LTO n'apparaissent pas dans menuconfig.
Commande correcte : make LLVM=1 menuconfig

=======================================================================
KEY .config OPTIONS FOR PS4 / JAGUAR
=======================================================================
CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE=y
CONFIG_LTO=y
CONFIG_LTO_CLANG=y
CONFIG_LTO_CLANG_FULL=y
CONFIG_LTO_CLANG_THIN=n
CONFIG_DRM_AMDGPU=y
CONFIG_DRM_AMDGPU_CIK=y
CONFIG_DRM_AMDGPU_SI=y
CONFIG_DRM_AMDGPU_USERPTR=y
# CONFIG_PAGE_TABLE_ISOLATION is not set
# CONFIG_MITIGATION_RETPOLINE is not set
# CONFIG_MITIGATION_SPECTRE_V1 is not set
# CONFIG_MITIGATION_SPECTRE_V2 is not set
# CONFIG_MITIGATION_SSB is not set
# CONFIG_DEBUG_INFO is not set

=======================================================================
JAGUAR COMPILATION FLAGS (btver2)
=======================================================================
KCFLAGS='-march=btver2 -mtune=btver2 -O3 -fomit-frame-pointer
         -flto -mno-sse4a -mno-xop -mno-tbm -pipe'

Commande complète :
make -j\$JOBS LLVM=1
    CC=clang LD=ld.lld AR=llvm-ar NM=llvm-nm
    STRIP=llvm-strip OBJCOPY=llvm-objcopy
    HOSTCC=clang HOSTCXX=clang++ HOSTAR=llvm-ar HOSTLD=ld.lld
    KCFLAGS='...'

=======================================================================
RECOMMENDED PS4 BOOTARGS
=======================================================================
amdgpu.gttsize=2048 amdgpu.vm_fragment_size=9 amdgpu.dc=0
amdgpu.pcie_gen2=1 amdgpu.aspm=0 amdgpu.dpm=1
amdgpu.deep_color=0 amdgpu.gpu_recovery=0
radeon.si_support=0 amdgpu.si_support=1 amdgpu.cik_support=1
mitigations=off nopti spectre_v2=off spec_store_bypass_disable=off
noibpb noibrs ibt=off processor.max_cstate=1 idle=nomwait
amdgpu.lockup_timeout=10000 drm.edid_firmware=edid/1920x1080.bin

=======================================================================
MESA JAGUAR — COMPILERFLAGS
=======================================================================
-pipe -march=btver2 -mtune=btver2 -O3 -mfpmath=sse
-ftree-vectorize -flto -flto={nproc} -g0 -fno-semantic-interposition

=======================================================================
RAM MEMORY — FULL LTO
=======================================================================
Full LTO uses a lot of RAM.
With i3 + 16 GB: use -j2 or -j1 to avoid freezing.
Scripts fournis : compile-i3-fulllto-v2.sh + monitor-compilation.sh
"

    echo "$doc_text" | yad --center --borders=10 \
        --title="PS4 Jaguar Kernel Documentation" \
        --text-info --scroll \
        --width=820 --height=620 \
        --button="Close:0"
}
export -f do_kernel_show_doc

tab_kernel() { : ; }   # stub — integrated in tab_kernel_boot

#========================================================================
# TAB 4 — Kernel & Boot
#========================================================================

tab_kernel_boot() {
    local src
    src=$(cat "$KERNEL_SRC_FILE" 2>/dev/null || echo "$HOME/linux-kernel")

    yad --plug="$KEY" --tabnum=4 \
        --form --scroll \
        --image="/usr/share/hybryde/SquareGlass/Control Panel 1.png" --image-on-top \
        --text="<big><b><span foreground='${C_KERNEL}'>🐧 PS4 Kernel &amp; Boot</span></b></big>
<span foreground='${C_SECTION}'>LTO Compilation  ·  Git Sources  ·  Initramfs  ·  Deployment  ·  Bootargs</span>
Current sources: <tt>$src</tt>\n" \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ ⚡ Kernel Compilation (Jaguar / Full LTO) ━━━━━━━━━━━━━━━━</span></b>":LBL "" \
        --field="  <small><tt>-march=btver2 -mtune=btver2 · LLVM/Clang · Full LTO</tt></small>":LBL "" \
        --field="  📂 Select kernel source directory":BTN   'bash -c "do_kernel_select_src"' \
        --field="  ⚙  Standard menuconfig  (make menuconfig)":BTN      'bash -c "do_kernel_menuconfig_standard"' \
        --field="  ⚡ LLVM/LTO menuconfig   (make LLVM=1 menuconfig)":BTN 'bash -c "do_kernel_menuconfig_lto"' \
        --field="  🚀 Compile kernel (Full LTO, -march=btver2)":BTN  'bash -c "do_kernel_compile_lto"' \
        --field="  💾 Copy bzImage to /boot (sudo)":BTN             'bash -c "do_kernel_copy_bzimage"' \
        --field="  📖 Full Jaguar / LTO / Mesa kernel guide":BTN    'bash -c "do_kernel_show_doc"' \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ 🐙 PS4 Kernel Git Sources ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</span></b>":LBL "" \
        --field="  🚀 crashniels/linux — PS4 kernel (choose branch)":BTN 'bash -c "do_git_ps4_kernel"' \
        --field="  🚀 feeRnt/ps4-linux-12xx — auto branches":BTN           'bash -c "do_git_feernt_kernel"' \
        --field="  🗂  fail0verflow/ps4-linux (original reference)":BTN   'bash -c "do_git_fail0verflow"' \
        --field="  🐙 Al-Azif — profil GitHub (payloads, outils PS4)":BTN  'bash -c "do_open_url_alazif"' \
        --field="  🎮 GoldHEN — download latest release":BTN       'bash -c "do_git_goldhen"' \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ 🔓 OpenOrbis SDK ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</span></b>":LBL "" \
        --field="  🚀 OpenOrbis PS4 Toolchain (latest release, auto)":BTN 'bash -c "do_git_orbis"' \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ 📦 Linux Payloads (ps4boot) ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</span></b>":LBL "" \
        --field="  🚀 ps4-linux-payloads — download + compile":BTN 'bash -c "do_git_payloads"' \
        --field="  📖 README GoldHEN / bzImage / initramfs":BTN         'bash -c "do_payloads_readme"' \
        --field="  ⚡ ps4-kexec — kexec payload (boot chain)":BTN  'bash -c "do_git_kexec"' \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ 🛠  Initramfs Builder ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</span></b>":LBL "" \
        --field="  🛠  Create / extract / repackage an initramfs.cpio.gz":BTN 'bash -c "do_build_initramfs"' \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ 🚀 Deployment ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</span></b>":LBL "" \
        --field="  💾 Prepare a PS4 boot USB drive":BTN            'bash -c "do_prepare_usb"' \
        --field="  📡 FTP Transfer → /data/linux/boot/ on PS4":BTN 'bash -c "do_ftp_transfer"' \
        --field="  ⚙  Edit bootargs.txt / vram.txt":BTN              'bash -c "do_edit_bootargs"' \
        --field="  📂 Open PROJECT-PS4/":BTN                         'bash -c "do_open_project_dir"' \
        \
        "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" \
        &
}
export -f tab_kernel_boot

do_git_ps4_kernel() {
    local branches=(
        "ps4-5.15.y"      # Stable PS4
        "ps4-6.1.y"       # Nouveau
        "ps4-6.6.y"       # Latest
        "master"          # Main
    )
    
    local branch
    branch=$(yad --center --borders=10 \
        --title="Download PS4 Kernel" \
        --list \
        --text="Select the PS4 branch:" \
        --column="Branch" \
        "${branches[@]}" \
        --print-column=1 --separator="" \
        --button="Cancel:1" --button="🚀 Download:0" \
        --width=400 --height=280)
    
    [ $? -ne 0 ] || [ -z "$branch" ] && return
    branch="${branch//|/}"

    local dest="$KERNELS_DIR/linux-ps4-$branch"
    [ -d "$dest" ] && yad_confirm "Dossier existant :\n<tt>$dest</tt>\n\nSupprimer et re-télécharger ?" || rm -rf "$dest"
    
    run_in_term "🚀 Git PS4 Kernel — $branch" "
        cd '$KERNELS_DIR'
        echo '=== Downloading PS4 kernel: $branch ==='
        git clone -b '$branch' --depth=1 https://github.com/crashniels/linux.git linux-ps4-$branch
        echo '=== PS4 Kernel sources downloaded ==='
        ls -la
        echo ''
        read -rp '[Press Enter to open folder]'
        sleep 1 && xdg-open '$KERNELS_DIR/linux-ps4-$branch'
    "
    
    yad_info "✓ Kernel PS4 $branch\n📂 <tt>$dest</tt>"
}
export -f do_git_ps4_kernel

#------------------------------------------------------------------------
# feeRnt/ps4-linux-12xx — alternative PS4 kernels
#------------------------------------------------------------------------
do_git_feernt_kernel() {
    # Fetch branches dynamically from GitHub API
    local branches_raw
    branches_raw=$(curl -s --max-time 8 \
        "https://api.github.com/repos/feeRnt/ps4-linux-12xx/branches" \
        2>/dev/null)

    local yad_branches=()
    if [ -n "$branches_raw" ] && echo "$branches_raw" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
        # Branches fetched from API
        while IFS= read -r b; do
            [ -n "$b" ] && yad_branches+=("$b")
        done < <(echo "$branches_raw" | python3 -c "
import sys, json
branches = json.load(sys.stdin)
# master first, then others sorted
names = [b['name'] for b in branches]
if 'master' in names:
    names.remove('master')
    names = ['master'] + sorted(names)
else:
    names = sorted(names)
for n in names:
    print(n)
" 2>/dev/null)
    fi

    # Fallback if API unreachable or empty
    if [ "${#yad_branches[@]}" -eq 0 ]; then
        yad_branches=("master" "ps4-6.1.y" "ps4-6.6.y" "ps4-5.15.y")
    fi

    local branch
    branch=$(yad --center --borders=10 \
        --title="feeRnt — ps4-linux-12xx" \
        --list \
        --text="<b>feeRnt/ps4-linux-12xx</b>\nAlternative PS4 kernels\n<small>https://github.com/feeRnt/ps4-linux-12xx</small>\n\nSelect a branch:" \
        --column="Branch" \
        "${yad_branches[@]}" \
        --print-column=1 --separator="" \
        --button="Cancel:1" --button="🚀 Download:0" \
        --width=420 --height=320)

    [ $? -ne 0 ] || [ -z "$branch" ] && return
    branch="${branch//|/}"

    local dest="$KERNELS_DIR/feeRnt-ps4-linux-$branch"

    if [ -d "$dest" ]; then
        yad_confirm "Dossier existant :\n<tt>$dest</tt>\n\nSupprimer et re-télécharger ?"
        [ $? -ne 0 ] && return
        rm -rf "$dest"
    fi

    local tmpscript
    tmpscript=$(mktemp /tmp/hyb-feernt-XXXX.sh)
    cat > "$tmpscript" << FEOF
#!/bin/bash
echo '=== Downloading feeRnt/ps4-linux-12xx ==='
echo "Branche : $branch"
echo "Destination : $dest"
echo ''
cd '$KERNELS_DIR'
git clone -b '$branch' --depth=1 \
    https://github.com/feeRnt/ps4-linux-12xx.git \
    "feeRnt-ps4-linux-$branch"

if [ \$? -ne 0 ] || [ ! -d '$dest' ]; then
    echo ''
    echo '✗ Clone failed'
    echo '  Check your connection or that the branch exists.'
    read -rp '[Press Enter to close]'
    exit 1
fi

echo ''
echo '=== Contents ==='
ls -la '$dest'
echo ''
echo "✓ feeRnt ps4-linux-12xx ($branch) téléloaded"
echo "  $dest"
echo ''
read -rp '[Press Enter to open folder]'
sleep 1 && xdg-open '$dest' 2>/dev/null
FEOF
    chmod +x "$tmpscript"
    case "$TERM_BIN" in
        xfce4-terminal) xfce4-terminal --title="🐧 feeRnt ps4-linux — $branch" -e "bash $tmpscript" ;;
        gnome-terminal) gnome-terminal --title="🐧 feeRnt ps4-linux — $branch" -- bash "$tmpscript" ;;
        mate-terminal)  mate-terminal  --title="🐧 feeRnt ps4-linux — $branch" -e "bash $tmpscript" ;;
        *)              xterm -title "🐧 feeRnt ps4-linux — $branch" -e bash "$tmpscript" ;;
    esac

    sleep 1
    [ -d "$dest" ] && \
        yad_info "✓ feeRnt/ps4-linux-12xx ($branch) téléloaded\n📂 <tt>$dest</tt>"
}
export -f do_git_feernt_kernel
do_git_orbis() {
    local out
    out=$(yad --center --borders=10 \
        --title="OpenOrbis PS4 Toolchain" \
        --form \
        --text="<b>Installer OpenOrbis Toolchain</b>\n\n<small>Télécharge la dernière release automatiquement depuis GitHub\nhttps://github.com/OpenOrbis/OpenOrbis-PS4-Toolchain</small>\n" \
        --field="Folder name:":TEXT "Orbis" \
        --button="Cancel:1" --button="🚀 Install:0" \
        --width=540)
    [ $? -ne 0 ] || [ -z "$out" ] && return

    local dest_name
    dest_name=$(echo "$out" | cut -d'|' -f1)
    dest_name="${dest_name//|/}"
    [ -z "$dest_name" ] && dest_name="Orbis"
    local dest="$PROJECT_DIR/$dest_name"

    # Direct heredoc — bypasses run_in_term to avoid issues
    # with nested variable interpretation and inline Python
    local tmpscript
    tmpscript=$(mktemp /tmp/hyb-orbis-XXXX.sh)
    cat > "$tmpscript" << ORBEOF
#!/bin/bash
set -e
cd '$PROJECT_DIR'

echo '=== Installing OpenOrbis PS4 Toolchain ==='
echo "Destination : $dest"
echo ''

echo '--- Dependencies ---'
sudo apt-get update -qq
sudo apt-get install -y clang lld make curl tar python3 2>&1 | tail -5

# libssl1.1 required by PkgTool.Core (.NET — incompatible with libssl3)
if ! dpkg -l libssl1.1 2>/dev/null | grep -q '^ii'; then
    echo '  → Installing libssl1.1 (required by PkgTool.Core)...'
    TMP_SSL=\$(mktemp /tmp/libssl1.1-XXXX.deb)
    curl -L --progress-bar \
        "http://security.debian.org/debian-security/pool/updates/main/o/openssl/libssl1.1_1.1.1w-0+deb11u5_amd64.deb" \
        -o "\$TMP_SSL"
    sudo dpkg -i "\$TMP_SSL" 2>&1 | tail -3
    rm -f "\$TMP_SSL"
fi

# DOTNET variable required for libicu78 (Forky lacks libicu66)
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
grep -q 'DOTNET_SYSTEM_GLOBALIZATION_INVARIANT' "\$HOME/.bashrc" || \
    echo 'export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1' >> "\$HOME/.bashrc"
echo '✓ Dependencies OK'
echo ''

echo '--- Fetching the latest release ---'
API_URL="https://api.github.com/repos/OpenOrbis/OpenOrbis-PS4-Toolchain/releases/latest"
JSON=\$(curl -s "\$API_URL")
if [ -z "\$JSON" ] || echo "\$JSON" | grep -q '"message".*"Not Found"'; then
    echo '✗ Unable to reach GitHub API'
    echo '  Check your internet connection'
    read -rp '[Press Enter to close]'
    exit 1
fi

VERSION=\$(echo "\$JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tag_name','?'))" 2>/dev/null)
echo "Version détectée : \$VERSION"

DOWNLOAD_URL=\$(echo "\$JSON" | python3 -c "
import sys, json
data = json.load(sys.stdin)
assets = data.get('assets', [])
# Priority 1: contains 'linux' + .tar.gz
for asset in assets:
    name = asset['name'].lower()
    if 'linux' in name and name.endswith('.tar.gz'):
        print(asset['browser_download_url']); break
else:
    # Priority 2: any .tar.gz except windows/mac/darwin/osx
    for asset in assets:
        name = asset['name'].lower()
        skip = any(x in name for x in ['windows', 'win', 'mac', 'darwin', 'osx', 'macos'])
        if name.endswith('.tar.gz') and not skip:
            print(asset['browser_download_url']); break
    else:
        # Priority 3: first available .tar.gz
        for asset in assets:
            if asset['name'].lower().endswith('.tar.gz'):
                print(asset['browser_download_url']); break
" 2>/dev/null)

if [ -z "\$DOWNLOAD_URL" ]; then
    echo '✗ No .tar.gz file found in the release'
    echo '  Available assets:'
    echo "\$JSON" | python3 -c "
import sys, json
for a in json.load(sys.stdin).get('assets',[]): print('  -', a['name'])
" 2>/dev/null
    read -rp '[Press Enter to close]'
    exit 1
fi
echo "URL : \$DOWNLOAD_URL"
echo ''

echo '--- Downloading ---'
curl -L --progress-bar "\$DOWNLOAD_URL" -o /tmp/toolchain.tar.gz
if [ ! -s /tmp/toolchain.tar.gz ]; then
    echo '✗ Download failed or empty file'
    read -rp '[Press Enter to close]'
    exit 1
fi
SIZE=\$(stat -c%s /tmp/toolchain.tar.gz)
echo "Taille : \$(numfmt --to=iec \$SIZE 2>/dev/null || echo \$SIZE bytes)"
if [ "\$SIZE" -lt 500000 ]; then
    echo '✗ File too small — probably an error'
    rm -f /tmp/toolchain.tar.gz
    read -rp '[Press Enter to close]'
    exit 1
fi
echo ''

echo '--- Extracting ---'
rm -rf '$dest'
mkdir -p '$dest'
tar -xzf /tmp/toolchain.tar.gz -C '$dest' --strip-components=1 2>&1 || \
    tar -xzf /tmp/toolchain.tar.gz -C '$dest' 2>&1
rm -f /tmp/toolchain.tar.gz
echo '✓ Extraction complete'
echo ''

echo '--- Configuring .bashrc ---'
BASHRC="\$HOME/.bashrc"
grep -q 'OO_PS4_TOOLCHAIN' "\$BASHRC" || \
    echo "export OO_PS4_TOOLCHAIN='$dest'" >> "\$BASHRC"
grep -q '$dest/bin/linux' "\$BASHRC" || \
    echo "export PATH=\"\\\$PATH:$dest/bin/linux\"" >> "\$BASHRC"
export OO_PS4_TOOLCHAIN='$dest'
export PATH="\$PATH:$dest/bin/linux"
echo '✓ Variables added to ~/.bashrc'
echo "  OO_PS4_TOOLCHAIN=$dest"
echo ''

echo '--- SDK contents ---'
ls -la '$dest'
echo ''

if [ -d '$dest/samples/hello_world' ]; then
    echo '--- Testing hello_world compilation ---'
    cd '$dest/samples/hello_world'
    make 2>&1 && echo '✓ Compilation successful 🎉' || echo '⚠ Compilation failed (ignored)'
    echo ''
fi

echo '============================================'
echo "✓ OpenOrbis \$VERSION installé dans :"
echo "  $dest"
echo ''
echo 'To use in a new terminal:'
echo '  source ~/.bashrc'
echo '============================================'
echo ''
read -rp '[Press Enter to open SDK folder]'
sleep 1 && xdg-open '$dest' 2>/dev/null
ORBEOF
    chmod +x "$tmpscript"
    case "$TERM_BIN" in
        xfce4-terminal) xfce4-terminal --title="🚀 Installation OpenOrbis" -e "bash $tmpscript" ;;
        gnome-terminal) gnome-terminal --title="🚀 Installation OpenOrbis" -- bash "$tmpscript" ;;
        mate-terminal)  mate-terminal  --title="🚀 Installation OpenOrbis" -e "bash $tmpscript" ;;
        *)              xterm -title "🚀 Installation OpenOrbis" -e bash "$tmpscript" ;;
    esac

    sleep 1
    if [ -d "$dest" ]; then
        yad_info "✓ OpenOrbis installé\n📂 <tt>$dest</tt>\n\nRechargez votre terminal ou : <tt>source ~/.bashrc</tt>"
    fi
}
export -f do_git_orbis

do_git_payloads() {
    local dest="$PROJECT_DIR/ps4-linux-payloads"

    if [ -d "$dest" ]; then
        yad_confirm "Dossier existant :\n<tt>$dest</tt>\n\nRe-télécharger depuis zéro ?"
        if [ $? -eq 0 ]; then
            rm -rf "$dest"
        else
            # Dossier déjà là → juste recompiler
            run_in_term "🔧 Compiler PS4 Linux Payloads" "
                cd '$dest/linux'
                echo '=== Compiling PS4 Linux payloads ==='
                make
                echo ''
                echo '=== Compilation complete ==='
                ls -la
                echo ''
                read -rp '[Press Enter to close]'
            "
            return
        fi
    fi

    run_in_term "🚀 Git + Compilation PS4 Linux Payloads" "
        cd '$PROJECT_DIR'
        echo '=== Downloading ps4-linux-payloads ==='
        git clone https://github.com/ps4boot/ps4-linux-payloads
        echo ''
        echo '=== Compiling with make ==='
        cd ps4-linux-payloads/linux
        make
        echo ''
        echo '=== Terminé ==='
        ls -la
        echo ''
        read -rp '[Press Enter to open folder]'
        sleep 1 && xdg-open '$dest'
    "
    yad_info "✓ PS4 Linux Payloads compilés\n📂 <tt>$dest</tt>"
}
export -f do_git_payloads

do_payloads_readme() {
    local readme_text="The host with pre-compiled Linux payloads works only with GoldHEN v2.4b18.5/v2.4b18.6 BinLoader.
Simply open your web browser and cache the host; it will also work offline.

▶️  https://ps4boot.github.io  (bouton ci-dessous pour ouvrir)

You will find Linux payloads for your firmware, as well as additional payloads.
The rest is already included in GoldHEN.

━━━  Automatic boot file placement  ━━━
The kernel (bzImage) and initramfs.cpio.gz are now automatically copied to /data/linux/boot
on the internal disk from the external FAT32 partition.
→ No external drive is needed for the recovery interface, except on first boot.

━━━  RTC time passed to initramfs  ━━━
The current OrbisOS time is added to the kernel command line (time=CURRENTTIME),
ensuring the correct time is set at boot instead of the default 1970 value,
even if the RTC hardware cannot be read directly.
A prepared initramfs is required to read the time from the command line and set it.

━━━  Default internal path  ━━━
  /data/linux/boot
The rest comes from the initramfs.cpio.gz init configuration.

Access without USB drive: transfer via FTP to your PS4:
  /data/linux/boot/bzImage
  /data/linux/boot/initramfs.cpio.gz

USB devices take priority: if a drive is connected, the system will use
bzImage and initramfs.cpio.gz from that drive.

You can add a text file (bootargs.txt) to modify the command line.
The vram.txt file lets you change the VRAM size via a text file.

━━━  Important notes  ━━━
★  With GoldHEN v2.4b18.5/v2.4b18.6, use .elf files instead of .bin files;
   this works better and ensures 100% success.

★  Do not use PRO payloads for Phat or Slim models.

★  UART (if needed) — currently disabled, does not work on recent kernels:
     Éolie / Belize : console=uart8250,mmio32,0xd0340000
     Baïkal          : console=uart8250,mmio32,0xC890E000"

    echo "$readme_text" | yad --center --borders=12 \
        --title="📖 README — PS4 Linux Payloads" \
        --text-info --scroll \
        --width=800 --height=580 \
        --button="🌐 Open ps4boot.github.io:2" \
        --button="Close:0"

    local ret=$?
    [ $ret -eq 2 ] && xdg-open "https://ps4boot.github.io" >/dev/null 2>&1 &
}
export -f do_payloads_readme

#------------------------------------------------------------------------
# 1. ps4-kexec — the kexec payload to boot Linux from the PS4
#------------------------------------------------------------------------
do_git_kexec() {
    local dest="$PROJECT_DIR/ps4-kexec"

    if [ -d "$dest" ]; then
        yad_confirm "Dossier existant :\n<tt>$dest</tt>\n\nRe-télécharger depuis zéro ?"
        if [ $? -eq 0 ]; then
            rm -rf "$dest"
        else
            run_in_term "🔧 Recompiler ps4-kexec" "
                cd '$dest'
                echo '=== Recompiling ps4-kexec ==='
                make clean 2>/dev/null; make
                echo ''
                echo '=== Produced files ==='
                ls -lh *.elf *.bin 2>/dev/null || ls -lh
                echo ''
                read -rp '[Press Enter to close]'
            "
            return
        fi
    fi

    run_in_term "🚀 Git + Compilation ps4-kexec" "
        cd '$PROJECT_DIR'
        echo '=== Downloading ps4-kexec ==='
        git clone https://github.com/ps4boot/ps4-kexec
        echo ''
        echo '=== Checking dependencies ==='
        for dep in make gcc git; do
            command -v \$dep >/dev/null 2>&1 \
                && echo \"  ✓ \$dep\" \
                || echo \"  ✗ \$dep missing — sudo apt install \$dep\"
        done
        echo ''
        echo '=== Compiling ==='
        cd ps4-kexec && make
        echo ''
        echo '=== Produced files ==='
        ls -lh *.elf *.bin 2>/dev/null || ls -lh
        echo ''
        echo 'NOTE: use the .elf with GoldHEN v2.4b18.5/v2.4b18.6 BinLoader'
        echo ''
        read -rp '[Press Enter to open folder]'
        sleep 1 && xdg-open '$dest'
    "
    yad_info "✓ ps4-kexec compilé\n📂 <tt>$dest</tt>\n\n<small>Utilisez le .elf avec GoldHEN BinLoader</small>"
}
export -f do_git_kexec

#------------------------------------------------------------------------
# 2. fail0verflow/ps4-linux — original reference fork
#------------------------------------------------------------------------
do_git_fail0verflow() {
    local dest="$KERNELS_DIR/ps4-linux-fail0verflow"

    if [ -d "$dest" ]; then
        yad_confirm "Dossier existant :\n<tt>$dest</tt>\n\nMettre à jour (git pull) ?"
        if [ $? -eq 0 ]; then
            run_in_term "🔄 Update fail0verflow/ps4-linux" "
                cd '$dest'
                echo '=== git pull ==='
                git pull
                echo ''
                echo '=== Branches availables ==='
                git branch -a | head -20
                echo ''
                read -rp '[Press Enter to close]'
            "
        fi
        return
    fi

    local branch
    branch=$(yad --center --borders=10 \
        --title="fail0verflow/ps4-linux — Branch" \
        --list \
        --text="<b>fail0verflow/ps4-linux</b>\nFork original PS4 Linux — référence historique.\nUtile pour récupérer des configs .config ou comparer des patchs.\n\nChoisissez la branche :" \
        --column="Branch" \
        --column="Description" \
        "master"    "Main branch" \
        "ps4"       "PS4-specific branch" \
        --print-column=1 --separator="" \
        --button="Cancel:1" --button="🚀 Download:0" \
        --width=500 --height=240)
    [ $? -ne 0 ] || [ -z "$branch" ] && return
    branch="${branch//|/}"

    run_in_term "🚀 Git fail0verflow/ps4-linux — $branch" "
        cd '$KERNELS_DIR'
        echo '=== Downloading fail0verflow/ps4-linux (shallow) ==='
        echo 'Large repo — this may take several minutes...'
        echo ''
        git clone -b '$branch' --depth=1 https://github.com/fail0verflow/ps4-linux ps4-linux-fail0verflow
        echo ''
        echo '=== Available .config files ==='
        find '$dest' -name '.config*' 2>/dev/null | head -10
        echo ''
        echo '=== Contents ==='
        ls -la '$dest' 2>/dev/null
        echo ''
        read -rp '[Press Enter to open folder]'
        sleep 1 && xdg-open '$dest' 2>/dev/null
    "
    yad_info "✓ fail0verflow/ps4-linux téléloaded\n📂 <tt>$dest</tt>"
}
export -f do_git_fail0verflow

#------------------------------------------------------------------------
# GoldHEN — download the latest release
#------------------------------------------------------------------------
do_git_goldhen() {
    local dest="$PROJECT_DIR/GoldHEN"

    local out
    out=$(yad --center --borders=10 \
        --title="GoldHEN — Latest release" \
        --form \
        --text="<b>Télécharger la dernière release de GoldHEN</b>\n\n<small>Source : https://github.com/GoldHEN/GoldHEN/releases\nLes fichiers seront téléloadeds dans :\n<tt>$PROJECT_DIR/GoldHEN/</tt></small>\n" \
        --field="Destination folder:":TEXT "$PROJECT_DIR/GoldHEN" \
        --button="Cancel:1" --button="🚀 Download:0" \
        --width=580)
    [ $? -ne 0 ] || [ -z "$out" ] && return

    dest=$(echo "$out" | cut -d'|' -f1)
    dest="${dest//|/}"
    [ -z "$dest" ] && dest="$PROJECT_DIR/GoldHEN"

    local tmpscript
    tmpscript=$(mktemp /tmp/hyb-goldhen-XXXX.sh)
    cat > "$tmpscript" << GHEOF
#!/bin/bash
echo '=== Downloading GoldHEN — latest release ==='
echo "Destination : $dest"
echo ''

if ! command -v curl >/dev/null 2>&1; then
    echo '✗ curl required: sudo apt install curl'
    read -rp '[Press Enter to close]'
    exit 1
fi

echo '--- Fetching release info ---'
# /releases (sans /latest) retourne TOUTES les releases y compris pre-releases
# On prend la première (la plus récente), qu'elle soit stable ou pre-release
API_URL="https://api.github.com/repos/GoldHEN/GoldHEN/releases"
JSON_ALL=\$(curl -s "\$API_URL")
if [ -z "\$JSON_ALL" ]; then
    echo '✗ Unable to reach GitHub API'
    read -rp '[Press Enter to close]'
    exit 1
fi

# Extraire la première release (index 0) — la plus récente
JSON=\$(echo "\$JSON_ALL" | python3 -c "
import sys, json
releases = json.load(sys.stdin)
if not releases:
    print('{}')
else:
    # Prendre la toute première release (pre-release ou stable)
    import json as j
    print(j.dumps(releases[0]))
" 2>/dev/null)

VERSION=\$(echo "\$JSON" | python3 -c "
import sys, json
d = json.load(sys.stdin)
pre = '(pre-release)' if d.get('prerelease') else '(stable)'
print(d.get('tag_name', '?'), pre)
" 2>/dev/null)
echo "Version : \$VERSION"
echo ''

# Lister tous les assets
echo '--- Available assets ---'
ASSETS=\$(echo "\$JSON" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for a in data.get('assets', []):
    print(a['browser_download_url'], a['name'], a.get('size', 0))
" 2>/dev/null)

if [ -z "\$ASSETS" ]; then
    echo '✗ No assets found in the release'
    read -rp '[Press Enter to close]'
    exit 1
fi

echo "\$ASSETS" | while read url name size; do
    echo "  - \$name  (\$size bytes)"
done
echo ''

echo '--- Downloading all files ---'
mkdir -p '$dest'
cd '$dest'

echo "\$ASSETS" | while read url name size; do
    echo "Téléchargement : \$name"
    curl -L --progress-bar "\$url" -o "\$name"
    if [ -s "\$name" ]; then
        echo "  ✓ \$name"
    else
        echo "  ✗ Failed: \$name"
    fi
    echo ''
done

echo ''
echo '=== GoldHEN folder contents ==='
ls -lh '$dest'
echo ''
echo "✓ GoldHEN \$VERSION téléloaded dans :"
echo "  $dest"
echo ''
read -rp '[Press Enter to open folder]'
sleep 1 && xdg-open '$dest' 2>/dev/null
GHEOF
    chmod +x "$tmpscript"
    case "$TERM_BIN" in
        xfce4-terminal) xfce4-terminal --title="🎮 GoldHEN Release" -e "bash $tmpscript" ;;
        gnome-terminal) gnome-terminal --title="🎮 GoldHEN Release" -- bash "$tmpscript" ;;
        mate-terminal)  mate-terminal  --title="🎮 GoldHEN Release" -e "bash $tmpscript" ;;
        *)              xterm -title "🎮 GoldHEN Release" -e bash "$tmpscript" ;;
    esac

    sleep 1
    [ -d "$dest" ] && ls "$dest"/*.bin "$dest"/*.elf 2>/dev/null | head -3 && \
        yad_info "✓ GoldHEN téléloaded\n📂 <tt>$dest</tt>"
}
export -f do_git_goldhen

#------------------------------------------------------------------------
# 3. Prepare PS4 boot USB drive
#------------------------------------------------------------------------
do_prepare_usb() {
    # Detect USB drives/disks.
    # 1) lsblk's TRAN column is only reliable on the whole-disk row (sdb),
    #    not on its partitions (sdb1) -> walk up to the parent disk
    #    (PKNAME) to check the transport, otherwise USB sticks/external
    #    SSDs are never listed.
    # 2) Some USB-SATA docks/enclosures (ASMedia/JMicron bridge in ATA
    #    pass-through mode) report TRAN=sata instead of usb -> also check
    #    the disk's real udev path, which always goes through a "usbX"
    #    node when physically connected via USB, regardless of what
    #    lsblk's transport detection reports.
    local usb_disks=()
    local name tran syspath
    while read -r name tran; do
        [ -z "$name" ] && continue
        if [ "$tran" = "usb" ]; then
            usb_disks+=("$name")
            continue
        fi
        syspath=$(udevadm info -q path -n "/dev/$name" 2>/dev/null)
        case "$syspath" in
            */usb*) usb_disks+=("$name") ;;
        esac
    done < <(lsblk -dn -o NAME,TRAN 2>/dev/null)

    local usb_list=()
    while IFS= read -r line; do
        local dev pkname size fstype is_usb d
        dev=$(echo "$line"    | awk '{print $1}')
        pkname=$(echo "$line" | awk '{print $2}')
        size=$(echo "$line"   | awk '{print $3}')
        fstype=$(echo "$line" | awk '{print $4}')
        [ -z "$dev" ] && continue

        is_usb=0
        for d in "${usb_disks[@]}"; do
            { [ "$dev" = "$d" ] || [ "$pkname" = "$d" ]; } && is_usb=1 && break
        done
        [ "$is_usb" -eq 0 ] && continue
        [ -z "$fstype" ] && continue

        usb_list+=("/dev/$dev" "${size}  |  ${fstype:-—}")
    done < <(lsblk -ln -o NAME,PKNAME,SIZE,FSTYPE 2>/dev/null | grep -v "^loop")

    if [ "${#usb_list[@]}" -eq 0 ]; then
        yad_err "No USB drive / external disk detected.\nConnect the device and try again.\n\n<small>Check with:\nlsblk -o NAME,SIZE,FSTYPE,TRAN\nudevadm info -q path -n /dev/sdX  (should contain 'usb')</small>"
        return
    fi

    local sel_dev
    sel_dev=$(yad --center --borders=10 \
        --title="Select USB drive" \
        --list \
        --text="<b>Préparer une clé USB de boot PS4</b>\n\nSélectionnez la partition USB cible :\n⚠️  Les fichiers existants dans <tt>/boot</tt> seront remplacés." \
        --column="Partition" \
        --column="Size  |  FS" \
        "${usb_list[@]}" \
        --print-column=1 --separator="" \
        --button="Cancel:1" --button="Select:0" \
        --width=560 --height=300)
    [ $? -ne 0 ] || [ -z "$sel_dev" ] && return
    sel_dev="${sel_dev//|/}"

    # Search for bzImage in the project
    local bzimage_default=""
    for k in "$KERNELS_DIR"/*/arch/x86/boot/bzImage; do
        [ -f "$k" ] && bzimage_default="$k" && break
    done
    # Fallback: kernel sources Tab 10
    if [ -z "$bzimage_default" ]; then
        local kdir
        kdir=$(cat "$CONF_DIR/kernel-src-dir.txt" 2>/dev/null)
        [ -f "$kdir/arch/x86/boot/bzImage" ] && bzimage_default="$kdir/arch/x86/boot/bzImage"
    fi

    # Search for initramfs
    local initramfs_default=""
    [ -f "$PROJECT_DIR/ps4-linux-payloads/linux/initramfs.cpio.gz" ] && \
        initramfs_default="$PROJECT_DIR/ps4-linux-payloads/linux/initramfs.cpio.gz"

    local out
    out=$(yad --center --borders=10 \
        --title="Files to copy to USB drive" \
        --form \
        --text="<b>Préparation clé USB PS4</b>\n\nLa structure <tt>boot/</tt> sera créée à la racine de la clé.\nLaissez vide pour ne pas copier le fichier.\n" \
        --field="USB drive (partition):":RO "$sel_dev" \
        --field="bzImage :":FL "${bzimage_default:-$PROJECT_DIR/}" \
        --field="initramfs.cpio.gz :":FL "${initramfs_default:-$PROJECT_DIR/}" \
        --field="Create bootargs.txt:":CHK "FALSE" \
        --field="Create vram.txt:":CHK "FALSE" \
        --button="Cancel:1" --button="🚀 Prepare drive:0" \
        --width=680)
    [ $? -ne 0 ] || [ -z "$out" ] && return

    IFS='|' read -r _dev bzimage_src initramfs_src do_bootargs do_vram <<< "$out"
    bzimage_src="${bzimage_src//|/}"
    initramfs_src="${initramfs_src//|/}"

    # Validate selected files
    local copy_bz="" copy_init=""
    [ -f "$bzimage_src" ]   && copy_bz="$bzimage_src"
    [ -f "$initramfs_src" ] && copy_init="$initramfs_src"

    if [ -z "$copy_bz" ] && [ -z "$copy_init" ] && \
       [ "$do_bootargs" != "TRUE" ] && [ "$do_vram" != "TRUE" ]; then
        yad_err "No files selected to copy."
        return
    fi

    # bootargs / vram values if requested
    local bootargs_val="" vram_val=""
    if [ "$do_bootargs" = "TRUE" ] || [ "$do_vram" = "TRUE" ]; then
        local bv_out
        bv_out=$(yad --center --borders=10 \
            --title="Text file contents" \
            --form \
            --text="<b>Contenu des fichiers optionnels</b>\n\n<small>bootargs.txt : arguments passés au kernel\nvram.txt     : taille VRAM en Mo (ex: 256)</small>\n" \
            --field="bootargs.txt :":TEXT "amdgpu.cik_support=1 amdgpu.si_support=1 amdgpu.dc=0 mitigations=off nopti" \
            --field="vram.txt (MB):":TEXT "256" \
            --button="Cancel:1" --button="OK:0" \
            --width=700)
        [ $? -ne 0 ] || [ -z "$bv_out" ] && return
        bootargs_val=$(echo "$bv_out" | cut -d'|' -f1)
        vram_val=$(echo "$bv_out"     | cut -d'|' -f2)
    fi

    local tmpscript
    tmpscript=$(mktemp /tmp/hyb-usb-XXXX.sh)
    cat > "$tmpscript" << UEOF
#!/bin/bash
set -e
echo '=== Preparing PS4 boot USB drive ==='
echo "Partition : $sel_dev"
echo ''

# Mount USB drive if not yet mounted
MNT=\$(lsblk -no MOUNTPOINT '$sel_dev' 2>/dev/null | head -1 | tr -d ' ')
MOUNTED_BY_US=0

if [ -z "\$MNT" ]; then
    MNT=\$(mktemp -d /tmp/ps4usb-XXXX)
    echo "Temporary mount at \$MNT ..."
    sudo mount '$sel_dev' "\$MNT" 2>/dev/null || {
        echo "ERROR: cannot mount $sel_dev"
        read -rp '[Press Enter to close]'
        exit 1
    }
    MOUNTED_BY_US=1
fi

echo "Mount point: \$MNT"
echo ''

# Create boot/ structure
echo '--- Creating boot/ directory ---'
sudo mkdir -p "\$MNT/boot"

# Copy bzImage
$([ -n "$copy_bz" ] && echo "echo '--- Copying bzImage ---'
sudo cp '$copy_bz' \"\$MNT/boot/bzImage\"
echo '  ✓ bzImage copied'")

# Copy initramfs
$([ -n "$copy_init" ] && echo "echo '--- Copying initramfs.cpio.gz ---'
sudo cp '$copy_init' \"\$MNT/boot/initramfs.cpio.gz\"
echo '  ✓ initramfs.cpio.gz copied'")

# bootargs.txt
$([ "$do_bootargs" = "TRUE" ] && echo "echo '--- Creating bootargs.txt ---'
echo '$bootargs_val' | sudo tee \"\$MNT/boot/bootargs.txt\" >/dev/null
echo '  ✓ bootargs.txt created'")

# vram.txt
$([ "$do_vram" = "TRUE" ] && echo "echo '--- Creating vram.txt ---'
echo '$vram_val' | sudo tee \"\$MNT/boot/vram.txt\" >/dev/null
echo '  ✓ vram.txt created'")

echo ''
echo '=== USB drive contents (/boot) ==='
ls -lh "\$MNT/boot/" 2>/dev/null

sync
echo ''
echo '✓ Sync OK — you can safely remove the drive.'

if [ \$MOUNTED_BY_US -eq 1 ]; then
    sudo umount "\$MNT" 2>/dev/null
    rmdir "\$MNT" 2>/dev/null
fi

echo ''
read -rp '[Press Enter to close]'
UEOF
    chmod +x "$tmpscript"
    case "$TERM_BIN" in
        xfce4-terminal) xfce4-terminal --title="Préparer clé USB PS4" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
        gnome-terminal) gnome-terminal --title="Préparer clé USB PS4" -- bash -c "$tmpscript; rm -f $tmpscript" ;;
        mate-terminal)  mate-terminal  --title="Préparer clé USB PS4" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
        *)              xterm -title "Préparer clé USB PS4" -e bash -c "$tmpscript; rm -f $tmpscript" ;;
    esac
}
export -f do_prepare_usb

#------------------------------------------------------------------------
# 4. FTP transfer to PS4 (bzImage + initramfs → /data/linux/boot)
#------------------------------------------------------------------------
PS4_FTP_IP_FILE="$CONF_DIR/ps4-ftp-ip.txt"
export PS4_FTP_IP_FILE

do_ftp_transfer() {
    local last_ip
    last_ip=$(cat "$PS4_FTP_IP_FILE" 2>/dev/null || echo "192.168.1.")

    # Search for bzImage in the project
    local bzimage_default=""
    for k in "$KERNELS_DIR"/*/arch/x86/boot/bzImage; do
        [ -f "$k" ] && bzimage_default="$k" && break
    done
    local kdir; kdir=$(cat "$CONF_DIR/kernel-src-dir.txt" 2>/dev/null)
    [ -z "$bzimage_default" ] && [ -f "$kdir/arch/x86/boot/bzImage" ] && \
        bzimage_default="$kdir/arch/x86/boot/bzImage"

    local initramfs_default=""
    [ -f "$PROJECT_DIR/ps4-linux-payloads/linux/initramfs.cpio.gz" ] && \
        initramfs_default="$PROJECT_DIR/ps4-linux-payloads/linux/initramfs.cpio.gz"

    local out
    out=$(yad --center --borders=10 \
        --title="Transfert FTP vers la PS4" \
        --form \
        --text="<b>Transfert FTP → /data/linux/boot/ sur la PS4</b>\n\n<small>La PS4 doit être sous Linux ou avoir un serveur FTP actif (GoldHEN).\nLaissez vide pour ne pas envoyer le fichier.</small>\n" \
        --field="IP de la PS4 :":TEXT "$last_ip" \
        --field="Port FTP :":NUM "2121!1..65535!1" \
        --field="Utilisateur FTP :":TEXT "anonymous" \
        --field="Mot de passe :":TEXT "" \
        --field="Dossier distant :":TEXT "/data/linux/boot" \
        --field="bzImage local :":FL "${bzimage_default:-$PROJECT_DIR/}" \
        --field="initramfs.cpio.gz local :":FL "${initramfs_default:-$PROJECT_DIR/}" \
        --button="Cancel:1" --button="🚀 Envoyer:0" \
        --width=720)
    [ $? -ne 0 ] || [ -z "$out" ] && return

    IFS='|' read -r ps4_ip ps4_port ftp_user ftp_pass remote_dir bz_src init_src <<< "$out"
    ps4_ip="${ps4_ip//|/}"
    ps4_port="${ps4_port//|/}"
    ftp_user="${ftp_user//|/}"
    ftp_pass="${ftp_pass//|/}"
    remote_dir="${remote_dir//|/}"
    bz_src="${bz_src//|/}"
    init_src="${init_src//|/}"

    [ -z "$ps4_ip" ] && yad_err "IP de la PS4 non saisie." && return

    echo "$ps4_ip" > "$PS4_FTP_IP_FILE"

    # Vérifier que curl est available
    if ! command -v curl >/dev/null 2>&1; then
        yad_err "curl is required.\n<b>sudo apt install curl</b>"
        return
    fi

    local files_to_send=()
    [ -f "$bz_src" ]   && files_to_send+=("$bz_src")
    [ -f "$init_src" ] && files_to_send+=("$init_src")

    if [ "${#files_to_send[@]}" -eq 0 ]; then
        yad_err "No fichier valide sélectionné."
        return
    fi

    local tmpscript
    tmpscript=$(mktemp /tmp/hyb-ftp-XXXX.sh)
    {
        echo "#!/bin/bash"
        echo "echo '=== Transfert FTP vers PS4 ==='"
        echo "echo \"  IP     : $ps4_ip:$ps4_port\""
        echo "echo \"  Dossier: $remote_dir\""
        echo "echo ''"
        local ftp_url="ftp://${ftp_user}"
        [ -n "$ftp_pass" ] && ftp_url="${ftp_url}:${ftp_pass}"
        ftp_url="${ftp_url}@${ps4_ip}:${ps4_port}${remote_dir}/"

        for f in "${files_to_send[@]}"; do
            local fname
            fname=$(basename "$f")
            echo "echo \"--- Envoi : $fname ---\""
            echo "curl -T '$f' '${ftp_url}' --ftp-create-dirs --progress-bar 2>&1"
            echo "[ \$? -eq 0 ] && echo \"  ✓ $fname envoyé\" || echo \"  ✗ Erreur envoi $fname\""
            echo "echo ''"
        done
        echo "echo '=== Transfert terminé ==='"
        echo "echo ''"
        echo "read -rp '[Press Enter to close]'"
    } > "$tmpscript"
    chmod +x "$tmpscript"
    case "$TERM_BIN" in
        xfce4-terminal) xfce4-terminal --title="FTP PS4 — $ps4_ip" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
        gnome-terminal) gnome-terminal --title="FTP PS4 — $ps4_ip" -- bash -c "$tmpscript; rm -f $tmpscript" ;;
        mate-terminal)  mate-terminal  --title="FTP PS4 — $ps4_ip" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
        *)              xterm -title "FTP PS4 — $ps4_ip" -e bash -c "$tmpscript; rm -f $tmpscript" ;;
    esac
}
export -f do_ftp_transfer

#------------------------------------------------------------------------
# 5. Éditeur bootargs.txt / vram.txt
#------------------------------------------------------------------------
BOOTARGS_FILE="$CONF_DIR/bootargs.txt"
VRAM_FILE="$CONF_DIR/vram.txt"
export BOOTARGS_FILE VRAM_FILE

[ ! -f "$BOOTARGS_FILE" ] && cat > "$BOOTARGS_FILE" << 'BAEOF'
amdgpu.cik_support=1 amdgpu.si_support=1 amdgpu.dc=0 amdgpu.gttsize=2048 amdgpu.vm_fragment_size=9 amdgpu.pcie_gen2=1 amdgpu.aspm=0 amdgpu.dpm=1 amdgpu.lockup_timeout=10000 mitigations=off nopti spectre_v2=off noibpb noibrs ibt=off processor.max_cstate=1 idle=nomwait
BAEOF
[ ! -f "$VRAM_FILE" ] && echo "256" > "$VRAM_FILE"

do_edit_bootargs() {
    local cur_ba cur_vram
    cur_ba=$(cat "$BOOTARGS_FILE"  2>/dev/null)
    cur_vram=$(cat "$VRAM_FILE"    2>/dev/null || echo "256")

    local out
    out=$(yad --center --borders=10 \
        --title="Éditeur bootargs.txt / vram.txt" \
        --form \
        --text="<b>Édition des fichiers de configuration kernel PS4</b>\n
<b>bootargs.txt</b> — arguments passés au kernel au démarrage
<b>vram.txt</b>     — taille VRAM réservée (en Mo)

<small>Paramètres UART (désactivé sur noyaux récents) :
  Éolie/Belize : <tt>console=uart8250,mmio32,0xd0340000</tt>
  Baïkal       : <tt>console=uart8250,mmio32,0xC890E000</tt></small>\n" \
        --field="bootargs.txt :":TEXT "$cur_ba" \
        --field="VRAM (Mo) :":TEXT "$cur_vram" \
        --field="Ajouter mitigations=off :":CHK "FALSE" \
        --field="Ajouter UART Éolie/Belize :":CHK "FALSE" \
        --field="Ajouter UART Baïkal :":CHK "FALSE" \
        --button="Cancel:1" \
        --button="💾 Save:0" \
        --width=800)
    [ $? -ne 0 ] || [ -z "$out" ] && return

    IFS='|' read -r new_ba new_vram add_mit add_uart_belize add_uart_baikal <<< "$out"

    # Ajouter les options cochées si pas déjà présentes
    [ "$add_mit"          = "TRUE" ] && \
        [[ "$new_ba" != *"mitigations=off"* ]] && \
        new_ba="$new_ba mitigations=off nopti spectre_v2=off noibpb noibrs ibt=off"
    [ "$add_uart_belize"  = "TRUE" ] && \
        [[ "$new_ba" != *"uart8250"* ]] && \
        new_ba="$new_ba console=uart8250,mmio32,0xd0340000"
    [ "$add_uart_baikal"  = "TRUE" ] && \
        [[ "$new_ba" != *"uart8250"* ]] && \
        new_ba="$new_ba console=uart8250,mmio32,0xC890E000"

    # Nettoyer les espaces multiples
    new_ba=$(echo "$new_ba" | tr -s ' ' | sed 's/^ //;s/ $//')

    echo "$new_ba"   > "$BOOTARGS_FILE"
    echo "$new_vram" > "$VRAM_FILE"

    # Proposer de copier vers USB ou via FTP
    local action
    action=$(yad --center --borders=10 \
        --title="Fichiers sauvegardés" \
        --list \
        --text="✓ <b>bootargs.txt</b> et <b>vram.txt</b> sauvegardés dans :\n<tt>$CONF_DIR</tt>\n\nQue voulez-vous faire ensuite ?" \
        --column="Action" \
        --column="Description" \
        "usb"   "Copier sur la clé USB de boot" \
        "ftp"   "Transférer via FTP vers la PS4" \
        "open"  "Ouvrir le dossier de config" \
        "done"  "Terminer" \
        --print-column=1 --separator="" \
        --button="Cancel:1" --button="OK:0" \
        --width=480 --height=280)
    [ $? -ne 0 ] || [ -z "$action" ] && return
    action="${action//|/}"

    case "$action" in
        usb)  do_prepare_usb   ;;
        ftp)  do_ftp_transfer  ;;
        open) xdg-open "$CONF_DIR" >/dev/null 2>&1 & ;;
    esac
}
export -f do_edit_bootargs

#------------------------------------------------------------------------
# 6. Builder initramfs minimaliste (busybox statique + repackage cpio.gz)
#------------------------------------------------------------------------
INITRAMFS_DIR="$PROJECT_DIR/initramfs-build"
export INITRAMFS_DIR

do_build_initramfs() {
    # Vérifier les outils nécessaires
    local missing_tools=()
    for t in cpio gzip find; do
        command -v "$t" >/dev/null 2>&1 || missing_tools+=("$t")
    done
    if [ "${#missing_tools[@]}" -gt 0 ]; then
        yad_err "Outils missings : <b>${missing_tools[*]}</b>\n<tt>sudo apt install ${missing_tools[*]}</tt>"
        return
    fi

    local choice
    choice=$(yad --center --borders=10 \
        --title="Builder initramfs PS4" \
        --list \
        --text="<b>Builder initramfs minimaliste pour PS4</b>\n\nQue voulez-vous faire ?" \
        --column="Action" \
        --column="Description" \
        "create"   "Créer un nouveau dossier de travail (busybox statique)" \
        "repack"   "Repackager un initramfs existant en cpio.gz" \
        "extract"  "Extraire un initramfs.cpio.gz existant pour le modifier" \
        "addscript" "Ajouter un script init personnalisé" \
        --print-column=1 --separator="" \
        --button="Cancel:1" --button="OK:0" \
        --width=600 --height=300)
    [ $? -ne 0 ] || [ -z "$choice" ] && return
    choice="${choice//|/}"

    case "$choice" in

        create)
            # Vérifier busybox-static
            if ! command -v busybox >/dev/null 2>&1 && \
               [ ! -f /bin/busybox ] && [ ! -f /usr/bin/busybox ]; then
                yad_confirm "busybox-static n'est pas installé.\n\nInstaller maintenant ?\n<tt>sudo apt install busybox-static</tt>" || return
                run_in_term "Installation busybox-static" "sudo apt install -y busybox-static"
            fi

            local tmpscript
            tmpscript=$(mktemp /tmp/hyb-initramfs-XXXX.sh)
            cat > "$tmpscript" << IEOF
#!/bin/bash
echo '=== Création dossier initramfs PS4 ==='
mkdir -p '$INITRAMFS_DIR'
cd '$INITRAMFS_DIR'

# Structure minimale
for d in bin sbin etc proc sys dev tmp lib lib64 usr/bin usr/sbin mnt/root; do
    mkdir -p \$d
done

# Copier busybox
BUSYBOX=\$(command -v busybox || echo /bin/busybox)
if [ ! -f "\$BUSYBOX" ]; then
    echo 'ERREUR : busybox introuvable — sudo apt install busybox-static'
    read -rp '[Press Enter to close]'
    exit 1
fi
cp "\$BUSYBOX" bin/busybox
chmod +x bin/busybox

# Créer les applets busybox
cd bin
./busybox --list 2>/dev/null | while read app; do
    [ "\$app" = "busybox" ] && continue
    ln -sf busybox "\$app" 2>/dev/null
done
cd ..

# Script init minimal
cat > init << 'INITEOF'
#!/bin/sh
mount -t proc     none /proc
mount -t sysfs    none /sys
mount -t devtmpfs none /dev 2>/dev/null || mknod /dev/null c 1 3

# Lire le temps depuis la ligne de commande (time=TIMESTAMP)
CMDLINE=\$(cat /proc/cmdline)
for param in \$CMDLINE; do
    case "\$param" in
        time=*) date -s @"\${param#time=}" 2>/dev/null ;;
    esac
done

echo "=== initramfs PS4 boot ==="
echo "Ligne de commande : \$CMDLINE"

# Shell de secours
exec /bin/sh
INITEOF
chmod +x init

echo ''
echo '=== Structure créée ==='
find . -maxdepth 2 | sort
echo ''
echo 'To repackage → relaunch the builder and choose "Repackage"'
echo ''
read -rp '[Press Enter to open folder]'
sleep 1 && xdg-open '$INITRAMFS_DIR'
IEOF
            chmod +x "$tmpscript"
            case "$TERM_BIN" in
                xfce4-terminal) xfce4-terminal --title="Créer initramfs" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
                gnome-terminal) gnome-terminal --title="Créer initramfs" -- bash -c "$tmpscript; rm -f $tmpscript" ;;
                mate-terminal)  mate-terminal  --title="Créer initramfs" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
                *)              xterm -title "Créer initramfs" -e bash -c "$tmpscript; rm -f $tmpscript" ;;
            esac
            ;;

        extract)
            local src_cpio
            src_cpio=$(yad --center --borders=10 \
                --title="Select initramfs to extract" \
                --file --filename="$PROJECT_DIR/" \
                --file-filter="initramfs | *.cpio.gz *.cpio *.gz" \
                --button="Cancel:1" --button="Select:0" \
                --width=860 --height=540)
            [ $? -ne 0 ] || [ -z "$src_cpio" ] && return

            local tmpscript
            tmpscript=$(mktemp /tmp/hyb-extract-initramfs-XXXX.sh)
            cat > "$tmpscript" << EXEOF
#!/bin/bash
echo '=== Extracting initramfs ==='
mkdir -p '$INITRAMFS_DIR'
cd '$INITRAMFS_DIR'
echo "Source : $src_cpio"
echo ''
case "$src_cpio" in
    *.gz) zcat '$src_cpio' | cpio -idm --quiet ;;
    *)    cpio -idm --quiet < '$src_cpio' ;;
esac
echo '✓ Extraction complete'
echo ''
echo '=== Contents ==='
ls -la
echo ''
read -rp '[Press Enter to open folder]'
sleep 1 && xdg-open '$INITRAMFS_DIR'
EXEOF
            chmod +x "$tmpscript"
            case "$TERM_BIN" in
                xfce4-terminal) xfce4-terminal --title="Extraire initramfs" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
                gnome-terminal) gnome-terminal --title="Extraire initramfs" -- bash -c "$tmpscript; rm -f $tmpscript" ;;
                mate-terminal)  mate-terminal  --title="Extraire initramfs" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
                *)              xterm -title "Extraire initramfs" -e bash -c "$tmpscript; rm -f $tmpscript" ;;
            esac
            ;;

        repack)
            [ ! -d "$INITRAMFS_DIR" ] && \
                yad_err "initramfs directory not found:\n<tt>$INITRAMFS_DIR</tt>\nFirst create the structure with 'Create'." && return

            local out_file="$PROJECT_DIR/initramfs.cpio.gz"
            local out_choice
            out_choice=$(yad --center --borders=10 \
                --title="Repackage destination" \
                --form \
                --text="<b>Repackage as initramfs.cpio.gz</b>\n\nSource : <tt>$INITRAMFS_DIR</tt>" \
                --field="Output file:":FL "$out_file" \
                --button="Cancel:1" --button="🚀 Repackage:0" \
                --width=680)
            [ $? -ne 0 ] || [ -z "$out_choice" ] && return
            out_file=$(echo "$out_choice" | cut -d'|' -f1)

            local tmpscript
            tmpscript=$(mktemp /tmp/hyb-repack-initramfs-XXXX.sh)
            cat > "$tmpscript" << RPEOF
#!/bin/bash
echo '=== Repackaging initramfs ==='
echo "Source  : $INITRAMFS_DIR"
echo "Sortie  : $out_file"
echo ''
cd '$INITRAMFS_DIR'
find . | cpio -o -H newc 2>/dev/null | gzip -9 > '$out_file'
echo "✓ Créé : $out_file"
echo ""
ls -lh '$out_file'
echo ''
echo 'You can now:'
echo '  → Copy to USB drive  (tab: Prepare USB drive)'
echo '  → Transfer via FTP  (tab: PS4 FTP Transfer)'
echo ''
read -rp '[Press Enter to close]'
RPEOF
            chmod +x "$tmpscript"
            case "$TERM_BIN" in
                xfce4-terminal) xfce4-terminal --title="Repackager initramfs" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
                gnome-terminal) gnome-terminal --title="Repackager initramfs" -- bash -c "$tmpscript; rm -f $tmpscript" ;;
                mate-terminal)  mate-terminal  --title="Repackager initramfs" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
                *)              xterm -title "Repackager initramfs" -e bash -c "$tmpscript; rm -f $tmpscript" ;;
            esac
            ;;

        addscript)
            [ ! -d "$INITRAMFS_DIR" ] && \
                yad_err "initramfs directory not found:\n<tt>$INITRAMFS_DIR</tt>\nFirst create the structure." && return

            local script_name
            local out_s
            out_s=$(yad --center --borders=10 \
                --title="Add script to initramfs" \
                --form \
                --text="<b>Add a script to the initramfs</b>\n\nThe script will be created in <tt>$INITRAMFS_DIR/</tt>" \
                --field="Script name:":TEXT "custom-init.sh" \
                --field="Content:":TXT "#!/bin/sh\n# Script personnalisé\necho 'Hello from PS4 initramfs'\n" \
                --button="Cancel:1" --button="Create:0" \
                --width=700 --height=400)
            [ $? -ne 0 ] || [ -z "$out_s" ] && return
            script_name=$(echo "$out_s" | cut -d'|' -f1)
            local script_content
            script_content=$(echo "$out_s" | cut -d'|' -f2-)
            local script_path="$INITRAMFS_DIR/$script_name"
            printf '%s' "$script_content" > "$script_path"
            chmod +x "$script_path"
            yad_info "✓ Script créé : <tt>$script_path</tt>\n\nN'oubliez pas de le référencer dans <tt>init</tt>,\npuis de repackager l'initramfs."
            ;;
    esac
}
export -f do_build_initramfs

#------------------------------------------------------------------------
# Al-Azif — GitHub profile
#------------------------------------------------------------------------
do_open_url_alazif() {
    xdg-open "https://github.com/Al-Azif" >/dev/null 2>&1 &
    yad_info "🐙 <b>Al-Azif</b>

Opening GitHub profile...

<small>You will find his PS4 tools:
payloads, exploits, firmware dumps and more.</small>

<tt>https://github.com/Al-Azif</tt>"
}
export -f do_open_url_alazif

#------------------------------------------------------------------------
# Open project folder
#------------------------------------------------------------------------
do_open_project_dir() {
    xdg-open "$PROJECT_DIR" >/dev/null 2>&1 &
    yad_info "📂 Project opened:\n<tt>$PROJECT_DIR</tt>"
}

tab_git_ps4() {
    yad --plug="$KEY" --tabnum=10 \
        --form --scroll \
        --image="/usr/share/hybryde/SquareGlass/Java 1.png" --image-on-top \
        --text="<big><b><span foreground='#F48FB1'>🚀 GIT PS4 — Kernels + Orbis + Payloads + Deployment</span></b></big>

<b>PROJET :</b> <tt>$PROJECT_DIR</tt>

Download, compile and deploy the full PS4 Linux ecosystem.\n" \
        \
        --field="":LBL "" \
        --field="<b>— PS4 KERNELS (crashniels/linux) —</b>":LBL "" \
        --field="  🚀 crashniels/linux — PS4 kernel (choose branch)":BTN 'bash -c "do_git_ps4_kernel"' \
        --field="  🚀 feeRnt/ps4-linux-12xx — kernel PS4 (branches auto)":BTN 'bash -c "do_git_feernt_kernel"' \
        --field="  🗂  fail0verflow/ps4-linux (original reference)":BTN 'bash -c "do_git_fail0verflow"' \
        --field="  🐙 Al-Azif — profil GitHub (payloads, outils PS4)":BTN 'bash -c "do_open_url_alazif"' \
        --field="  🎮 GoldHEN — download latest release":BTN 'bash -c "do_git_goldhen"' \
        \
        --field="":LBL "" \
        --field="<b>— ORBIS (PS4 SDK) —</b>":LBL "" \
        --field="  🚀 OpenOrbis PS4 Toolchain (latest release, auto)":BTN 'bash -c "do_git_orbis"' \
        \
        --field="":LBL "" \
        --field="<b>— LINUX PAYLOADS (ps4boot) —</b>":LBL "" \
        --field="  🚀 ps4-linux-payloads — download + compile":BTN 'bash -c "do_git_payloads"' \
        --field="  📖 README GoldHEN / bzImage / initramfs":BTN 'bash -c "do_payloads_readme"' \
        --field="  ⚡ ps4-kexec — kexec payload (boot chain)":BTN 'bash -c "do_git_kexec"' \
        \
        --field="":LBL "" \
        --field="<b>— DEPLOYMENT —</b>":LBL "" \
        --field="  💾 Prepare a PS4 boot USB drive":BTN 'bash -c "do_prepare_usb"' \
        --field="  📡 FTP Transfer → /data/linux/boot/ on PS4":BTN 'bash -c "do_ftp_transfer"' \
        \
        --field="":LBL "" \
        --field="<b>— KERNEL CONFIGURATION —</b>":LBL "" \
        --field="  ⚙  Edit bootargs.txt / vram.txt":BTN 'bash -c "do_edit_bootargs"' \
        \
        --field="":LBL "" \
        --field="<b>— INITRAMFS BUILDER —</b>":LBL "" \
        --field="  🛠  Create / extract / repackage an initramfs.cpio.gz":BTN 'bash -c "do_build_initramfs"' \
        --field="  <small><i>→ Based on static busybox — supports PS4 RTC init script</i></small>":LBL "" \
        \
        --field="":LBL "" \
        --field="<b>— Project —</b>":LBL "" \
        --field="  📂 Open PROJECT-PS4/":BTN 'bash -c "do_open_project_dir"' \
        \
        --field="Kernels:   <tt>$KERNELS_DIR</tt>":LBL "" \
        --field="Orbis:     <tt>$ORBIS_DIR</tt>":LBL "" \
        --field="Payloads:  <tt>$PROJECT_DIR/ps4-linux-payloads</tt>":LBL "" \
        --field="kexec:     <tt>$PROJECT_DIR/ps4-kexec</tt>":LBL "" \
        --field="initramfs: <tt>$INITRAMFS_DIR</tt>":LBL "" \
        \
        "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" \
        &
}

#========================================================================

#========================================================================
# TAB 13 — DionKill Downloads (live scraping)
#========================================================================

# ── Format size in bytes → human readable ─────────────────────────────
do_dl_fmt_size() {
    local b="$1"
    if   [ "$b" -gt 1073741824 ] 2>/dev/null; then awk "BEGIN{printf \"%.2f GB\", $b/1073741824}"
    elif [ "$b" -gt 1048576    ] 2>/dev/null; then awk "BEGIN{printf \"%.1f MB\", $b/1048576}"
    elif [ "$b" -gt 1024       ] 2>/dev/null; then awk "BEGIN{printf \"%.1f KB\", $b/1024}"
    elif [ "$b" -gt 0          ] 2>/dev/null; then echo "${b} B"
    else echo "? (taille inconnue)"
    fi
}
export -f do_dl_fmt_size

# ── Get remote file size (HEAD + Content-Length) ──────────────────────
do_dl_get_size() {
    local url="$1"
    local bytes
    bytes=$(curl -sI --max-time 12 -L "$url" \
        | awk 'tolower($1)=="content-length:"{val=$2} END{print val+0}' \
        | tr -d '\r')
    echo "${bytes:-0}"
}
export -f do_dl_get_size

# ── Download with wget resume (-c) and terminal ───────────────────────
do_dl_wget() {
    local url="$1"
    local dest="$2"
    mkdir -p "$(dirname "$dest")"

    # Size before download
    local size_bytes size_str
    size_bytes=$(do_dl_get_size "$url")
    size_str=$(do_dl_fmt_size "$size_bytes")

    # Escape & for Pango in YAD fields
    local safe_fname safe_dest safe_url
    safe_fname=$(basename "$dest" | sed 's/&/\&amp;/g')
    safe_dest=$(dirname "$dest"   | sed 's/&/\&amp;/g')
    safe_url=$(echo "$url"        | sed 's/&/\&amp;/g')

    yad_confirm "⬇  <b>Téléchargement</b>\n\n<b>Fichier  :</b> <tt>${safe_fname}</tt>\n<b>Taille   :</b> ${size_str}\n<b>Vers     :</b> <tt>${safe_dest}</tt>\n\n<small>Reprise automatique si le fichier existe déjà (wget -c)</small>\n\nLancer le téléchargement ?" || return

    local tmpscript
    tmpscript=$(mktemp /tmp/hyb-dl-XXXX.sh)
    cat > "$tmpscript" << DLEOF
#!/bin/bash
echo "╔═════════════════════════════════════════════════════════════════╗"
echo "║  ⬇  PS4 Tools — Download                                 ║"
echo "╚═════════════════════════════════════════════════════════════════╝"
echo ""
echo "  Fichier : $(basename "$dest")"
echo "  Taille  : $size_str"
echo "  Dest    : $(dirname "$dest")"
echo ""
echo "  URL : $url"
echo ""
echo "  (wget -c  →  automatic resume if partial file)"
echo "─────────────────────────────────────────────────────────────────"
echo ""
wget -c --show-progress --progress=bar:force "$url" -O "${dest}.part"
RET=\$?
echo ""
if [ \$RET -eq 0 ]; then
    mv -f "${dest}.part" "$dest"
    echo "  ✓ Success — file available:"
    echo "    $dest"
else
    echo "  ✗ Erreur (code \$RET)"
    echo "    Le fichier partiel est conservé : ${dest}.part"
    echo "    Relancez pour reprendre le téléchargement."
fi
echo ""
read -rp "[Press Enter to close]"
DLEOF
    chmod +x "$tmpscript"
    case "$TERM_BIN" in
        xfce4-terminal) xfce4-terminal --title="⬇ $(basename "$dest")" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
        gnome-terminal)  gnome-terminal --title="⬇ $(basename "$dest")" -- bash -c "$tmpscript; rm -f $tmpscript" ;;
        mate-terminal)   mate-terminal  --title="⬇ $(basename "$dest")" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
        *)               xterm -title "⬇ $(basename "$dest")" -e bash -c "$tmpscript; rm -f $tmpscript" ;;
    esac
}
export -f do_dl_wget

# ── GitHub API: list release assets ───────────────────────────────────
do_dl_github_assets() {
    local gh_url="$1"
    local api_url=""

    if   [[ "$gh_url" =~ github\.com/([^/?#]+)/([^/?#]+)/releases/tag/([^/?#]+) ]]; then
        api_url="https://api.github.com/repos/${BASH_REMATCH[1]}/${BASH_REMATCH[2]}/releases/tags/${BASH_REMATCH[3]}"
    elif [[ "$gh_url" =~ github\.com/([^/?#]+)/([^/?#]+)/releases ]]; then
        api_url="https://api.github.com/repos/${BASH_REMATCH[1]}/${BASH_REMATCH[2]}/releases/latest"
    elif [[ "$gh_url" =~ github\.com/([^/?#]+)/([^/?#]+)$ ]]; then
        api_url="https://api.github.com/repos/${BASH_REMATCH[1]}/${BASH_REMATCH[2]}/releases/latest"
    else
        return 1
    fi

    local json
    json=$(curl -s --max-time 15 \
        -H "Accept: application/vnd.github+json" \
        "$api_url") || return 1

    echo "$json" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    tag = data.get('tag_name','?')
    assets = data.get('assets', [])
    if not assets:
        sys.exit(1)
    for a in sorted(assets, key=lambda x: x.get('name','')):
        n = a.get('name','')
        u = a.get('browser_download_url','')
        s = a.get('size', 0)
        if s > 1073741824: ss = f'{s/1073741824:.2f} GB'
        elif s > 1048576:  ss = f'{s/1048576:.1f} MB'
        elif s > 1024:     ss = f'{s/1024:.1f} KB'
        else:              ss = f'{s} B'
        print(f'{tag}\t{n}\t{ss}\t{u}')
except Exception:
    sys.exit(1)
" 2>/dev/null
}
export -f do_dl_github_assets

# ── Interactive GitHub asset selection with YAD list ──────────────────
do_dl_pick_github() {
    local gh_url="$1"
    local dest_dir="$2"
    local entry_name="$3"

    # Spinner during API call
    local PID_W
    yad --center --borders=10 --title="GitHub API…" \
        --text="🔄 <b>Fetching GitHub assets…</b>\n\n<small><tt>$gh_url</tt></small>" \
        --no-buttons --width=520 &
    PID_W=$!

    local assets
    assets=$(do_dl_github_assets "$gh_url")
    local api_ret=$?
    kill "$PID_W" 2>/dev/null; wait "$PID_W" 2>/dev/null

    if [ $api_ret -ne 0 ] || [ -z "$assets" ]; then
        yad_confirm "⚠  No binary assets found via GitHub API.\n\n<b>$entry_name</b>\n<small><tt>$gh_url</tt></small>\n\nOpen the page in the browser?" \
            && xdg-open "$gh_url" &
        return
    fi

    # Build YAD list arguments
    # Col 1 (HD) = URL (print-column=1), Col 2 = Tag, Col 3 = File, Col 4 = Size
    local list_args=() first_tag=""
    while IFS=$'\t' read -r tag name size url; do
        [ -z "$first_tag" ] && first_tag="$tag"
        list_args+=("$url" "$tag" "$name" "$size")
    done <<< "$assets"

    local sel ret
    while true; do
        sel=$(yad --center --borders=10 \
            --title="Assets GitHub — $entry_name" \
            --list \
            --text="<b>Release :</b> <tt>$first_tag</tt>\n\nSelect the file to download:\n\n<small>💡 Prefer <tt>bzImage_Clang_thinLTO</tt> if available · Auto-resume with <tt>-c</tt></small>\n" \
            --column="URL":HD \
            --column="Tag":TEXT \
            --column="Fichier":TEXT \
            --column="Taille":TEXT \
            "${list_args[@]}" \
            --print-column=1 \
            --button="Close:1" \
            --button="🌐 Navigateur:3" \
            --button="⬇ Download:0" \
            --width=920 --height=420)
        ret=$?
        case $ret in
            1|252) break ;;
            3) xdg-open "$gh_url" &
               break ;;
            0)
                [ -z "$sel" ] && yad_info "⚠  Sélectionnez un fichier dans la liste." && continue
                local s_url s_name
                # YAD --print-column=1 ajoute un | séparateur en fin → on le strip
                s_url="${sel%|}"
                s_url="${s_url%$'\n'}"   # strip newline éventuel
                # Dériver le nom de fichier depuis l'URL (urllib.parse pour les % encodés)
                s_name=$(python3 -c "
import sys, urllib.parse, os
u = urllib.parse.unquote(sys.argv[1].split('?')[0])
print(os.path.basename(u))
" "$s_url" 2>/dev/null)
                [ -z "$s_name" ] && s_name=$(basename "${s_url%%\?*}")
                [ -z "$s_url" ] && continue
                do_dl_wget "$s_url" "$dest_dir/$s_name"
                ;;
        esac
    done
}
export -f do_dl_pick_github

# ── Téléchargement Mega.nz via mega-get (mega-cmd) ────────────────────
do_dl_mega() {
    local url="$1"
    local dest_dir="$2"
    local name="$3"

    # mega-get est la commande de téléchargement de mega-cmd
    if ! command -v mega-get >/dev/null 2>&1; then
        yad_info "⚠  <b>mega-cmd non trouvé</b>\n\n<tt>mega-get</tt> n'est pas dans le PATH.\n\nInstallation :\n<tt>sudo apt install megacmd</tt>\n\nEn attendant, ouverture dans le navigateur…"
        xdg-open "$url" &
        return
    fi

    # Vérifier si l'utilisateur est connecté à Mega
    local whoami_out
    whoami_out=$(mega-whoami 2>&1)
    local is_logged=false
    echo "$whoami_out" | grep -qi "account e-mail\|@" && is_logged=true

    local safe_url; safe_url=$(echo "$url" | sed 's/&/\&amp;/g')
    local safe_name; safe_name=$(echo "$name" | sed 's/&/\&amp;/g')

    if ! $is_logged; then
        # Proposer de se connecter ou télécharger en anonyme
        yad --center --borders=10 \
            --title="Mega.nz — Authentification" \
            --text="<b>🔐 Mega.nz — Connexion</b>\n\n<b>Fichier :</b> <tt>$safe_name</tt>\n<b>URL     :</b> <tt>$safe_url</tt>\n\n<small>Vous n'êtes pas connecté à Mega.\nLes liens <tt>#!</tt> (fichiers publics) fonctionnent sans compte.\nLes liens <tt>#F!</tt> (dossiers) nécessitent un compte Mega.</small>\n" \
            --button="Cancel:1" \
            --button="🌐 Navigateur:3" \
            --button="🔑 Se connecter à Mega:2" \
            --button="⬇ Télécharger (anonyme):0" \
            --width=560
        local ret=$?
        case $ret in
            1|252) return ;;
            3) xdg-open "$url" &
               return ;;
            2)
                # Connexion Mega via mega-login
                local mega_user mega_pass
                mega_user=$(yad --center --borders=10 \
                    --title="Connexion Mega.nz" \
                    --entry --entry-label="Email Mega :" \
                    --button="Cancel:1" --button="Suivant:0" \
                    --width=380) || return
                mega_pass=$(yad --center --borders=10 \
                    --title="Connexion Mega.nz" \
                    --entry --entry-label="Mot de passe :" \
                    --hide-text \
                    --button="Cancel:1" --button="Se connecter:0" \
                    --width=380) || return
                mega-login "$mega_user" "$mega_pass"
                if [ $? -ne 0 ]; then
                    yad_err "❌ Échec de connection à Mega.\n\nVérifiez vos identifiants."
                    return
                fi
                log_entry "MEGA" "Connexion réussie : $mega_user"
                ;;
            0) : ;; # Continuer en anonyme
        esac
    fi

    # Confirmation + lancement du téléchargement dans un terminal
    yad_confirm "⬇  <b>Téléchargement Mega.nz</b>\n\n<b>Fichier :</b> <tt>$safe_name</tt>\n<b>Vers    :</b> <tt>$dest_dir</tt>\n\n<small>Outil : <tt>mega-get</tt> (mega-cmd)\nNote : la reprise n'est pas supportée par mega-get</small>\n\nLancer le téléchargement ?" || return

    local tmpscript
    tmpscript=$(mktemp /tmp/hyb-mega-XXXX.sh)
    cat > "$tmpscript" << MEGAEOF
#!/bin/bash
echo "╔═════════════════════════════════════════════════════════════════╗"
echo "║  ⬇  PS4 Tools — Mega.nz                                        ║"
echo "╚═════════════════════════════════════════════════════════════════╝"
echo ""
echo "  Fichier : ${name}"
echo "  Dest    : ${dest_dir}"
echo "  URL     : ${url}"
echo ""
echo "  Outil   : mega-get (mega-cmd)"
echo "─────────────────────────────────────────────────────────────────"
echo ""
mega-get "${url}" "${dest_dir}/"
RET=\$?
echo ""
if [ \$RET -eq 0 ]; then
    echo "  ✓ Succès — fichier available dans :"
    echo "    ${dest_dir}/"
else
    echo "  ✗ Erreur mega-get (code \$RET)"
    echo ""
    echo "  Causes possibles :"
    echo "    · Lien expiré ou supprimé"
    echo "    · Dossier nécessitant un compte (mega-login)"
    echo "    · mega-cmd server non démarré (lancez : mega-cmd)"
fi
echo ""
read -rp "[Press Enter to close]"
MEGAEOF
    chmod +x "$tmpscript"
    log_entry "MEGA" "Lancement mega-get : $url → $dest_dir"
    case "$TERM_BIN" in
        xfce4-terminal) xfce4-terminal --title="⬇ Mega — $name" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
        gnome-terminal)  gnome-terminal --title="⬇ Mega — $name" -- bash -c "$tmpscript; rm -f $tmpscript" ;;
        mate-terminal)   mate-terminal  --title="⬇ Mega — $name" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
        *)               xterm -title "⬇ Mega — $name" -e bash -c "$tmpscript; rm -f $tmpscript" ;;
    esac
}
export -f do_dl_mega

# ── Dispatcher selon type d'URL ────────────────────────────────────────
do_dl_dispatch() {
    local url="$1"
    local dest_dir="$2"
    local name="$3"
    local cat="$4"

    [ -z "$url" ] && yad_err "No URL associée à cette entrée." && return

    if [[ "$url" =~ github\.com/([^/?#]+)/([^/?#]+)/blob/ ]]; then
        # Fichier blob GitHub → convertir en URL raw.githubusercontent.com
        local raw="${url/github.com/raw.githubusercontent.com}"
        raw="${raw/\/blob\//\/}"
        local fname
        fname=$(python3 -c "
import sys, urllib.parse
u = sys.argv[1].split('?')[0]
print(urllib.parse.unquote(u.split('/')[-1]))
" "$raw" 2>/dev/null || basename "$raw")
        do_dl_wget "$raw" "$dest_dir/$fname"

    elif [[ "$url" =~ github\.com ]]; then
        # Page de release GitHub → API + sélection d'asset
        do_dl_pick_github "$url" "$dest_dir" "$name"

    elif [[ "$url" =~ mega\.nz ]]; then
        # Mega.nz → mega-get (mega-cmd) si available, sinon navigateur
        do_dl_mega "$url" "$dest_dir" "$name"

    elif [[ "$url" =~ ps4linux\.com ]] || [[ "$url" =~ youtube\.com ]]; then
        # Forum / YouTube → navigateur uniquement
        yad_info "🌐 <b>Ouverture dans le navigateur</b>\n\nCe lien (Forum / YouTube) ne supporte pas\nle téléchargement direct.\n\n<tt>$url</tt>"
        xdg-open "$url" &

    elif [[ "$url" =~ ^https?:// ]]; then
        # URL directe inconnue → tenter wget
        local fname
        fname=$(basename "$url" | sed 's/[?#].*//')
        [ -z "$fname" ] && fname="ps4-download-$(date +%s)"
        do_dl_wget "$url" "$dest_dir/$fname"

    else
        yad_err "URL non reconnue :\n<tt>${url:-(vide)}</tt>"
    fi
}
export -f do_dl_dispatch

# ── Gestionnaire principal — scraping live + liste YAD ────────────────
do_dl_manager() {
    # Vérification des dépendances
    local missing=()
    command -v curl    >/dev/null 2>&1 || missing+=("curl")
    command -v wget    >/dev/null 2>&1 || missing+=("wget")
    command -v python3 >/dev/null 2>&1 || missing+=("python3")
    if [ ${#missing[@]} -gt 0 ]; then
        yad_err "Dépendances missinges : <b>${missing[*]}</b>\n\n<tt>sudo apt install ${missing[*]}</tt>"
        return
    fi

    mkdir -p "$DL_KERNELS_DIR" "$DL_INITRAMFS_DIR" "$DL_DISTROS_DIR"

    # ── Scraping live ──────────────────────────────────────────────────
    local PID_W
    yad --center --borders=10 --title="Chargement…" \
        --text="🔄 <b>Scraping dionkill.github.io/ps4-linux-tutorial/files.html</b>\n\n<small>Lecture de la page en direct, veuillez patienter…</small>" \
        --no-buttons --width=480 &
    PID_W=$!

    local tmphtml
    tmphtml=$(mktemp /tmp/hyb-dl-html-XXXX.html)
    curl -sL --max-time 20 \
        "https://dionkill.github.io/ps4-linux-tutorial/files.html" \
        -o "$tmphtml"
    local curl_ret=$?
    kill "$PID_W" 2>/dev/null; wait "$PID_W" 2>/dev/null

    if [ $curl_ret -ne 0 ] || [ ! -s "$tmphtml" ]; then
        rm -f "$tmphtml"
        yad_err "❌ Impossible de contacter <tt>dionkill.github.io</tt>\n\nVérifiez votre connection internet."
        return
    fi

    # ── Parsing Python — extraction des tableaux HTML ──────────────────
    local tmppy
    tmppy=$(mktemp /tmp/hyb-dl-parse-XXXX.py)
    cat > "$tmppy" << 'PYEOF'
#!/usr/bin/env python3
"""
Scraper DionKill — extrait les kernels, initramfs et distros
depuis les tableaux HTML de la page files.html (VitePress/statique).
Sortie TSV : type \t nom \t compat \t url \t cat
"""
import sys, re
from html.parser import HTMLParser

class TblParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.tables = []
        self._t = self._r = self._c = None
        self._h = ''
    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == 'table':
            self._t = []
        elif tag == 'tr' and self._t is not None:
            self._r = []
        elif tag in ('td', 'th') and self._r is not None:
            self._c, self._h = '', ''
        elif tag == 'a' and self._c is not None:
            if not self._h:
                self._h = a.get('href', '')
        elif tag == 'br' and self._c is not None:
            self._c += ' '
    def handle_endtag(self, tag):
        if tag == 'table' and self._t is not None:
            self.tables.append(self._t); self._t = None
        elif tag == 'tr' and self._r is not None and self._t is not None:
            if self._r: self._t.append(self._r)
            self._r = None
        elif tag in ('td', 'th') and self._c is not None and self._r is not None:
            self._r.append((re.sub(r'\s+', ' ', self._c).strip(), self._h))
            self._c = None
    def handle_data(self, data):
        if self._c is not None:
            self._c += data

with open(sys.argv[1], encoding='utf-8', errors='ignore') as f:
    html = f.read()

p = TblParser()
p.feed(html)

# Correspondance index tableau → (label affiché, catégorie interne)
TABLE_META = {
    0: ('🐧 Kernel',   'kernel'),
    1: ('🖥 Serveur',  'kernel'),
    2: ('🔧 Alt',      'kernel'),
    3: ('📦 Distro',  'distro'),
    4: ('📦 Legacy',  'distro'),
}

SKIP = {'kernel download', 'distro', 'compatible southbridges',
        'source code', 'extra info', 'port credits', 'info', ''}

rows = []
first_distro_idx = None  # pour insérer initramfs juste avant

for i, table in enumerate(p.tables):
    if i not in TABLE_META:
        continue
    lbl, cat = TABLE_META[i]
    if cat == 'distro' and first_distro_idx is None:
        first_distro_idx = len(rows)
    for row in table[1:]:  # ignorer ligne d'en-tête
        if len(row) < 2:
            continue
        name  = row[0][0].strip()
        compat = row[1][0].strip() if len(row) > 1 else ''
        href  = row[0][1]
        if not name or name.lower() in SKIP:
            continue
        # Nettoyer le nom (retours à la ligne, espaces multiples)
        name = re.sub(r'\s{2,}', ' ', name.replace('\n', ' '))
        if len(name) > 62:
            name = name[:59] + '…'
        rows.append(f"{lbl}\t{name}\t{compat}\t{href}\t{cat}")

# Recherche de l'initramfs (lien hors tableau)
init_m = (re.search(r'href="([^"]*initramfs[^"]*\.zip[^"]*)"', html) or
          re.search(r'\[this one\]\(([^)]+initramfs[^)]*)\)', html))
if init_m:
    entry = f"💾 Initramfs\tinitramfs.zip\tTous (requis)\t{init_m.group(1)}\tinitramfs"
    idx = first_distro_idx if first_distro_idx is not None else len(rows)
    rows.insert(idx, entry)

for r in rows:
    if r.strip():
        print(r)
PYEOF

    local entries
    entries=$(python3 "$tmppy" "$tmphtml" 2>/dev/null)
    rm -f "$tmphtml" "$tmppy"

    if [ -z "$entries" ]; then
        yad_err "❌ Impossible de parser la page dionkill.\n\nLa structure a peut-être changé.\nOuvrez la page manuellement pour vérifier."
        return
    fi

    # ── Construction des arguments de la liste YAD ─────────────────────
    # Col 1 (HD) = "URL|CAT|NOM" encodé → print-column=1 compatible toutes versions YAD
    local list_args=()
    while IFS=$'\t' read -r typ nom compat url cat; do
        [ -z "$nom" ] && continue
        # payload: URL|CAT|NOM (| est rare dans les URLs GitHub/wget)
        local payload="${url}|${cat}|${nom}"
        list_args+=("$payload" "$typ" "$nom" "$compat")
    done <<< "$entries"

    local nb_entries=$(( ${#list_args[@]} / 4 ))

    # ── Boucle principale du gestionnaire ─────────────────────────────
    local sel ret
    while true; do
        sel=$(yad --center --borders=10 \
            --title="⬇  PS4 Linux Downloads — DionKill" \
            --list \
            --text="<big><b><span foreground='#4FC3F7'>⬇  PS4 Linux Downloads</span></b></big>\n<small>Source : <tt>https://dionkill.github.io/ps4-linux-tutorial/files.html</tt>  —  <b>$nb_entries entrées</b></small>

<b>🐧 Kernels  →</b> <tt>$DL_KERNELS_DIR</tt>
<b>💾 Initramfs→</b> <tt>$DL_INITRAMFS_DIR</tt>
<b>📦 Distros  →</b> <tt>$DL_DISTROS_DIR</tt>

<small>Sélectionnez une entrée → <b>⬇ Télécharger</b> (wget -c, reprise auto) ou <b>🌐 Navigateur</b></small>\n" \
            --column="DATA":HD \
            --column="Type":TEXT \
            --column="Nom":TEXT \
            --column="Compatibilité":TEXT \
            "${list_args[@]}" \
            --print-column=1 \
            --button="🔄 Rafraîchir:5" \
            --button="📂 Dossier:4" \
            --button="🌐 Navigateur:3" \
            --button="⬇ Download:0" \
            --button="Close:1" \
            --width=980 --height=580)
        ret=$?

        # Décoder le payload "URL|CAT|NOM"
        # YAD --print-column=1 ajoute un | séparateur final → on le strip d'abord
        local _url _cat _nom
        if [ -n "$sel" ]; then
            local _sel="${sel%|}"          # strip | final YAD
            _sel="${_sel%$'\n'}"           # strip newline éventuel
            _url="${_sel%%|*}"             # tout avant le premier |
            local _rest="${_sel#*|}"       # tout après le premier |
            _cat="${_rest%%|*}"            # CAT (avant le 2e |)
            _nom="${_rest#*|}"             # NOM (après le 2e |)
            _nom="${_nom%|}"              # strip | résiduel éventuel
        fi

        case $ret in
            1|252) break ;;

            5)  # Rafraîchir
                do_dl_manager
                return
                ;;

            4)  # Ouvrir le dossier selon la catégorie sélectionnée
                case "$_cat" in
                    kernel)        xdg-open "$DL_KERNELS_DIR"   & ;;
                    initramfs)     xdg-open "$DL_INITRAMFS_DIR" & ;;
                    distro|legacy) xdg-open "$DL_DISTROS_DIR"   & ;;
                    *)             xdg-open "$PROJECT_DIR/system" & ;;
                esac
                ;;

            3)  # Navigateur
                if [ -z "$sel" ]; then
                    xdg-open "https://dionkill.github.io/ps4-linux-tutorial/files.html" &
                else
                    [ -n "$_url" ] && xdg-open "$_url" &
                fi
                ;;

            0)  # Télécharger
                if [ -z "$sel" ]; then
                    yad_info "⚠  Sélectionnez d'abord une entrée dans la liste."
                    continue
                fi
                local _dest
                case "$_cat" in
                    kernel)        _dest="$DL_KERNELS_DIR" ;;
                    initramfs)     _dest="$DL_INITRAMFS_DIR" ;;
                    distro|legacy) _dest="$DL_DISTROS_DIR" ;;
                    *)             _dest="$PROJECT_DIR/system" ;;
                esac
                do_dl_dispatch "$_url" "$_dest" "$_nom" "$_cat"
                ;;
        esac
    done
}
export -f do_dl_manager

tab_downloads() {
    yad --plug="$KEY" --tabnum=13 \
        --form \
        --image="/usr/share/hybryde/SquareGlass/Download Manager.png" --image-on-top \
        --text="<big><b><span foreground='#4FC3F7'>⬇  PS4 Linux Downloads</span></b></big>
<span foreground='#81D4FA'>Live scraping · DionKill · Kernels, Initramfs, Distros</span>

<b>Automatic destinations:</b>
  🐧 Kernels    → <tt>$DL_KERNELS_DIR</tt>
  💾 Initramfs  → <tt>$DL_INITRAMFS_DIR</tt>
  📦 Distros    → <tt>$DL_DISTROS_DIR</tt>

<small><i>The list is read live from dionkill.github.io at each opening.
Mega.nz → mega-get (mega-cmd) · Forum / YouTube → automatic browser.
GitHub releases → asset selection via GitHub API.
Resume interrupted download: wget -c</i></small>\n" \
        \
        --field="":LBL "" \
        --field="<b>— Download manager —</b>":LBL "" \
        --field="  ⬇  Open manager (live scraping + YAD list)":BTN 'bash -c "do_dl_manager"' \
        --field="  <small><i>→ Scrapes dionkill.github.io · sort by type · size before download · resume wget -c</i></small>":LBL "" \
        \
        --field="":LBL "" \
        --field="<b>— Destination folders —</b>":LBL "" \
        --field="  📂 Open kernels  (<tt>system/kernels</tt>)":BTN "bash -c \"xdg-open '$DL_KERNELS_DIR' &\"" \
        --field="  📂 Open initramfs (<tt>system/initramfs</tt>)":BTN "bash -c \"xdg-open '$DL_INITRAMFS_DIR' &\"" \
        --field="  📂 Open distros  (<tt>system/distros</tt>)":BTN "bash -c \"xdg-open '$DL_DISTROS_DIR' &\"" \
        \
        --field="":LBL "" \
        --field="<b>— Source —</b>":LBL "" \
        --field="  🌐 dionkill.github.io/ps4-linux-tutorial/files.html":BTN 'bash -c "xdg-open https://dionkill.github.io/ps4-linux-tutorial/files.html &"' \
        --field="  <small><tt>https://dionkill.github.io/ps4-linux-tutorial/files.html</tt></small>":LBL "" \
        \
        "" "" "" "" "" "" "" "" "" "" "" "" \
        &
}

#========================================================================

#========================================================================
# TAB 11 — PS4 Linux Community
#========================================================================

do_open_url_dionkill() {
    xdg-open "https://dionkill.github.io/ps4-linux-tutorial/files.html" >/dev/null 2>&1 &
}
export -f do_open_url_dionkill

do_open_url_ps4linux() {
    xdg-open "https://ps4linux.com/downloads/#PS4_Linux_Kernel_Source" >/dev/null 2>&1 &
}
export -f do_open_url_ps4linux

tab_communaute() {
    yad --plug="$KEY" --tabnum=11 \
        --form --scroll \
        --image="/usr/share/hybryde/SquareGlass/Pidgin 2.png" --image-on-top \
        --text="<big><b><span foreground='#80CBC4'>🌍 Communauté PS4 Linux</span></b></big>
Community resources, tutorials, downloads and online help.\n" \
        \
        --field="":LBL "" \
        --field="<b>— Dionkill — PS4 Linux Tutorial —</b>":LBL "" \
        --field="  🌐 Open ps4-linux-tutorial (dionkill.github.io)":BTN 'bash -c "do_open_url_dionkill"' \
        --field="  <small><i>All In One for PS4: bzImage, initramfs, tutorials, ready-to-use files.</i></small>":LBL "" \
        \
        --field="":LBL "" \
        --field="<b>— noob404 — PS4Linux.com —</b>":LBL "" \
        --field="  🌐 Open ps4linux.com (noob404)":BTN 'bash -c "do_open_url_ps4linux"' \
        --field="  <small><i>Forum, help, tutorials, downloads and other PS4 Linux resources.</i></small>":LBL "" \
        \
        --field="":LBL "" \
        --field="<b>— Ps4-Linux-Warez (triki1 / Hybryde) —</b>":LBL "" \
        --field="  🎮 Open Ps4-Linux-Warez (hostps4.free.fr)":BTN 'bash -c "do_open_url_warez"' \
        --field="  <small><i>bzImages · Initramfs Vvsx87 · Distros (Elive, Debian Trixie, Xubuntu, Peppermint, Manjaro, Fedora 42)</i></small>":LBL "" \
        --field="  ⬇  Ps4-Linux-Warez download manager":BTN 'bash -c "do_warez_dl_manager"' \
        --field="  <small><tt>http://hostps4.free.fr/Ps4-Linux-Warez/index.html</tt></small>":LBL "" \
        \
        --field="":LBL "" \
        --field="<b>— Useful links —</b>":LBL "" \
        --field="  <small><tt>https://dionkill.github.io/ps4-linux-tutorial/files.html</tt></small>":LBL "" \
        --field="  <small><tt>https://ps4linux.com/downloads/#PS4_Linux_Kernel_Source</tt></small>":LBL "" \
        --field="  <small><tt>http://hostps4.free.fr/Ps4-Linux-Warez/index.html</tt></small>":LBL "" \
        \
        "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" \
        &
}

# LAUNCH TABS IN BACKGROUND
#========================================================================

# Tab 11 exports — all functions must be defined before this call
export -f do_git_ps4_kernel
export -f do_git_feernt_kernel
export -f do_git_orbis
export -f do_git_payloads
export -f do_payloads_readme
export -f do_git_kexec
export -f do_git_fail0verflow
export -f do_git_goldhen
export -f do_prepare_usb
export -f do_ftp_transfer
export -f do_edit_bootargs
export -f do_build_initramfs
export -f do_open_url_alazif
export -f do_open_project_dir
export -f tab_git_ps4


#========================================================================
# Ps4-Linux-Warez — Download Manager (live scraping from hostps4.free.fr)
# Pages : initramfs.html · bzimage.html · sous-pages distributions
#========================================================================

WAREZ_BASE_URL="http://hostps4.free.fr/Ps4-Linux-Warez"
export WAREZ_BASE_URL

do_open_url_warez() {
    xdg-open "$WAREZ_BASE_URL/index.html" >/dev/null 2>&1 &
}
export -f do_open_url_warez

do_warez_dl_manager() {
    local missing=()
    command -v curl    >/dev/null 2>&1 || missing+=("curl")
    command -v python3 >/dev/null 2>&1 || missing+=("python3")
    if [ ${#missing[@]} -gt 0 ]; then
        yad_err "Missing dependencies: <b>${missing[*]}</b>\n\n<tt>sudo apt install ${missing[*]}</tt>"
        return
    fi

    mkdir -p "$DL_KERNELS_DIR" "$DL_INITRAMFS_DIR" "$DL_DISTROS_DIR"

    # ── Spinner pendant le scraping ────────────────────────────────────
    local PID_W
    yad --center --borders=10 --title="Ps4-Linux-Warez…" \
        --text="🔄 <b>Scraping hostps4.free.fr/Ps4-Linux-Warez/…</b>\n\n<small>Fetching initramfs.html · bzimage.html · distributions…</small>" \
        --no-buttons --width=480 &
    PID_W=$!

    # ── Récupération des pages en parallèle ───────────────────────────
    local tmp_init tmp_bzimg tmp_review tmpdir_dist
    tmp_init=$(mktemp /tmp/hyb-warez-init-XXXX.html)
    tmp_bzimg=$(mktemp /tmp/hyb-warez-bz-XXXX.html)
    tmp_review=$(mktemp /tmp/hyb-warez-rev-XXXX.html)
    tmpdir_dist=$(mktemp -d /tmp/hyb-warez-dist-XXXX)

    curl -sL --max-time 15 "$WAREZ_BASE_URL/initramfs.html" -o "$tmp_init"  &
    local p1=$!
    curl -sL --max-time 15 "$WAREZ_BASE_URL/bzimage.html"   -o "$tmp_bzimg" &
    local p2=$!
    curl -sL --max-time 15 "$WAREZ_BASE_URL/review.html"    -o "$tmp_review" &
    local p3=$!

    # Stocker les PIDs des curls distros (ne PAS faire wait nu — bloquerait YAD)
    local distro_pids=()
    for _pg in elive.html debian-trixie.html xubuntu.html peppermint.html manjaro.html fedora.html; do
        curl -sL --max-time 10 "$WAREZ_BASE_URL/$_pg" -o "$tmpdir_dist/$_pg" 2>/dev/null &
        distro_pids+=($!)
    done

    wait $p1 $p2 $p3
    wait "${distro_pids[@]}"   # attend uniquement les curls distros, pas YAD

    # Fermer le spinner maintenant que tout est chargé
    kill "$PID_W" 2>/dev/null; wait "$PID_W" 2>/dev/null

    # ── Parser Python inline ───────────────────────────────────────────
    local tmppy
    tmppy=$(mktemp /tmp/hyb-warez-parse-XXXX.py)
    cat > "$tmppy" << 'PYEOF2'
#!/usr/bin/env python3
"""
Scraper Ps4-Linux-Warez
Args: initramfs.html  bzimage.html  review.html  distro_dir
TSV output: payload(url|cat|name) \t author \t label \t cat \t service
"""
import sys, re, os
from html.parser import HTMLParser

WAREZ_BASE = "http://hostps4.free.fr/Ps4-Linux-Warez"

class TblParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.tables = []
        self._t = self._r = self._c = None
        self._href = ''
    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == 'table':
            self._t = []
        elif tag == 'tr' and self._t is not None:
            self._r = []
        elif tag in ('td','th') and self._r is not None:
            self._c = ''; self._href = ''
        elif tag == 'a' and self._c is not None and not self._href:
            self._href = a.get('href','')
    def handle_endtag(self, tag):
        if tag == 'table' and self._t is not None:
            self.tables.append(self._t); self._t = None
        elif tag == 'tr' and self._r is not None and self._t is not None:
            if self._r: self._t.append(self._r)
            self._r = None
        elif tag in ('td','th') and self._c is not None and self._r is not None:
            self._r.append((re.sub(r'\s+',' ',self._c).strip(), self._href))
            self._c = None
    def handle_data(self, data):
        if self._c is not None:
            self._c += data

class LinkParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []
        self._t = None; self._h = ''
    def handle_starttag(self, tag, attrs):
        if tag == 'a':
            self._t = ''; self._h = dict(attrs).get('href','')
    def handle_endtag(self, tag):
        if tag == 'a' and self._t is not None:
            text = re.sub(r'\s+',' ',self._t).strip()
            if self._h: self.links.append((text, self._h))
            self._t = None
    def handle_data(self, data):
        if self._t is not None:
            self._t += data

def read(path):
    try:
        with open(path) as f: return f.read()
    except: return ''

def svc(url):
    if 'mega.nz'      in url: return 'Mega.nz'
    if '1fichier.com' in url: return '1fichier'
    if 'youtube.com'  in url: return 'YouTube'
    return 'Direct'

results = []

# ── initramfs.html ───────────────────────────────────────────────────
html = read(sys.argv[1])
if html:
    p = TblParser(); p.feed(html)
    for tbl in p.tables:
        for row in tbl:
            cols = [c[0] for c in row]
            hrefs= [c[1] for c in row]
            if any(h.lower() in ('auteurs','author','fichier','file') for h in cols):
                continue
            url = next((h for h in hrefs if h and ('mega.nz' in h or h.startswith('http'))), '')
            if not url: continue
            author = cols[0] if cols else 'Unknown'
            fname  = cols[2] if len(cols)>2 else 'initramfs.cpio.gz'
            results.append(('💾', author, fname, 'initramfs', svc(url), url))

# ── bzimage.html ─────────────────────────────────────────────────────
html = read(sys.argv[2])
if html:
    p = TblParser(); p.feed(html)
    for tbl in p.tables:
        for row in tbl:
            cols = [c[0] for c in row]
            hrefs= [c[1] for c in row]
            if any(h.lower() in ('auteurs','author','fichier','file','version') for h in cols):
                continue
            url = next((h for h in hrefs if h and ('mega.nz' in h or h.startswith('http'))), '')
            if not url: continue
            author  = cols[0] if cols else 'Unknown'
            version = cols[1] if len(cols)>1 else ''
            fname   = cols[2] if len(cols)>2 else 'bzImage'
            label   = f"{fname}  [{version}]" if version else fname
            results.append(('🐧', author, label, 'kernel', svc(url), url))

# ── distro sub-pages ─────────────────────────────────────────────────
distro_dir = sys.argv[4]
distro_names = {
    'elive.html':        'Elive Trixie PS4  [9,6 Go]',
    'debian-trixie.html':'Debian Trixie PS4  [33,7 Go]',
    'xubuntu.html':      'Xubuntu PS4  [19,7 Go]',
    'peppermint.html':   'Peppermint OS PS4  [2,7 Go]',
    'manjaro.html':      'Manjaro PS4  [2,3 Go]',
    'fedora.html':       'Fedora 42 PS4  [7,6 Go]',
}
for fname_pg, label in distro_names.items():
    html = read(os.path.join(distro_dir, fname_pg))
    if not html: continue
    lp = LinkParser(); lp.feed(html)
    for text, href in lp.links:
        if href and ('mega.nz' in href or '1fichier.com' in href):
            results.append(('📦', 'triki1', label, 'distro', svc(href), href))
            break

# ── TSV output ───────────────────────────────────────────────────────
for icon, author, name, cat, service, url in results:
    payload = f"{url}|{cat}|{name}"
    print('\t'.join([payload, author, name, cat, service]))
PYEOF2
    chmod +x "$tmppy"

    # Lancer le parser
    local tsv
    tsv=$(python3 "$tmppy" "$tmp_init" "$tmp_bzimg" "$tmp_review" "$tmpdir_dist" 2>/dev/null)
    rm -f "$tmppy" "$tmp_init" "$tmp_bzimg" "$tmp_review"
    rm -rf "$tmpdir_dist"

    # ── Fallback hardcodé si scraping échoue ──────────────────────────
    if [ -z "$tsv" ]; then
        tsv="https://mega.nz/file/uAg3BbhL#V0uv9iGJ8IKq1oNI5Cxh_1owm2KgaJ0OoLC0_aPuJKU|initramfs|initramfs.cpio.gz [K5→7.x]	Vvsx87	initramfs.cpio.gz  [Kernel 5→7.x]	initramfs	Mega.nz
https://mega.nz/file/zUB1AADK#Z3uVxAMFuNBV03e6JvFmqdQ5fnegq1hCk32cUvPqrq0|kernel|bzImage [K5.4.213]	Saya	bzImage  [Kernel 5.4.213]	kernel	Mega.nz
https://mega.nz/file/g1gkkTaC#zAEddjeh7sDXs65o2MvFmgvIXFQjgJRZdORShmkgJ8Q|kernel|bzImage [K6.12.11]	triki1	bzImage  [Kernel 6.12.11]	kernel	Mega.nz
https://mega.nz/file/TE4HmCIR#dKiGi6xbQL8v5BJOmBLL_xt-vxdWyJiMEsI6wRCbl2o|kernel|bzImage [K6.8.12]	Saya	bzImage  [Kernel 6.8.12]	kernel	Mega.nz
https://mega.nz/file/zRx3zSDQ#CUUNqZbnuBGU62ySdd8dngQ6ZvnkIwrF1uc1JTjLzuc|kernel|bzImage [K6.15.4]	Saya	bzImage  [Kernel 6.15.4]	kernel	Mega.nz
https://mega.nz/file/l5BCnTJB#aq5E3GjaF0vIeqboew3M9aQi1cYQzeivBtSXzKBy23I|kernel|bzImage [K6.15.4 jaguar]	triki1	bzImage  [Kernel 6.15.4 Jaguar FullLTO]	kernel	Mega.nz
https://mega.nz/folder/G90y2bwB#PMcHGaTF6vxiBQvInFmi8w|distro|Elive Trixie PS4 [9,6 Go]	triki1	Elive Trixie PS4  [9,6 Go]	distro	Mega.nz
https://mega.nz/file/KV5QFZBZ#Rj0RtOfuGgdSeNLouyKfSCpua2iJzbc__0e4nAfrars|distro|Peppermint OS PS4 [2,7 Go]	triki1	Peppermint OS PS4  [2,7 Go]	distro	Mega.nz
https://mega.nz/file/3Zhw3ZZA#6xhFTmx1rquzQwpOYIrB_Z_LsnrX4Qx2GOQz9pa0tcY|distro|Manjaro PS4 [2,3 Go]	triki1	Manjaro PS4  [2,3 Go]	distro	Mega.nz
https://mega.nz/file/uRoTFb5T#5PxBuwCPV33l_4llVu9KIeWzLkaX2gC7aGcyHBKqJkI|distro|Fedora 42 PS4 [7,6 Go]	triki1	Fedora 42 PS4  [7,6 Go]	distro	Mega.nz
https://1fichier.com/?mi34bnkq59qae0scs9h0|distro|Debian Trixie PS4 [33,7 Go]	triki1	Debian Trixie PS4  [33,7 Go]	distro	1fichier
https://1fichier.com/?at7ccs9f5rb9spzkm8h9|distro|Xubuntu PS4 [19,7 Go]	triki1	Xubuntu PS4  [19,7 Go]	distro	1fichier"
    fi

    # ── Construction des arguments YAD ────────────────────────────────
    local yad_args=()
    while IFS=$'\t' read -r payload author name cat service; do
        [ -z "$payload" ] && continue
        local _cat="${payload#*|}"; _cat="${_cat%%|*}"
        local icon
        case "$_cat" in
            kernel)    icon="🐧" ;;
            initramfs) icon="💾" ;;
            distro)    icon="📦" ;;
            *)         icon="📁" ;;
        esac
        yad_args+=("$payload" "$icon" "$author" "$name" "$service")
    done <<< "$tsv"

    # ── Boucle principale d'affichage ─────────────────────────────────
    while true; do
        local sel ret
        sel=$(yad --center --borders=10 \
            --title="⬇  Ps4-Linux-Warez — Téléchargements" \
            --list \
            --text="<big><b><span foreground='#4FC3F7'>⬇  Ps4-Linux-Warez — Téléchargements</span></b></big>
<span foreground='#81D4FA'><b>hostps4.free.fr</b> · bzImages · Initramfs Vvsx87 · Distributions triki1</span>
<small>🐧 kernel → $DL_KERNELS_DIR
💾 initramfs → $DL_INITRAMFS_DIR
📦 distro → $DL_DISTROS_DIR
Mega.nz → mega-get (mega-cmd) · 1fichier → navigateur</small>\n" \
            --column="PAYLOAD:HD" \
            --column="Type" \
            --column="Auteur" \
            --column="Nom / Version" \
            --column="Service" \
            --print-column=1 --separator="|" \
            "${yad_args[@]}" \
            --button="🔄 Rafraîchir:5" \
            --button="📂 Dossier:4" \
            --button="🌐 Site web:3" \
            --button="⬇ Télécharger:0" \
            --button="Close:1" \
            --width=970 --height=560)
        ret=$?

        local _url _cat _nom
        if [ -n "$sel" ]; then
            local _sel="${sel%|}"; _sel="${_sel%$'\n'}"
            _url="${_sel%%|*}"
            local _rest="${_sel#*|}"
            _cat="${_rest%%|*}"
            _nom="${_rest#*|}"; _nom="${_nom%|}"
        fi

        case $ret in
            1|252) break ;;

            5)  # Rafraîchir
                do_warez_dl_manager
                return ;;

            4)  # Ouvrir dossier
                case "$_cat" in
                    kernel)    xdg-open "$DL_KERNELS_DIR"   & ;;
                    initramfs) xdg-open "$DL_INITRAMFS_DIR" & ;;
                    distro)    xdg-open "$DL_DISTROS_DIR"   & ;;
                    *)         xdg-open "$PROJECT_DIR/system" & ;;
                esac ;;

            3)  # Navigateur
                if [ -n "$_url" ]; then
                    xdg-open "$_url" &
                else
                    xdg-open "$WAREZ_BASE_URL/index.html" &
                fi ;;

            0)  # Télécharger
                if [ -z "$sel" ]; then
                    yad_info "⚠  Sélectionnez d'abord une entrée dans la liste."
                    continue
                fi
                local _dest
                case "$_cat" in
                    kernel)    _dest="$DL_KERNELS_DIR" ;;
                    initramfs) _dest="$DL_INITRAMFS_DIR" ;;
                    distro)    _dest="$DL_DISTROS_DIR" ;;
                    *)         _dest="$PROJECT_DIR/system" ;;
                esac
                if [[ "$_url" =~ 1fichier\.com ]]; then
                    yad_info "🌐 <b>1fichier.com</b>\n\nCe lien s'ouvre dans le navigateur.\nTéléchargez manuellement vers :\n<tt>$_dest</tt>\n\n<tt>$_url</tt>"
                    xdg-open "$_url" &
                else
                    do_dl_dispatch "$_url" "$_dest" "$_nom" "$_cat"
                fi ;;
        esac
    done
}
export -f do_warez_dl_manager

# Community tab exports
export -f do_open_url_dionkill
export -f do_open_url_ps4linux
export -f do_open_url_warez
export -f do_warez_dl_manager
export -f tab_communaute

# Tab 13 exports — DionKill downloads
export -f do_dl_fmt_size
export -f do_dl_get_size
export -f do_dl_wget
export -f do_dl_github_assets
export -f do_dl_pick_github
export -f do_dl_dispatch
export -f do_dl_manager
export -f tab_downloads

#========================================================================
# TAB 14 — Credits & Acknowledgements
#========================================================================

tab_credits() {
    yad --plug="$KEY" --tabnum=6 \
        --form --scroll \
        --image="/usr/share/hybryde/SquareGlass/Pidgin 2.png" --image-on-top \
        --text="<big><b><span foreground='#FFD54F'>🏆 Credits &amp; Acknowledgements</span></b></big>
<span foreground='#FFF9C4'><i>Hybryde PS4 Tools — made with passion for the PS4 Linux community</i></span>\n" \
        \
        --field="":LBL "" \
        --field="<b><span foreground='#FFD54F'>— PS4 Linux Developers —</span></b>":LBL "" \
        \
        --field="  🐙 <b>Thanks</b>":LBL "" \
        --field="  <small>Thank you to all the developers in the PS4 scene.\n  Too many people to mention, so a big thank you to everyone, it allows me to make sure I don't forget anyone.</small>":LBL "" \
        \
        --field="":LBL "" \
        --field="<b><span foreground='#FFD54F'>— Hybryde PS4 Tools —</span></b>":LBL "" \
        --field="  <small><b>Auteur :</b> Triki1 · Amiga Warez Community\n  <b>Objectif :</b> simplifying work on PS4 Linux for everyone\n  from beginner to kernel developer.\n\n  <i>This project is a tribute to all those who gave their time to open the PlayStation 4 to the free world.</i>\n\n  🐧 <b>Long live Linux on PS4!</b> 🎮</small>":LBL "" \
        \
        --field="":LBL "" \
        --field="  🌐 Dionkill — Tutorial":BTN 'bash -c "xdg-open https://dionkill.github.io/ps4-linux-tutorial/ &"' \
        --field="  🌍 PS4Linux.com":BTN 'bash -c "xdg-open https://ps4linux.com &"' \
        \
        "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" \
        &
}
export -f tab_credits

#========================================================================
# TAB 5 — Hub (Community + Docs + Downloads)
#========================================================================

tab_hub() {
    # ── Build doc fields dynamically ────────────────────────────────
    local fields_docs=()
    for i in "${!AIDE_LABELS[@]}"; do
        local lbl="${AIDE_LABELS[$i]}"
        local fpath="${AIDE_PATHS[$i]/#\~/$HOME}"
        local exist_icon
        [ -f "$fpath" ] && exist_icon="📄" || exist_icon="<span foreground='${C_WARN}'>⚠ </span>"
        fields_docs+=(
            --field="${exist_icon} <b>${lbl}</b>  —  🔍 Aperçu":BTN "bash -c \"preview_pdf '${fpath}'\""
            --field="   📂 Ouvrir dans le lecteur PDF":BTN "bash -c \"xdg-open '${fpath}' >/dev/null 2>&1 &\""
        )
    done

    yad --plug="$KEY" --tabnum=5 \
        --form --scroll \
        --image="/usr/share/hybryde/SquareGlass/Pidgin 2.png" --image-on-top \
        --text="<big><b><span foreground='${C_HUB}'>🌍 PS4 Linux Hub</span></b></big>
<span foreground='${C_SECTION}'>Community  ·  Ps4-Linux-Warez  ·  DionKill  ·  Documentation</span>\n" \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ 🌍 Community ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</span></b>":LBL "" \
        \
        --field="  🎮 <b>triki1</b> — Ps4-Linux-Warez (bzImages, Initramfs, Distros)":BTN \
            'bash -c "do_open_url_warez"' \
        --field="  <small><tt>http://hostps4.free.fr/Ps4-Linux-Warez/index.html</tt></small>":LBL "" \
        \
        --field="  📖 <b>Dionkill</b> — PS4 Linux Tutorial (All-In-One)":BTN \
            'bash -c "do_open_url_dionkill"' \
        --field="  <small><tt>https://dionkill.github.io/ps4-linux-tutorial/</tt></small>":LBL "" \
        \
        --field="  🌍 <b>noob404</b> — PS4Linux.com (forum, help, resources)":BTN \
            'bash -c "do_open_url_ps4linux"' \
        --field="  <small><tt>https://ps4linux.com</tt></small>":LBL "" \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ 🎮 Ps4-Linux-Warez Downloads (triki1) ━━━━━━━━━━━━━━━━━━━━</span></b>":LBL "" \
        --field="  <small>bzImages (Saya/triki1/Dr4kk3n) · Initramfs Vvsx87 · Distros (Elive, Debian, Xubuntu, Peppermint, Manjaro, Fedora)</small>":LBL "" \
        --field="  <small>Kernels → <tt>$DL_KERNELS_DIR</tt></small>":LBL "" \
        --field="  <small>Initramfs → <tt>$DL_INITRAMFS_DIR</tt></small>":LBL "" \
        --field="  <small>Distros → <tt>$DL_DISTROS_DIR</tt></small>":LBL "" \
        --field="  ⬇  Open Ps4-Linux-Warez manager (live scraping)":BTN \
            'bash -c "do_warez_dl_manager"' \
        --field="  🌐 Open hostps4.free.fr/Ps4-Linux-Warez":BTN \
            'bash -c "do_open_url_warez"' \
        --field="  📂 Open downloads folder":BTN \
            "bash -c \"xdg-open '$PROJECT_DIR/system' &\"" \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ ⬇  DionKill Downloads ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</span></b>":LBL "" \
        --field="  <small>Kernels → <tt>$DL_KERNELS_DIR</tt></small>":LBL "" \
        --field="  <small>Initramfs → <tt>$DL_INITRAMFS_DIR</tt></small>":LBL "" \
        --field="  <small>Distros → <tt>$DL_DISTROS_DIR</tt></small>":LBL "" \
        --field="  ⬇  Open DionKill manager (live scraping + list)":BTN \
            'bash -c "do_dl_manager"' \
        --field="  📂 Open system/ folder":BTN \
            "bash -c \"xdg-open '$PROJECT_DIR/system' &\"" \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ 📖 PDF Documentation ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</span></b>":LBL "" \
        --field="  <small>🔍 Preview = page 1 text + viewer button  ·  📂 Open = direct PDF reader</small>":LBL "" \
        "${fields_docs[@]}" \
        \
        "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" \
        &
}
export -f tab_hub

#========================================================================
# LAUNCH TABS IN BACKGROUND
#========================================================================

# Infrastructure exports
export -f log_entry
export -f do_show_logs
export -f do_open_settings
export -f notify_ps4
export -f do_check_deps_full

# Dashboard tab exports
export -f tab_dashboard

# System tab exports
export -f tab_systeme

# Mesa dev tab exports
export -f tab_mesa_dev

# Kernel boot tab exports
export -f tab_kernel_boot

# Tab 11 exports — git functions (already exported above)
export -f do_git_ps4_kernel
export -f do_git_feernt_kernel
export -f do_git_orbis
export -f do_git_payloads
export -f do_payloads_readme
export -f do_git_kexec
export -f do_git_fail0verflow
export -f do_git_goldhen
export -f do_prepare_usb
export -f do_ftp_transfer
export -f do_edit_bootargs
export -f do_build_initramfs
export -f do_open_url_alazif
export -f do_open_project_dir
export -f tab_git_ps4

# Community tab exports / hub
export -f do_open_url_dionkill
export -f do_open_url_ps4linux
export -f do_open_url_warez
export -f do_warez_dl_manager
export -f tab_communaute
export -f tab_hub

# Tab 13 exports — DionKill downloads
export -f do_dl_fmt_size
export -f do_dl_get_size
export -f do_dl_wget
export -f do_dl_github_assets
export -f do_dl_pick_github
export -f do_dl_dispatch
export -f do_dl_manager
export -f tab_downloads

# Credits exports
export -f tab_credits

# ── Parallel launch ─────────────────────────────────────────────────
tab_dashboard   &
tab_systeme     &
tab_mesa_dev    &
tab_kernel_boot &
tab_hub         &
tab_credits     &

#========================================================================
# MAIN WINDOW
#========================================================================

yad --notebook \
    --window-icon="applications-system" \
    --title="Hybryde PS4 Tools v2.0" \
    --width=1000 --height=740 \
    --image="$LOGO" \
    --image-on-top \
    --text="<span size='x-large'><b><span foreground='${C_TITRE}'>Hybryde PS4 Tools</span></b></span>  <small><span foreground='${C_SECTION}'>v2.0 — by Triki1</span></small>
<small><span foreground='${C_SECTION}'>Dashboard  ·  System  ·  Mesa &amp; Dev  ·  Kernel &amp; Boot  ·  Hub  ·  Credits</span></small>" \
    --button="⚙ Preferences:2" \
    --button="📋 Logs:3" \
    --button="Close:0" \
    --key="$KEY" \
    --tab="🏠 Dashboard" \
    --tab="💿 System &amp; Storage" \
    --tab="🔧 Mesa &amp; Dev" \
    --tab="🐧 Kernel &amp; Boot" \
    --tab="🌍 PS4 Linux Hub" \
    --tab="🏆 Credits" \
    --active-tab=1

ret=$?
case $ret in
    2) do_open_settings ;;
    3) do_show_logs     ;;
esac
