#!/bin/bash

#========================================================================
# hybryde-ps4-tools.sh — Hybryde PS4 Tools
# Interface YAD multi-onglets pour outils PS4 Linux
# Version : 1.1 — 2026
# By triki1
#========================================================================

preview_pdf() {
    local FILE="${1/#\~/$HOME}"

    if [ ! -f "$FILE" ]; then
        yad_err "Fichier introuvable :\n<tt>$FILE</tt>"
        return
    fi

    local TMPTXT TMPIMG IMG_FILE
    TMPTXT=$(mktemp)
    TMPIMG=$(mktemp --suffix=.png)

    # Extraire texte (rapide, page 1 seulement)
    if command -v pdftotext >/dev/null 2>&1; then
        pdftotext -l 1 "$FILE" "$TMPTXT" 2>/dev/null
    else
        echo "pdftotext non installé (sudo apt install poppler-utils)" > "$TMPTXT"
    fi

    # Générer aperçu image (page 1)
    if command -v pdftoppm >/dev/null 2>&1; then
        pdftoppm -f 1 -l 1 -png "$FILE" "${TMPIMG%.png}" 2>/dev/null
        IMG_FILE="${TMPIMG%.png}-1.png"
    fi

    yad --title="Aperçu PDF — $(basename "$FILE")" \
        --width=640 --height=480 \
        --center \
        --text-info --scroll \
        --filename="$TMPTXT" \
        ${IMG_FILE:+--image="$IMG_FILE" --image-on-top} \
        --button="📂 Ouvrir dans le lecteur:0" \
        --button="Fermer:1"

    local ret=$?
    rm -f "$TMPTXT" "$TMPIMG"* 2>/dev/null

    # Bouton "Ouvrir" → lancer le lecteur PDF par défaut
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
mkdir -p "$KERNELS_DIR"   # orbis créé uniquement à l'installation (do_git_orbis)

#--- Répertoires de téléchargements DionKill ---
DL_KERNELS_DIR="$PROJECT_DIR/system/kernels"
DL_INITRAMFS_DIR="$PROJECT_DIR/system/initramfs"
DL_DISTROS_DIR="$PROJECT_DIR/system/distros"
mkdir -p "$DL_KERNELS_DIR" "$DL_INITRAMFS_DIR" "$DL_DISTROS_DIR"
export DL_KERNELS_DIR DL_INITRAMFS_DIR DL_DISTROS_DIR
# ── Fichiers d'état inter-dialogs ──────────────────────────────────────
TAR_EXCLUDES_FILE="$CONF_DIR/tar-excludes.txt"
TAR_NAME_FILE="$CONF_DIR/tar-name.txt"
TAR_CMD_FILE="$CONF_DIR/tar-cmd.txt"
IMG_PATH_FILE="$CONF_DIR/img-path.txt"
EXT_SRC_FILE="$CONF_DIR/extract-src.txt"
EXT_DST_FILE="$CONF_DIR/extract-dst.txt"
BUILD_CMD_FILE="$CONF_DIR/build-cmd.txt"

# ── Valeurs par défaut ─────────────────────────────────────────────────
[ ! -f "$TAR_NAME_FILE" ]     && echo "ps4linux.tar.xz" > "$TAR_NAME_FILE"
[ ! -f "$TAR_EXCLUDES_FILE" ] && printf "/var/cache\n"   > "$TAR_EXCLUDES_FILE"
[ ! -f "$BUILD_CMD_FILE" ]    && echo "./mesa-build.py --apt-auto 1 --incremental 0 --git-pull 1 --llvm=off --gallium-drivers=radeonsi,r600 --vulkan-drivers=amd --buildopencl 0" > "$BUILD_CMD_FILE"

# ── Détection du terminal ──────────────────────────────────────────────
TERM_BIN="xterm"
for t in xfce4-terminal gnome-terminal mate-terminal xterm; do
    command -v "$t" &>/dev/null && TERM_BIN="$t" && break
done

#========================================================================
# UTILITAIRES
#========================================================================

run_in_term() {
    local title="$1" cmd="$2"
    # Tmpscript pour éviter tout problème de guillemets dans les commandes complexes
    local tmpscript
    tmpscript=$(mktemp /tmp/hyb-term-XXXX.sh)
    printf '#!/bin/bash\n%s\necho\nread -rp "[Entrée pour fermer]"\nrm -f "%s"\n' \
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
        gnome-terminal) gnome-terminal --title="$title" -- bash -c "sudo bash -c \"$cmd\"; echo; read -rp '[Entrée pour fermer]'; exit" ;;
        mate-terminal)  mate-terminal  --title="$title" -e "bash -c 'sudo bash -c \"$cmd\"; echo; read -rp \"[Entrée pour fermer]\"; exit'" ;;
        *)              xterm -title "$title" -e bash -c "sudo bash -c \"$cmd\"; echo; read -rp '[Entrée pour fermer]'; exit" ;;
    esac
}
export -f run_sudo_in_term

yad_err() {
    yad --center --borders=10 --window-icon="dialog-error" \
        --title="Erreur" --image="dialog-error" \
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
        --text="$1" --button="Non:1" --button="Oui:0" --width=500
}
export -f yad_confirm

export KEY LOGO TERM_BIN CONF_DIR
export TAR_EXCLUDES_FILE TAR_NAME_FILE TAR_CMD_FILE
export IMG_PATH_FILE EXT_SRC_FILE EXT_DST_FILE BUILD_CMD_FILE

#========================================================================
# PALETTE COULEURS UNIFIÉE
#========================================================================
C_TITRE='#4FC3F7'      # Bleu PS4 — titres principaux
C_SECTION='#90A4AE'    # Gris ardoise — séparateurs de section
C_OK='#81C784'         # Vert — succès / disponible
C_WARN='#FFB74D'       # Orange — avertissement
C_ERR='#EF9A9A'        # Rouge doux — erreur
C_KERNEL='#C5E1A5'     # Vert clair — kernel
C_MESA='#FFCC80'       # Orange clair — Mesa
C_SYS='#CE93D8'        # Violet — système/stockage
C_HUB='#80CBC4'        # Cyan — hub/communauté
C_GOLD='#FFD54F'       # Or — crédits
export C_TITRE C_SECTION C_OK C_WARN C_ERR C_KERNEL C_MESA C_SYS C_HUB C_GOLD

#========================================================================
# CONFIGURATION PERSISTANTE
#========================================================================
PS4_CONF="$CONF_DIR/config.conf"
# Valeurs par défaut si absentes
if [ ! -f "$PS4_CONF" ]; then
    cat > "$PS4_CONF" << 'CONFEOF'
# Hybryde PS4 Tools — configuration persistante
PS4_IP=192.168.1.xxx
PS4_FW=11.00
MESA_SRC_DIR=~/mesa-git
LIBDRM_SRC_DIR=~/libdrm-git
NOTIFY_ENABLED=yes
LOG_ENABLED=yes
CONFEOF
fi
# Charger la config (ignorer les erreurs)
# shellcheck source=/dev/null
source "$PS4_CONF" 2>/dev/null || true
export PS4_CONF PS4_IP PS4_FW NOTIFY_ENABLED LOG_ENABLED

#========================================================================
# LOGS CENTRALISÉS
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
        yad_info "📋 Aucun log disponible pour l'instant.\n\n<small><tt>$LOG_FILE</tt></small>"
        return
    fi
    # Afficher les 500 dernières lignes dans yad --text-info
    local tmplog
    tmplog=$(mktemp /tmp/hyb-log-XXXX.txt)
    tail -500 "$LOG_FILE" > "$tmplog"
    yad --center --borders=10 \
        --title="📋 Logs PS4 Tools" \
        --text-info --filename="$tmplog" \
        --width=900 --height=540 \
        --button="🗑 Effacer les logs:2" \
        --button="📂 Ouvrir le fichier:3" \
        --button="Fermer:1"
    local ret=$?
    rm -f "$tmplog"
    case $ret in
        2) > "$LOG_FILE"
           log_entry "LOGS" "Journal effacé par l'utilisateur"
           yad_info "✓ Logs effacés." ;;
        3) xdg-open "$LOG_FILE" & ;;
    esac
}
export -f do_show_logs

do_open_settings() {
    local out
    out=$(yad --center --borders=10 --title="⚙  Préférences PS4 Tools" \
        --form \
        --text="<big><b><span foreground='${C_TITRE}'>⚙  Préférences</span></b></big>\n<small>Sauvegardées dans <tt>$PS4_CONF</tt></small>\n" \
        --field="Adresse IP de la PS4 :":TEXT         "${PS4_IP:-192.168.1.xxx}" \
        --field="Firmware PS4 :":TEXT                 "${PS4_FW:-11.00}" \
        --field="Dossier sources Mesa :":DIR           "${MESA_SRC_DIR:-$HOME/mesa-git}" \
        --field="Dossier sources libdrm :":DIR         "${LIBDRM_SRC_DIR:-$HOME/libdrm-git}" \
        --field="Notifications système (notify-send) :":CHK "${NOTIFY_ENABLED:-yes}" \
        --field="Journalisation (logs) :":CHK          "${LOG_ENABLED:-yes}" \
        --button="Annuler:1" --button="💾 Sauvegarder:0" \
        --width=560)
    [ $? -ne 0 ] || [ -z "$out" ] && return
    IFS='|' read -r _ip _fw _mesa _libdrm _notif _logs <<< "$out"
    cat > "$PS4_CONF" << CONFEOF
# Hybryde PS4 Tools — configuration persistante
PS4_IP=${_ip}
PS4_FW=${_fw}
MESA_SRC_DIR=${_mesa}
LIBDRM_SRC_DIR=${_libdrm}
NOTIFY_ENABLED=$( [ "$_notif" = "TRUE" ] && echo yes || echo no )
LOG_ENABLED=$( [ "$_logs"  = "TRUE" ] && echo yes || echo no )
CONFEOF
    source "$PS4_CONF" 2>/dev/null || true
    export PS4_IP PS4_FW MESA_SRC_DIR LIBDRM_SRC_DIR NOTIFY_ENABLED LOG_ENABLED
    log_entry "CONFIG" "Préférences sauvegardées (IP=$_ip FW=$_fw)"
    yad_info "✓ Préférences sauvegardées."
}
export -f do_open_settings

#========================================================================
# NOTIFICATIONS SYSTÈME
#========================================================================
notify_ps4() {
    # notify_ps4 "Titre" "Message" ["ok"|"warn"|"err"]
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
# VÉRIFICATION GLOBALE DES DÉPENDANCES
#========================================================================
DEPS_STATUS_FILE="$LOG_DIR/deps-status.txt"
export DEPS_STATUS_FILE

do_check_deps_full() {
    # Génère $DEPS_STATUS_FILE et renvoie un résumé lisible
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
    _chk "parted"       parted      parted
    _chk "mkfs.vfat"    mkfs.vfat   dosfstools
    _chk "mkfs.ext4"    mkfs.ext4   e2fsprogs
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

    local txt="<b>Dépendances vérifiées — $(date '+%H:%M')</b>\n\n"
    txt+="<b><span foreground='${C_OK}'>✓ Disponibles (${#ok[@]})</span></b>\n"
    for x in "${ok[@]}";   do txt+="  <span foreground='${C_OK}'>✓</span>  $x\n"; done
    txt+="\n"
    if [ ${#fail[@]} -gt 0 ]; then
        txt+="<b><span foreground='${C_ERR}'>✗ Manquantes (${#fail[@]})</span></b>\n"
        for x in "${fail[@]}"; do txt+="  <span foreground='${C_ERR}'>✗</span>  $x\n"; done
    else
        txt+="<span foreground='${C_OK}'><b>✓ Toutes les dépendances sont présentes !</b></span>\n"
    fi

    yad --center --borders=10 \
        --title="Vérification des dépendances" \
        --text="$txt" \
        --image="dialog-information" \
        --button="OK:0" --width=560

    log_entry "DEPS" "Check: ${#ok[@]} OK, ${#fail[@]} manquantes"
}
export -f do_check_deps_full

# Check silencieux au démarrage (génère DEPS_STATUS_FILE en tâche de fond)
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
# ONGLET 1 — Compiler Mesa
#========================================================================

do_edit_script() {
    command -v geany &>/dev/null || {
        yad_err "Geany n'est pas installé.\n<b>sudo apt install geany</b>"
        return
    }
    local script
    script=$(yad --center --borders=10 \
        --title="Sélectionner un script à éditer" \
        --file --filename="$HOME/" \
        --file-filter="Scripts | *.sh *.py *.bash *.pl" \
        --button="Annuler:1" --button="Ouvrir dans Geany:0" \
        --width=860 --height=540)
    [ $? -ne 0 ] || [ -z "$script" ] && return
    [ ! -f "$script" ] && yad_err "Fichier introuvable." && return
    geany "$script" &
}
export -f do_edit_script

do_patch_mesa() {
    local mesa_dir="$HOME/mesa-git"
    [ ! -d "$mesa_dir" ] && yad_err "Dossier introuvable : <tt>$mesa_dir</tt>\nVérifiez que les sources Mesa sont clonées." && return

    local patch
    patch=$(yad --center --borders=10 \
        --title="Sélectionner le patch Mesa" \
        --file --filename="$mesa_dir/" \
        --file-filter="Patches | *.patch *.diff" \
        --button="Annuler:1" --button="Sélectionner:0" \
        --width=860 --height=540)
    [ $? -ne 0 ] || [ -z "$patch" ] && return
    [ ! -f "$patch" ] && yad_err "Fichier patch introuvable." && return

    local pname drylog
    pname=$(basename "$patch")
    drylog="$CONF_DIR/mesa-dryrun.log"

    run_in_term "Dry-run Mesa — $pname" \
        "cd '$mesa_dir' && patch -p1 --dry-run < '$patch' 2>&1 | tee '$drylog'; echo; echo '=== Dry-run terminé ==='; read -rp '[Entrée pour continuer]'"

    yad_confirm "Dry-run terminé.\nLog : <tt>$drylog</tt>\n\nAppliquer le patch <b>$pname</b> au dépôt Mesa ?" || return
    run_in_term "Appliquer patch Mesa — $pname" \
        "cd '$mesa_dir' && patch -p1 < '$patch'"
}
export -f do_patch_mesa

do_patch_libdrm() {
    local drm_dir="$HOME/libdrm-git"
    [ ! -d "$drm_dir" ] && yad_err "Dossier introuvable : <tt>$drm_dir</tt>\nVérifiez que les sources libdrm sont clonées." && return

    local patch
    patch=$(yad --center --borders=10 \
        --title="Sélectionner le patch libdrm" \
        --file --filename="$drm_dir/" \
        --file-filter="Patches | *.patch *.diff" \
        --button="Annuler:1" --button="Sélectionner:0" \
        --width=860 --height=540)
    [ $? -ne 0 ] || [ -z "$patch" ] && return
    [ ! -f "$patch" ] && yad_err "Fichier patch introuvable." && return

    local pname drylog
    pname=$(basename "$patch")
    drylog="$CONF_DIR/libdrm-dryrun.log"

    run_in_term "Dry-run libdrm — $pname" \
        "cd '$drm_dir' && patch -p1 --dry-run < '$patch' 2>&1 | tee '$drylog'; echo; echo '=== Dry-run terminé ==='; read -rp '[Entrée pour continuer]'"

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
        yad_confirm "mesa-build.py existe déjà :\n<tt>$dest</tt>\n\nMise à jour depuis le gist de baryluk ?" || return
    fi

    if ! command -v curl >/dev/null 2>&1; then
        yad_err "curl est requis.\n<b>sudo apt install curl</b>"
        return
    fi

    local tmpscript
    tmpscript=$(mktemp /tmp/hyb-baryluk-XXXX.sh)
    cat > "$tmpscript" << BEOF
#!/bin/bash
echo '=== Téléchargement mesa-build.py (baryluk) ==='
echo "Source  : $raw_url"
echo "Cible   : $dest"
echo ''

curl -L --progress-bar "$raw_url" -o "$dest"
if [ \$? -ne 0 ] || [ ! -s "$dest" ]; then
    echo ''
    echo '✗ Téléchargement échoué'
    echo "  Vérifiez votre connexion ou ouvrez manuellement :"
    echo "  $gist_url"
    rm -f "$dest"
    read -rp '[Entrée pour fermer]'
    exit 1
fi

chmod +x "$dest"
echo ''
echo "✓ mesa-build.py téléchargé et rendu exécutable"
echo "  Emplacement : $dest"
echo ''
echo '--- Début du script (10 premières lignes) ---'
head -10 "$dest"
echo '...'
echo ''
echo "Utilisation : cd ~/mesa-git && python3 $dest [options]"
echo ''
read -rp '[Entrée pour fermer]'
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
        yad_info "✓ mesa-build.py installé :\n<tt>$dest</tt>\n\n<small>Gist original : $gist_url</small>"
}
export -f do_get_mesa_build_baryluk
do_manual_build() {
    local last_cmd
    last_cmd=$(cat "$BUILD_CMD_FILE" 2>/dev/null)
    [ -z "$last_cmd" ] && last_cmd="./mesa-build.py"

    local out
    out=$(yad --center --borders=10 \
        --title="Commande manuelle Mesa" \
        --form \
        --text="<b>Commande de build Mesa</b>\n\nLe répertoire de travail sera : <tt>~/mesa-git</tt>\nModifiez la commande puis cliquez sur Lancer.\n" \
        --field="Commande :":TEXT "$last_cmd" \
        --button="Annuler:1" --button="🚀 Lancer:0" \
        --width=840 --height=220)
    [ $? -ne 0 ] || [ -z "$out" ] && return

    local cmd
    cmd=$(echo "$out" | cut -d'|' -f1)
    echo "$cmd" > "$BUILD_CMD_FILE"
    run_in_term "Build Mesa (manuel)" "cd '$HOME' && $cmd"
}
export -f do_manual_build

tab_mesa() { : ; }   # stub — intégré dans tab_mesa_dev

#========================================================================
# ONGLET 1 — Tableau de bord
#========================================================================

tab_dashboard() {
    # ── Statuts calculés au moment du lancement ──────────────────────
    # Kernel compilé
    local k_status k_label
    k_label=$(ls -t "$KERNELS_DIR"/linux-ps4-*/arch/x86/boot/bzImage 2>/dev/null | head -1)
    if [ -n "$k_label" ]; then
        k_status="<span foreground='${C_OK}'>✓ $(basename "$(dirname "$(dirname "$(dirname "$k_label")")")")</span>"
    elif ls -t "$KERNELS_DIR"/*/arch/x86/boot/bzImage 2>/dev/null | head -1 | grep -q .; then
        k_status="<span foreground='${C_OK}'>✓ bzImage trouvé</span>"
    else
        k_status="<span foreground='${C_WARN}'>— aucun kernel compilé</span>"
    fi

    # Mesa
    local mesa_status
    if command -v glxinfo >/dev/null 2>&1; then
        local mv; mv=$(glxinfo 2>/dev/null | awk '/OpenGL version/{print $4}' | head -1)
        [ -n "$mv" ] && mesa_status="<span foreground='${C_OK}'>✓ Mesa $mv</span>" \
                     || mesa_status="<span foreground='${C_WARN}'>Mesa installé (glxinfo)</span>"
    else
        mesa_status="<span foreground='${C_SECTION}'>— glxinfo non disponible</span>"
    fi

    # Espace disque PROJECT-PS4
    local disk_status
    if [ -d "$PROJECT_DIR" ]; then
        local avail used
        avail=$(df -h "$PROJECT_DIR" 2>/dev/null | awk 'NR==2{print $4}')
        used=$(df -h  "$PROJECT_DIR" 2>/dev/null | awk 'NR==2{print $3}')
        disk_status="<span foreground='${C_OK}'>✓ $used utilisés — $avail libres</span>"
    else
        disk_status="<span foreground='${C_WARN}'>$PROJECT_DIR non créé</span>"
    fi

    # PS4 joignable (ping rapide)
    local net_status
    if [[ "${PS4_IP:-}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        if ping -c1 -W1 "$PS4_IP" >/dev/null 2>&1; then
            net_status="<span foreground='${C_OK}'>✓ PS4 joignable — $PS4_IP</span>"
        else
            net_status="<span foreground='${C_ERR}'>✗ PS4 hors ligne — $PS4_IP</span>"
        fi
    else
        net_status="<span foreground='${C_SECTION}'>— IP non configurée (Préférences)</span>"
    fi

    # SSD PS4 monté
    local ssd_status
    if mount 2>/dev/null | grep -q "ps4hdd"; then
        ssd_status="<span foreground='${C_OK}'>✓ SSD PS4 monté sur /ps4hdd</span>"
    else
        ssd_status="<span foreground='${C_SECTION}'>— SSD PS4 non monté</span>"
    fi

    # Dépendances (résultat du check silencieux démarrage)
    local dep_ok dep_fail dep_status
    dep_ok=$(  grep  '^OK='   "$DEPS_STATUS_FILE" 2>/dev/null | cut -d= -f2)
    dep_fail=$(grep  '^FAIL=' "$DEPS_STATUS_FILE" 2>/dev/null | cut -d= -f2)
    if [ "${dep_fail:-0}" -gt 0 ] 2>/dev/null; then
        dep_status="<span foreground='${C_WARN}'>⚠  $dep_fail manquante(s) sur $(( ${dep_ok:-0} + ${dep_fail:-0} ))</span>"
    else
        dep_status="<span foreground='${C_OK}'>✓ Toutes présentes (${dep_ok:-?})</span>"
    fi

    yad --plug="$KEY" --tabnum=1 \
        --form --scroll \
        --image="$LOGO" --image-on-top \
        --text="<big><b><span foreground='${C_TITRE}'>🏠 Tableau de bord</span></b></big>
<small>Hybryde PS4 Tools v2.0 — $(date '+%d/%m/%Y %H:%M')</small>\n" \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ État du système ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</span></b>":LBL "" \
        --field="  🐧 Kernel     : $k_status":LBL "" \
        --field="  🔧 Mesa       : $mesa_status":LBL "" \
        --field="  💽 SSD PS4   : $ssd_status":LBL "" \
        --field="  🌐 Réseau     : $net_status":LBL "" \
        --field="  💾 Stockage   : $disk_status":LBL "" \
        --field="  📦 Dépendances: $dep_status":LBL "" \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ Actions rapides ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</span></b>":LBL "" \
        --field="  🚀 Compiler le kernel (Full LTO Jaguar)":BTN       'bash -c "do_kernel_compile_lto"' \
        --field="  🔧 Compiler Mesa (mesa-build.py)":BTN              'bash -c "do_build_mesa"' \
        --field="  ⬇  Gestionnaire de téléchargements DionKill":BTN  'bash -c "do_dl_manager"' \
        --field="  📡 Déployer via FTP → PS4 (/data/linux/boot/)":BTN 'bash -c "do_ftp_transfer"' \
        --field="  💾 Préparer une clé USB de boot PS4":BTN           'bash -c "do_prepare_usb"' \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ Outils &amp; Préférences ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</span></b>":LBL "" \
        --field="  ✅ Vérifier les dépendances (détail complet)":BTN 'bash -c "do_check_deps_full"' \
        --field="  📋 Voir les logs PS4 Tools":BTN                   'bash -c "do_show_logs"' \
        --field="  ⚙  Préférences (IP PS4, chemins, notifications)":BTN 'bash -c "do_open_settings"' \
        --field="  📂 Ouvrir PROJECT-PS4/":BTN                        'bash -c "do_open_project_dir"' \
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
# ONGLET 2 — Créer un tar.xz  (fonctions do_tar_* inchangées)
#========================================================================

do_tar_set_name() {
    local cur
    cur=$(cat "$TAR_NAME_FILE" 2>/dev/null || echo "ps4linux.tar.xz")
    local out
    out=$(yad --center --borders=10 \
        --title="Nom du tar.xz" \
        --form \
        --text="Entrez le nom du fichier tar.xz :" \
        --field="Nom du fichier :":TEXT "$cur" \
        --button="Annuler:1" --button="Valider:0" \
        --width=520)
    [ $? -ne 0 ] || [ -z "$out" ] && return
    local name
    name=$(echo "$out" | cut -d'|' -f1)
    echo "$name" > "$TAR_NAME_FILE"
    yad_info "✓ Nom défini : <b>$name</b>\nEmplacement final : <tt>/$name</tt>"
}
export -f do_tar_set_name

do_tar_add_exclude() {
    local out
    out=$(yad --center --borders=10 \
        --title="Ajouter une exclusion" \
        --form \
        --text="Entrez un chemin à exclure du tar.xz :\n(ex: <tt>/var/cache</tt>  <tt>/proc</tt>  <tt>/tmp</tt>)" \
        --field="Chemin à exclure :":TEXT "/var/cache" \
        --button="Annuler:1" --button="Ajouter:0" \
        --width=540)
    [ $? -ne 0 ] || [ -z "$out" ] && return
    local entry
    entry=$(echo "$out" | cut -d'|' -f1)
    [ -z "$entry" ] && return
    echo "$entry" >> "$TAR_EXCLUDES_FILE"
    yad_info "✓ Exclusion ajoutée : <tt>$entry</tt>"
}
export -f do_tar_add_exclude

do_tar_del_exclude() {
    [ ! -f "$TAR_EXCLUDES_FILE" ] && yad_info "La liste d'exclusions est vide." && return
    local items=()
    while IFS= read -r line; do
        [ -n "$line" ] && items+=("$line")
    done < "$TAR_EXCLUDES_FILE"
    [ "${#items[@]}" -eq 0 ] && yad_info "La liste d'exclusions est vide." && return

    local sel
    sel=$(yad --center --borders=10 \
        --title="Supprimer une exclusion" \
        --list \
        --text="Sélectionnez l'entrée à supprimer :" \
        --column="Chemin à exclure" \
        "${items[@]}" \
        --print-column=1 --separator="" \
        --button="Annuler:1" --button="Supprimer:0" \
        --width=520 --height=360)
    [ $? -ne 0 ] || [ -z "$sel" ] && return
    local escaped="${sel//\//\\/}"
    sed -i "/^${escaped}$/d" "$TAR_EXCLUDES_FILE"
    yad_info "✓ Supprimé : <tt>$sel</tt>"
}
export -f do_tar_del_exclude

do_tar_show_excludes() {
    local content
    content=$(cat "$TAR_EXCLUDES_FILE" 2>/dev/null || echo "(liste vide)")
    yad --center --borders=10 \
        --title="Exclusions actuelles" \
        --text-info \
        --width=540 --height=340 \
        --button="Fermer:0" \
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

    yad_info "<b>Commande générée :</b>\n\n<tt>$cmd</tt>\n\n📦 Fichier final : <tt>/$tarname</tt>\n\nCliquez sur <b>🚀 Lancer la création</b> pour exécuter."
}
export -f do_tar_generate

do_tar_run() {
    [ ! -f "$TAR_CMD_FILE" ] && yad_err "Aucune commande générée.\nCliquez d'abord sur <b>Générer la commande</b>." && return
    local cmd tarname
    cmd=$(cat "$TAR_CMD_FILE")
    tarname=$(cat "$TAR_NAME_FILE" 2>/dev/null || echo "ps4linux.tar.xz")

    yad_confirm "Lancer la création de l'archive ?\n\n<tt>$cmd</tt>\n\n📦 Résultat : <tt>/$tarname</tt>\n\n⚠️  Cette opération peut prendre <b>plusieurs heures</b>." || return
    run_in_term "Création tar.xz PS4" "$cmd"
}
export -f do_tar_run

tab_tar_create() { : ; }   # stub — contenu intégré dans tab_systeme

#========================================================================
# ONGLET 3 — Créer un .img

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
        yad_err "Aucune partition détectée.\nVérifiez que le disque est connecté (<tt>lsblk</tt>)."
        return
    fi

    local sel
    sel=$(yad --center --borders=10 \
        --title="Sélectionner la partition source" \
        --list \
        --text="<b>Sélectionnez la partition à sauvegarder en .img</b>\n\n⚠️  Idéalement, la partition ne doit <b>pas être montée</b> pour une image cohérente." \
        --column="Partition" \
        --column="Taille  |  FS  |  Point de montage" \
        "${parts[@]}" \
        --print-column=1 --separator="" \
        --button="Annuler:1" --button="Sélectionner:0" \
        --width=700 --height=440)
    [ $? -ne 0 ] || [ -z "$sel" ] && return
    sel="${sel//|/}"
    echo "$sel" > "$IMG_SRC_PART_FILE"
    yad_info "✓ Partition source sélectionnée :\n<tt>$sel</tt>"
}
export -f do_img_select_partition

do_img_select_dst() {
    local d
    d=$(yad --center --borders=10 \
        --title="Sélectionner le dossier de destination" \
        --file --directory --filename="$HOME/" \
        --button="Annuler:1" --button="Sélectionner:0" \
        --width=860 --height=540)
    [ $? -ne 0 ] || [ -z "$d" ] && return
    echo "$d" > "$IMG_DST_DIR_FILE"
    yad_info "✓ Dossier de destination :\n<tt>$d</tt>"
}
export -f do_img_select_dst

do_img_set_name() {
    local cur
    cur=$(cat "$IMG_NAME_FILE2" 2>/dev/null || echo "ps4linux-partition.img")
    local out
    out=$(yad --center --borders=10 \
        --title="Nom du fichier .img" \
        --form \
        --text="Entrez le nom du fichier image à créer :" \
        --field="Nom du fichier .img :":TEXT "$cur" \
        --button="Annuler:1" --button="Valider:0" \
        --width=520)
    [ $? -ne 0 ] || [ -z "$out" ] && return
    local name
    name=$(echo "$out" | cut -d'|' -f1)
    echo "$name" > "$IMG_NAME_FILE2"
    yad_info "✓ Nom défini : <b>$name</b>"
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

    [ -z "$src" ] && yad_err "Aucune partition source sélectionnée.\nCliquez sur <b>① Sélectionner la partition</b>." && return
    [ ! -b "$src" ] && yad_err "Périphérique bloc introuvable :\n<tt>$src</tt>\nVérifiez que le disque est connecté." && return
    [ -z "$dst" ] && yad_err "Aucun dossier de destination sélectionné.\nCliquez sur <b>② Sélectionner le dossier</b>." && return
    [ ! -d "$dst" ] && yad_err "Dossier introuvable :\n<tt>$dst</tt>" && return

    local imgpath="$dst/$name"

    local part_size_human part_size_bytes avail_bytes space_warn=""
    part_size_human=$(lsblk -no SIZE "$src" 2>/dev/null | head -1 | tr -d ' ')
    part_size_bytes=$(lsblk -bno SIZE "$src" 2>/dev/null | head -1 | tr -d ' ')
    avail_bytes=$(df -B1 --output=avail "$dst" 2>/dev/null | tail -1 | tr -d ' ')

    if [ -n "$part_size_bytes" ] && [ -n "$avail_bytes" ]; then
        if [ "$avail_bytes" -lt "$part_size_bytes" ]; then
            local avail_human
            avail_human=$(df -h --output=avail "$dst" 2>/dev/null | tail -1 | tr -d ' ')
            space_warn="\n\n⚠️  <b>Espace insuffisant !</b>\n  Requis     : $part_size_human\n  Disponible : $avail_human"
        fi
    fi

    local cmd="sudo dd if='$src' of='$imgpath' bs=4M status=progress conv=fsync"

    yad_confirm "Créer l'image complète de la partition ?\n\n  💽 Source  : <tt>$src</tt>  ($part_size_human)\n  📄 Image   : <tt>$imgpath</tt>\n\nCommande :\n<tt>$cmd</tt>${space_warn}\n\n⏱  Cette opération peut prendre plusieurs minutes." || return

    echo "$imgpath" > "$IMG_PATH_FILE"
    run_sudo_in_term "Sauvegarde partition → .img" \
        "dd if='$src' of='$imgpath' bs=4M status=progress conv=fsync && echo '' && echo '✓ Image créée :' && ls -lh '$imgpath' || echo '✗ Erreur dd'"
}
export -f do_img_create

do_img_show_path() {
    local p
    p=$(cat "$IMG_PATH_FILE" 2>/dev/null)
    if [ -n "$p" ]; then
        local info
        info=$(ls -lh "$p" 2>/dev/null || echo "(fichier introuvable)")
        yad_info "Dernier .img créé :\n\n<tt>$p</tt>\n\n$info"
    else
        yad_info "Aucun .img créé pour l'instant."
    fi
}
export -f do_img_show_path

tab_img_create() { : ; }   # stub — intégré dans tab_systeme

#========================================================================
# ONGLET 4 — Décompresser un tar.xz

do_ext_select_src() {
    local f
    f=$(yad --center --borders=10 \
        --title="Sélectionner l'archive tar.xz" \
        --file --filename="$HOME/" \
        --file-filter="Archives tar.xz | *.tar.xz *.tar" \
        --button="Annuler:1" --button="Sélectionner:0" \
        --width=860 --height=540)
    [ $? -ne 0 ] || [ -z "$f" ] && return
    echo "$f" > "$EXT_SRC_FILE"
    yad_info "✓ Archive sélectionnée :\n<tt>$f</tt>"
}
export -f do_ext_select_src

do_ext_select_dst() {
    local d
    d=$(yad --center --borders=10 \
        --title="Sélectionner la partition de destination" \
        --file --directory --filename="/media/$USER/" \
        --button="Annuler:1" --button="Sélectionner:0" \
        --width=860 --height=540)
    [ $? -ne 0 ] || [ -z "$d" ] && return
    echo "$d" > "$EXT_DST_FILE"
    yad_info "✓ Destination sélectionnée :\n<tt>$d</tt>"
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

    [ -z "$src" ] && yad_err "Aucune archive sélectionnée.\nCliquez sur <b>① Sélectionner l'archive</b>." && return
    [ ! -f "$src" ] && yad_err "Fichier introuvable :\n<tt>$src</tt>" && return
    [ -z "$dst" ] && yad_err "Aucune destination sélectionnée.\nCliquez sur <b>② Sélectionner la partition</b>." && return

    local cmd="sudo tar -xvJpf '$src' -C '$dst' --numeric-owner"

    yad_confirm "Lancer l'extraction ?\n\n  📁 Archive     : <tt>$(basename "$src")</tt>\n  📂 Destination : <tt>$dst</tt>\n\n<tt>$cmd</tt>\n\n⚠️  Cette opération peut prendre un long moment." || return

    run_in_term "Décompression tar.xz PS4" "$cmd"
}
export -f do_ext_run

tab_tar_extract() { : ; }   # stub — intégré dans tab_systeme

#========================================================================
# ONGLET 5 — Monter le SSD PS4 (VERSION SIMPLE)

PS4_KEY="/key/eap_hdd_key.bin"
PS4_DEV="/dev/sda27"
PS4_MNT="/ps4hdd"

# ── Montage Belize / Aeolia ───────────────────────────────────────────
do_mount_ps4_belize() {
    xterm -hold -e bash -c "
echo '--- Montage PS4 Belize / Aeolia ---'
echo ''
echo '--- cryptsetup ---'
sudo cryptsetup -d /key/eap_hdd_key.bin --cipher aes-xts-plain64 -s 256 --offset 0 --skip 111669149696 create ps4hdd /dev/sd?27
sudo mount -t ufs -o ufstype=ufs2 /dev/mapper/ps4hdd /ps4hdd
sudo chmod -R a+rwX /ps4hdd

echo ''
echo 'OK → SSD monté sur $PS4_MNT'
cd /ps4hdd
ls 
read -p 'Entrée... Vous pouvez fermer ce terminal, vous pouvez utiliser votre explorateur de fichier, dossier /ps4hdd'
"
}

# ── Montage Baikal ────────────────────────────────────────────────────
do_mount_ps4_baikal() {
    xterm -hold -e bash -c "
echo '--- Montage PS4 Baikal ---'
echo ''
echo '--- cryptsetup ---'
sudo cryptsetup -d $PS4_KEY --cipher aes-xts-plain64 -s 256 --offset 0 create ps4hdd $PS4_DEV
sudo mount -t ufs -o ufstype=ufs2 /dev/mapper/ps4hdd $PS4_MNT
sudo chmod -R a+rwX $PS4_MNT

echo ''
echo 'OK → SSD monté sur $PS4_MNT'
cd /ps4hdd
ls 
read -p 'Entrée... Vous pouvez fermer ce terminal, vous pouvez utiliser votre explorateur de fichier, dossier /ps4hdd'
"
}

# ── Démontage ─────────────────────────────────────────────────────────
do_unmount_ps4() {
    xterm -hold -e bash -c "
echo '--- Démontage SSD PS4 ---'
echo ''

sudo umount $PS4_MNT 2>/dev/null
sudo cryptsetup remove ps4hdd 2>/dev/null

echo 'OK → démonté'
read -p 'Entrée...'
"
}

# ── Interface YAD ─────────────────────────────────────────────────────
tab_mount_ps4() { : ; }   # stub — intégré dans tab_systeme (doublon supprimé)

export -f do_mount_ps4_belize
export -f do_mount_ps4_baikal
export -f do_unmount_ps4
export -f tab_mount_ps4

#========================================================================
# ONGLET 2 — Système & Stockage (archives + img + SSD + réseau)
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
        --text="<big><b><span foreground='${C_SYS}'>💿 Système &amp; Stockage</span></b></big>
<span foreground='${C_SECTION}'>Archives tar.xz  ·  Images .img  ·  SSD PS4  ·  Réseau &amp; SSH</span>\n" \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ 📦 Créer un tar.xz ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</span></b>":LBL "" \
        --field="  <small>Commande : <tt>sudo tar -cvf /[nom] --exclude=... --one-file-system / -I \"xz -9\"</tt></small>":LBL "" \
        --field="  Nom actuel : <b>$tar_name</b>  →  Modifier":BTN 'bash -c "do_tar_set_name"' \
        --field="  Ajouter une exclusion (--exclude)":BTN            'bash -c "do_tar_add_exclude"' \
        --field="  Supprimer une exclusion":BTN                      'bash -c "do_tar_del_exclude"' \
        --field="  Voir les exclusions actuelles":BTN                'bash -c "do_tar_show_excludes"' \
        --field="  Générer la commande finale":BTN                   'bash -c "do_tar_generate"' \
        --field="  🚀 Lancer la création du tar.xz":BTN             'bash -c "do_tar_run"' \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ 📂 Décompresser un tar.xz ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</span></b>":LBL "" \
        --field="  <small>Commande : <tt>sudo tar -xvJpf [archive] -C [partition] --numeric-owner</tt></small>":LBL "" \
        --field="  Archive : <small>$tar_src</small>":LBL "" \
        --field="  Dest    : <small>$tar_dst</small>":LBL "" \
        --field="  ① Sélectionner l'archive tar.xz":BTN             'bash -c "do_ext_select_src"' \
        --field="  ② Sélectionner la partition de destination":BTN  'bash -c "do_ext_select_dst"' \
        --field="  🚀 Lancer l'extraction":BTN                      'bash -c "do_ext_run"' \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ 💿 Créer une image .img (dd) ━━━━━━━━━━━━━━━━━━━━━━━━━━━━</span></b>":LBL "" \
        --field="  <small>Commande : <tt>sudo dd if=[partition] of=[fichier.img] bs=4M status=progress conv=fsync</tt></small>":LBL "" \
        --field="  ① Sélectionner la partition à sauvegarder":BTN  'bash -c "do_img_select_partition"' \
        --field="  ② Sélectionner le dossier de destination":BTN   'bash -c "do_img_select_dst"' \
        --field="  ③ Modifier le nom du fichier .img":BTN          'bash -c "do_img_set_name"' \
        --field="  Voir la sélection actuelle":BTN                  'bash -c "do_img_show_sel"' \
        --field="  🚀 Créer l'image .img (dd)":BTN                 'bash -c "do_img_create"' \
        --field="  Voir le dernier .img créé":BTN                   'bash -c "do_img_show_path"' \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ 🔌 SSD PS4 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</span></b>":LBL "" \
        --field="  Clé : <tt>$PS4_KEY</tt>  ·  Partition : <tt>$PS4_DEV</tt>  ·  Point : <tt>$PS4_MNT</tt>":LBL "" \
        --field="  🚀 Monter SSD PS4 (Belize / Aeolia)":BTN        'bash -c "do_mount_ps4_belize"' \
        --field="  🚀 Monter SSD PS4 (Baikal)":BTN                 'bash -c "do_mount_ps4_baikal"' \
        --field="  ⏏  Démonter SSD PS4":BTN                        'bash -c "do_unmount_ps4"' \
        --field="  💽 État cryptsetup + mount + lsblk":BTN         'bash -c "do_cryptsetup_status"' \
        --field="  📁 Copier un dossier vers /ps4hdd (rsync)":BTN  'bash -c "do_rsync_to_ps4hdd"' \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ 🌐 Réseau &amp; SSH ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</span></b>":LBL "" \
        --field="  🔍 Scanner le réseau local (nmap)":BTN           'bash -c "do_net_scan"' \
        --field="  🖥  Connexion SSH vers la PS4":BTN               'bash -c "do_ssh_ps4"' \
        --field="  📂 Connexion FTP vers la PS4 (FileZilla)":BTN    'bash -c "do_ftp_ps4"' \
        \
        "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" \
        &
}

#========================================================================
# ONGLET 6 — Aide (10 documents configurables)
#
# CORRECTION v1.1 : l'ancienne approche --list + --dclick-action ouvrait
# un sélecteur de fichiers yad (Thunar) au lieu du PDF.
# Nouvelle approche : --form avec BTN par document → appel direct à
# preview_pdf (aperçu) ou xdg-open (lecteur par défaut).
# Les chemins sont expansés à la génération du plug (pas dans un sous-shell)
# donc pas de problème de portée variable.
#
# ─── Modifiez les noms et chemins ici ──────────────────────────────────
#========================================================================

AIDE_LABELS=(
    "Create a Multiboot SSD"      # bouton 1
    "Active Zram"             # bouton 2
    "TRANSFORM YOUR PS4 INTO A WII" # bouton 3
    "A developer in your terminal" # bouton 4
    "CUSTOM BASH"             # bouton 5
    "Update mesa"             # bouton 6
    "Doc PS4 Linux 7"             # bouton 7
    "Doc PS4 Linux 8"             # bouton 8
    "Doc PS4 Linux 9"             # bouton 9
    "Doc PS4 Linux 10"            # bouton 10
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
# ────────────────────────────────────────────────────────────────────────

tab_aide() { : ; }   # stub — intégré dans tab_hub

#========================================================================
# ONGLET 7 — Réseau / Transfert

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
    read -rp "[Entrée pour fermer]"
    exit 1
fi
IFACE=$(ip route | awk '/^default/ {print $5; exit}')
SUBNET=$(ip route | awk -v ifc="$IFACE" '$0 ~ "scope link" && $0 ~ ("dev "ifc" ") {print $1; exit}')
if [ -z "$SUBNET" ]; then
    SUBNET=$(ip route | awk '/scope link/ {print $1}' | head -1)
fi
echo "Interface par défaut : $IFACE"
echo "Sous-réseau détecté  : $SUBNET"
echo ""
echo "(scan ARP via sudo : plus fiable pour détecter les appareils WiFi comme la PS4)"
echo ""
if [ "$(id -u)" -eq 0 ]; then
    nmap -sn "$SUBNET" 2>/dev/null | grep -E "Nmap scan|Host is up|report for|MAC Address"
else
    sudo nmap -sn "$SUBNET" 2>/dev/null | grep -E "Nmap scan|Host is up|report for|MAC Address"
fi
echo ""
read -rp "[Entrée pour fermer]"
EOF
    chmod +x "$tmpscript"
    case "$TERM_BIN" in
        xfce4-terminal) xfce4-terminal --title="Scan réseau" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
        gnome-terminal) gnome-terminal --title="Scan réseau" -- bash -c "$tmpscript; rm -f $tmpscript" ;;
        mate-terminal)  mate-terminal  --title="Scan réseau" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
        *)              xterm -title "Scan réseau" -e bash -c "$tmpscript; rm -f $tmpscript" ;;
    esac
}
export -f do_net_scan

do_rsync_to_ps4hdd() {
    local src
    src=$(yad --center --borders=10 \
        --title="Sélectionner le dossier source à copier" \
        --file --directory --filename="$HOME/" \
        --button="Annuler:1" --button="Sélectionner:0" \
        --width=860 --height=540)
    [ $? -ne 0 ] || [ -z "$src" ] && return

    local dst
    dst=$(yad --center --borders=10 \
        --title="Destination sur /ps4hdd" \
        --form \
        --text="Dossier destination sur /ps4hdd :" \
        --field="Chemin destination :":TEXT "/ps4hdd/game/" \
        --button="Annuler:1" --button="Valider:0" \
        --width=540)
    [ $? -ne 0 ] || [ -z "$dst" ] && return
    dst=$(echo "$dst" | cut -d'|' -f1)

    yad_confirm "Lancer le transfert rsync ?\n\n  Source : <tt>$src</tt>\n  Dest   : <tt>$dst</tt>\n\n⚠️  Peut prendre plusieurs minutes selon la taille." || return

    local tmpscript
    tmpscript=$(mktemp /tmp/hyb-rsync-XXXX.sh)
    printf '#!/bin/bash\nrsync -av --progress "%s" "%s"\necho ""\nread -rp "[Entrée pour fermer]"\n' "$src" "$dst" > "$tmpscript"
    chmod +x "$tmpscript"
    case "$TERM_BIN" in
        xfce4-terminal) xfce4-terminal --title="rsync vers ps4hdd" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
        gnome-terminal) gnome-terminal --title="rsync vers ps4hdd" -- bash -c "$tmpscript; rm -f $tmpscript" ;;
        mate-terminal)  mate-terminal  --title="rsync vers ps4hdd" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
        *)              xterm -title "rsync vers ps4hdd" -e bash -c "$tmpscript; rm -f $tmpscript" ;;
    esac
}
export -f do_rsync_to_ps4hdd

do_ssh_ps4() {
    local out
    out=$(yad --center --borders=10 \
        --title="SSH vers PS4" \
        --form \
        --text="<b>Connexion SSH vers la PS4</b>" \
        --field="Adresse IP PS4 :":TEXT "192.168.1.xxx" \
        --field="Utilisateur :":TEXT "root" \
        --field="Port SSH :":NUM "22!1..65535!1" \
        --button="Annuler:1" --button="Connecter:0" \
        --width=460)
    [ $? -ne 0 ] || [ -z "$out" ] && return
    local ip user port
    ip=$(echo "$out"   | cut -d'|' -f1)
    user=$(echo "$out" | cut -d'|' -f2)
    port=$(echo "$out" | cut -d'|' -f3)

    local tmpscript
    tmpscript=$(mktemp /tmp/hyb-ssh-XXXX.sh)
    printf '#!/bin/bash\necho "Connexion SSH : %s@%s:%s"\nssh -p "%s" "%s@%s"\nread -rp "[Entrée pour fermer]"\n' \
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
        yad_info "⚠ Aucune adresse IP PS4 configurée.\n\nOuvre <b>⚙ Préférences</b> et renseigne l'adresse IP de ta PS4 avant de te connecter en FTP."
        return
    fi
    if ! command -v filezilla >/dev/null 2>&1; then
        yad_info "⚠ FileZilla n'est pas installé.\n\n  sudo apt install filezilla"
        return
    fi
    local out
    out=$(yad --center --borders=10 \
        --title="Connexion FTP vers PS4" \
        --form \
        --text="<b>Connexion FTP vers la PS4</b>\n<small>IP enregistrée dans les préférences : $PS4_IP\nLaisser l'utilisateur vide pour une connexion anonyme (serveurs FTP PS4 homebrew classiques)</small>" \
        --field="Adresse IP PS4 :":TEXT      "$PS4_IP" \
        --field="Utilisateur (optionnel) :":TEXT "" \
        --field="Port FTP :":NUM             "2121!1..65535!1" \
        --button="Annuler:1" --button="📂 Ouvrir FileZilla:0" \
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

    log_entry "FTP" "Ouverture de FileZilla vers ${ftp_uri}"
    filezilla "$ftp_uri" &
}
export -f do_ftp_ps4

tab_reseau() { : ; }   # stub — intégré dans tab_systeme

#========================================================================
# ONGLET 8 — Diagnostic / Logs

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
chk parted        parted        "parted"
chk dosfstools    mkfs.vfat     "dosfstools"
chk e2fsprogs     mkfs.ext4     "e2fsprogs"
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
    warn "vulkaninfo" "non disponible"
fi

echo ""
echo "=== Driver GPU actif ==="
lspci -k 2>/dev/null | grep -A2 "VGA" | head -6

echo ""
echo "=== Mesa version ==="
if command -v glxinfo >/dev/null 2>&1; then
    glxinfo 2>/dev/null | grep -i "OpenGL version\|renderer" | head -3
else
    warn "glxinfo" "non disponible (sudo apt install mesa-utils)"
fi

echo ""
read -rp "[Entrée pour fermer]"
EOF
    chmod +x "$tmpscript"
    case "$TERM_BIN" in
        xfce4-terminal) xfce4-terminal --title="Diagnostic Prérequis" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
        gnome-terminal) gnome-terminal --title="Diagnostic Prérequis" -- bash -c "$tmpscript; rm -f $tmpscript" ;;
        mate-terminal)  mate-terminal  --title="Diagnostic Prérequis" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
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
read -rp "[Entrée pour fermer]"
EOF
    chmod +x "$tmpscript"
    case "$TERM_BIN" in
        xfce4-terminal) xfce4-terminal --title="État SSD PS4" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
        gnome-terminal) gnome-terminal --title="État SSD PS4" -- bash -c "$tmpscript; rm -f $tmpscript" ;;
        mate-terminal)  mate-terminal  --title="État SSD PS4" -e "bash -c '$tmpscript; rm -f $tmpscript'" ;;
        *)              xterm -title "État SSD PS4" -e bash -c "$tmpscript; rm -f $tmpscript" ;;
    esac
}
export -f do_cryptsetup_status

tab_diagnostic() { : ; }   # stub — intégré dans tab_mesa_dev

#========================================================================
# ONGLET 9 — Variables d'environnement Mesa

MESA_ENV_FILE="$CONF_DIR/mesa-env.conf"
MESA_PROFILES_DIR="$CONF_DIR/mesa-profiles"
mkdir -p "$MESA_PROFILES_DIR"
export MESA_ENV_FILE MESA_PROFILES_DIR

# Profil par défaut si absent
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
    # Lire le fichier courant
    source "$MESA_ENV_FILE" 2>/dev/null

    out=$(yad --center --borders=10 \
        --title="Variables Mesa" \
        --form \
        --text="<b>Variables d'environnement Mesa/Vulkan</b>\n<small>Laisser vide = non exporté</small>\n" \
        --field="RADV_DEBUG :":TEXT "${RADV_DEBUG:-}" \
        --field="MESA_DEBUG :":TEXT "${MESA_DEBUG:-}" \
        --field="AMD_DEBUG :":TEXT "${AMD_DEBUG:-}" \
        --field="VK_ICD_FILENAMES :":TEXT "${VK_ICD_FILENAMES:-/usr/share/vulkan/icd.d/radeon_icd.x86_64.json}" \
        --field="mesa_glthread :":CBX "true!false" \
        --field="RADV_PERFTEST :":TEXT "${RADV_PERFTEST:-}" \
        --button="Annuler:1" --button="Sauvegarder:0" \
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
    yad_info "✓ Variables sauvegardées dans :\n<tt>$MESA_ENV_FILE</tt>"
}
export -f do_mesa_edit_env

do_mesa_save_profile() {
    local out
    out=$(yad --center --borders=10 \
        --title="Sauvegarder un profil" \
        --form \
        --text="Nom du profil Mesa à sauvegarder :" \
        --field="Nom :":TEXT "profil-debug" \
        --button="Annuler:1" --button="Sauvegarder:0" \
        --width=400)
    [ $? -ne 0 ] || [ -z "$out" ] && return
    local name; name=$(echo "$out" | cut -d'|' -f1 | tr ' ' '-')
    cp "$MESA_ENV_FILE" "$MESA_PROFILES_DIR/$name.conf"
    yad_info "✓ Profil sauvegardé : <b>$name</b>\n<tt>$MESA_PROFILES_DIR/$name.conf</tt>"
}
export -f do_mesa_save_profile

do_mesa_load_profile() {
    local profiles=()
    for f in "$MESA_PROFILES_DIR"/*.conf; do
        [ -f "$f" ] && profiles+=("$(basename "$f" .conf)")
    done
    [ "${#profiles[@]}" -eq 0 ] && yad_info "Aucun profil sauvegardé." && return

    local sel
    sel=$(yad --center --borders=10 \
        --title="Charger un profil Mesa" \
        --list \
        --text="Sélectionnez le profil à charger :" \
        --column="Profil" \
        "${profiles[@]}" \
        --print-column=1 --separator="" \
        --button="Annuler:1" --button="Charger:0" \
        --width=400 --height=300)
    [ $? -ne 0 ] || [ -z "$sel" ] && return
    sel="${sel//|/}"
    cp "$MESA_PROFILES_DIR/$sel.conf" "$MESA_ENV_FILE"
    yad_info "✓ Profil chargé : <b>$sel</b>"
}
export -f do_mesa_load_profile

do_mesa_launch_app() {
    local app
    app=$(yad --center --borders=10 \
        --title="Lancer une application avec les variables Mesa" \
        --file --filename="$HOME/" \
        --button="Annuler:1" --button="Lancer:0" \
        --width=860 --height=540)
    [ $? -ne 0 ] || [ -z "$app" ] && return
    [ ! -f "$app" ] && yad_err "Fichier introuvable." && return

    local tmpscript
    tmpscript=$(mktemp /tmp/hyb-mesa-launch-XXXX.sh)
    {
        echo "#!/bin/bash"
        echo "echo '=== Variables Mesa actives ==='"
        # Exporter chaque variable non vide
        while IFS='=' read -r key val; do
            [[ "$key" =~ ^# ]] && continue
            [ -z "$key" ] && continue
            if [ -n "$val" ]; then
                echo "export ${key}=${val}"
                echo "echo \"  ${key}=${val}\""
            fi
        done < "$MESA_ENV_FILE"
        echo "echo ''"
        echo "echo '=== Lancement : $app ==='"
        echo "\"$app\""
        echo "read -rp '[Entrée pour fermer]'"
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
    content=$(cat "$MESA_ENV_FILE" 2>/dev/null || echo "(aucune variable définie)")
    yad --center --borders=10 \
        --title="Variables Mesa actuelles" \
        --text-info --width=560 --height=300 \
        --button="Fermer:0" \
        <<< "$content"
}
export -f do_mesa_show_current

tab_mesa_env() { : ; }   # stub — intégré dans tab_mesa_dev

#========================================================================
# ONGLET 3 — Mesa & Dev
#========================================================================

tab_mesa_dev() {
    yad --plug="$KEY" --tabnum=3 \
        --form --scroll \
        --image="/usr/share/hybryde/SquareGlass/Download Manager.png" --image-on-top \
        --text="<big><b><span foreground='${C_MESA}'>🔧 Mesa &amp; Dev</span></b></big>
<span foreground='${C_SECTION}'>Compilation Mesa / libdrm  ·  Variables d'environnement  ·  Diagnostic</span>\n" \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ 🔧 Compiler Mesa (AMD Liverpool / Gladius) ━━━━━━━━━━━━━━━</span></b>":LBL "" \
        --field="  <small>Sources : <tt>~/mesa-git</tt>  et  <tt>~/libdrm-git</tt></small>":LBL "" \
        --field="  Ouvrir un script dans Geany":BTN              'bash -c "do_edit_script"' \
        --field="  Appliquer un .patch Mesa":BTN                 'bash -c "do_patch_mesa"' \
        --field="  Appliquer un .patch libdrm":BTN               'bash -c "do_patch_libdrm"' \
        --field="  🚀 Build Mesa (./mesa-build.py)":BTN          'bash -c "do_build_mesa"' \
        --field="  Commande manuelle (éditable avant lancement)":BTN 'bash -c "do_manual_build"' \
        --field="  ⬇  Télécharger mesa-build.py (baryluk)":BTN  'bash -c "do_get_mesa_build_baryluk"' \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ ⚙  Variables Mesa / Vulkan ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</span></b>":LBL "" \
        --field="  <small>RADV_DEBUG, MESA_DEBUG, AMD_DEBUG, mesa_glthread…</small>":LBL "" \
        --field="  ✏  Éditer les variables Mesa/Vulkan":BTN           'bash -c "do_mesa_edit_env"' \
        --field="  📋 Afficher les variables actuelles":BTN           'bash -c "do_mesa_show_current"' \
        --field="  💾 Sauvegarder le profil actuel":BTN               'bash -c "do_mesa_save_profile"' \
        --field="  📂 Charger un profil":BTN                          'bash -c "do_mesa_load_profile"' \
        --field="  🚀 Lancer une application avec les variables actives":BTN 'bash -c "do_mesa_launch_app"' \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ 🔍 Diagnostic ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</span></b>":LBL "" \
        --field="  ✅ Vérifier tous les prérequis PS4 Linux":BTN      'bash -c "do_diag_prereqs"' \
        --field="  ✅ Vérification dépendances (détail complet)":BTN  'bash -c "do_check_deps_full"' \
        --field="  📋 dmesg temps réel (USB / DRM / amdgpu)":BTN     'bash -c "do_dmesg_live"' \
        --field="  💽 cryptsetup status + mount + lsblk":BTN         'bash -c "do_cryptsetup_status"' \
        --field="  📋 Voir les logs PS4 Tools":BTN                   'bash -c "do_show_logs"' \
        \
        "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" \
        &
}
export -f tab_mesa_dev

# Documentation intégrée — texte affiché dans l'onglet
KERNEL_DOC="<b>Optimisation kernel pour PS4 (Jaguar / GCN 1.1)</b>

<b>Pourquoi kernel 5.15.x &gt; 6.x sur PS4 ?</b>
• GPU Sea Islands / GCN 1.1 (Liverpool) — aucun support officiel
• Kernel 5.15 : moins de régressions GCN 1.1, amdgpu plus léger,
  gestion clock/powerplay/fences plus stable
• Kernel 6.x : protections Spectre/Meltdown coûteuses sur Jaguar 1.6 GHz
  → <b>Heaven : 5.15.15 = 1200 pts | 6.15.4 = ~965 pts</b>

<b>menuconfig avec LTO visible :</b>  <tt>make LLVM=1 menuconfig</tt>
<b>Flags de compilation Jaguar :</b>
<tt>-march=btver2 -mtune=btver2 -O3 -fomit-frame-pointer -flto -pipe</tt>

<b>Bootargs PS4 recommandés :</b>
<small><tt>amdgpu.cik_support=1 amdgpu.si_support=1 amdgpu.dc=0
mitigations=off nopti spectre_v2=off noibpb noibrs
processor.max_cstate=1 idle=nomwait
amdgpu.lockup_timeout=10000</tt></small>

<b>CONFIG clés :</b>
<tt>CONFIG_LTO_CLANG_FULL=y
CONFIG_DRM_AMDGPU_CIK=y
CONFIG_DRM_AMDGPU_SI=y
CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE=y</tt>

<b>Mesa Jaguar (ligne COMPILERFLAGS) :</b>
<small><tt>-march=btver2 -mtune=btver2 -O3 -flto={nproc} -g0 -fno-semantic-interposition</tt></small>"

export KERNEL_DOC

KERNEL_SRC_FILE="$CONF_DIR/kernel-src-dir.txt"
[ ! -f "$KERNEL_SRC_FILE" ] && echo "$HOME/linux-kernel" > "$KERNEL_SRC_FILE"
export KERNEL_SRC_FILE

do_kernel_select_src() {
    local d
    d=$(yad --center --borders=10 \
        --title="Dossier des sources kernel" \
        --file --directory --filename="$(cat "$KERNEL_SRC_FILE" 2>/dev/null || echo "$HOME/")" \
        --button="Annuler:1" --button="Sélectionner:0" \
        --width=860 --height=540)
    [ $? -ne 0 ] || [ -z "$d" ] && return
    echo "$d" > "$KERNEL_SRC_FILE"
    yad_info "✓ Sources kernel définies :\n<tt>$d</tt>"
}
export -f do_kernel_select_src

do_kernel_menuconfig_standard() {
    local src
    src=$(cat "$KERNEL_SRC_FILE" 2>/dev/null || echo "$HOME/linux-kernel")
    [ ! -d "$src" ] && yad_err "Dossier sources introuvable :\n<tt>$src</tt>\nCliquez sur <b>Sélectionner les sources</b>." && return

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
read -rp "[Entrée pour fermer]"
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
    [ ! -d "$src" ] && yad_err "Dossier sources introuvable :\n<tt>$src</tt>\nCliquez sur <b>Sélectionner les sources</b>." && return

    # Vérifier clang/lld
    if ! command -v clang >/dev/null 2>&1 || ! command -v ld.lld >/dev/null 2>&1; then
        yad_err "clang ou lld non installé.\n<b>sudo apt install clang lld llvm</b>"
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
read -rp "[Entrée pour fermer]"
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
    [ ! -d "$src" ] && yad_err "Dossier sources introuvable :\n<tt>$src</tt>" && return

    if ! command -v clang >/dev/null 2>&1; then
        yad_err "clang non installé.\n<b>sudo apt install clang lld llvm</b>"
        return
    fi

    local jobs
    jobs=$(nproc)

    # Permettre à l'utilisateur d'ajuster le nb de jobs
    local out
    out=$(yad --center --borders=10 \
        --title="Compilation kernel FULL LTO — Jaguar" \
        --form \
        --text="<b>Compilation Full LTO pour PS4 (Jaguar / btver2)</b>\n\n⚠️  <b>Consomme beaucoup de RAM</b> — prévoir 24 Go minimum pour Full LTO.\nAvec 16 Go, utiliser <b>-j2</b> ou <b>-j1</b> pour éviter le freeze.\n" \
        --field="Nb de jobs (-j) :":NUM "${jobs}!1..$(nproc)!1" \
        --field="Flags supplémentaires :":TEXT "" \
        --button="Annuler:1" --button="🚀 Compiler:0" \
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
read -rp "[Entrée pour fermer]"
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
    [ ! -f "$bzimage" ] && yad_err "bzImage introuvable :\n<tt>$bzimage</tt>\nCompiler d'abord le kernel." && return

    local dst
    dst=$(yad --center --borders=10 \
        --title="Copier bzImage" \
        --form \
        --text="Destination de la copie de bzImage :" \
        --field="Destination :":TEXT "/boot/bzImage-ps4-lto" \
        --button="Annuler:1" --button="Copier:0" \
        --width=520)
    [ $? -ne 0 ] || [ -z "$dst" ] && return
    dst=$(echo "$dst" | cut -d'|' -f1)

    local tmpscript
    tmpscript=$(mktemp /tmp/hyb-cpbz-XXXX.sh)
    cat > "$tmpscript" << CPEOF
#!/bin/bash
echo "Copie de bzImage..."
sudo cp "$bzimage" "$dst" && echo "OK - bzImage copié : $dst" || echo "ERREUR copie"
echo ""
ls -lh "$dst" 2>/dev/null
echo ""
read -rp "[Entrée pour fermer]"
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
    # Afficher la documentation complète en texte brut dans yad --text-info
    local doc_text
    doc_text="Optimisation kernel 6.15.4 — PS4 Jaguar / GCN 1.1
=======================================================================

POURQUOI LE KERNEL 6.x EST PLUS LENT SUR PS4 ?
=======================================================================
La PS4 utilise un GPU Sea Islands / GCN 1.1 (Liverpool).
Aucun kernel Linux ne supporte officiellement ce matériel.

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
MENUCONFIG AVEC OPTIONS LTO VISIBLES
=======================================================================
Sans LLVM=1, les options LTO n'apparaissent pas dans menuconfig.
Commande correcte : make LLVM=1 menuconfig

=======================================================================
CONFIG .config CLÉS POUR PS4 / JAGUAR
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
FLAGS DE COMPILATION JAGUAR (btver2)
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
BOOTARGS PS4 RECOMMANDÉS
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
MÉMOIRE RAM — FULL LTO
=======================================================================
Full LTO consomme beaucoup de RAM.
Avec i3 + 16 Go : utiliser -j2 ou -j1 pour éviter le freeze.
Scripts fournis : compile-i3-fulllto-v2.sh + monitor-compilation.sh
"

    echo "$doc_text" | yad --center --borders=10 \
        --title="Documentation Kernel PS4 Jaguar" \
        --text-info --scroll \
        --width=820 --height=620 \
        --button="Fermer:0"
}
export -f do_kernel_show_doc

tab_kernel() { : ; }   # stub — intégré dans tab_kernel_boot

#========================================================================
# ONGLET 4 — Kernel & Boot
#========================================================================

tab_kernel_boot() {
    local src
    src=$(cat "$KERNEL_SRC_FILE" 2>/dev/null || echo "$HOME/linux-kernel")

    yad --plug="$KEY" --tabnum=4 \
        --form --scroll \
        --image="/usr/share/hybryde/SquareGlass/Control Panel 1.png" --image-on-top \
        --text="<big><b><span foreground='${C_KERNEL}'>🐧 Kernel &amp; Boot PS4</span></b></big>
<span foreground='${C_SECTION}'>Compilation LTO  ·  Sources Git  ·  Initramfs  ·  Déploiement  ·  Bootargs</span>
Sources actuelles : <tt>$src</tt>\n" \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ ⚡ Compilation Kernel (Jaguar / Full LTO) ━━━━━━━━━━━━━━━━</span></b>":LBL "" \
        --field="  <small><tt>-march=btver2 -mtune=btver2 · LLVM/Clang · Full LTO</tt></small>":LBL "" \
        --field="  📂 Sélectionner le dossier des sources kernel":BTN   'bash -c "do_kernel_select_src"' \
        --field="  ⚙  menuconfig standard  (make menuconfig)":BTN      'bash -c "do_kernel_menuconfig_standard"' \
        --field="  ⚡ menuconfig LLVM/LTO   (make LLVM=1 menuconfig)":BTN 'bash -c "do_kernel_menuconfig_lto"' \
        --field="  🚀 Compiler le kernel (Full LTO, -march=btver2)":BTN  'bash -c "do_kernel_compile_lto"' \
        --field="  💾 Copier bzImage dans /boot (sudo)":BTN             'bash -c "do_kernel_copy_bzimage"' \
        --field="  📖 Guide complet kernel Jaguar / LTO / Mesa":BTN    'bash -c "do_kernel_show_doc"' \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ 🐙 Sources Git Kernels PS4 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</span></b>":LBL "" \
        --field="  🚀 crashniels/linux — kernel PS4 (branche au choix)":BTN 'bash -c "do_git_ps4_kernel"' \
        --field="  🚀 feeRnt/ps4-linux-12xx — branches auto":BTN           'bash -c "do_git_feernt_kernel"' \
        --field="  🗂  fail0verflow/ps4-linux (référence originale)":BTN   'bash -c "do_git_fail0verflow"' \
        --field="  🐙 Al-Azif — profil GitHub (payloads, outils PS4)":BTN  'bash -c "do_open_url_alazif"' \
        --field="  🎮 GoldHEN — télécharger la dernière release":BTN       'bash -c "do_git_goldhen"' \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ 🔓 SDK OpenOrbis ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</span></b>":LBL "" \
        --field="  🚀 OpenOrbis PS4 Toolchain (dernière release auto)":BTN 'bash -c "do_git_orbis"' \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ 📦 Payloads Linux (ps4boot) ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</span></b>":LBL "" \
        --field="  🚀 ps4-linux-payloads — télécharger + compiler":BTN 'bash -c "do_git_payloads"' \
        --field="  📖 README GoldHEN / bzImage / initramfs":BTN         'bash -c "do_payloads_readme"' \
        --field="  ⚡ ps4-kexec — payload kexec (maillon de boot)":BTN  'bash -c "do_git_kexec"' \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ 🛠  Initramfs Builder ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</span></b>":LBL "" \
        --field="  🛠  Créer / extraire / repackager un initramfs.cpio.gz":BTN 'bash -c "do_build_initramfs"' \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ 🚀 Déploiement ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</span></b>":LBL "" \
        --field="  💾 Préparer une clé USB de boot PS4":BTN            'bash -c "do_prepare_usb"' \
        --field="  📡 Transfert FTP → /data/linux/boot/ sur la PS4":BTN 'bash -c "do_ftp_transfer"' \
        --field="  ⚙  Éditer bootargs.txt / vram.txt":BTN              'bash -c "do_edit_bootargs"' \
        --field="  📂 Ouvrir PROJECT-PS4/":BTN                         'bash -c "do_open_project_dir"' \
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
        --title="Télécharger Kernel PS4" \
        --list \
        --text="Sélectionne la branche PS4 :" \
        --column="Branche" \
        "${branches[@]}" \
        --print-column=1 --separator="" \
        --button="Annuler:1" --button="🚀 Télécharger:0" \
        --width=400 --height=280)
    
    [ $? -ne 0 ] || [ -z "$branch" ] && return
    branch="${branch//|/}"

    local dest="$KERNELS_DIR/linux-ps4-$branch"
    [ -d "$dest" ] && yad_confirm "Dossier existant :\n<tt>$dest</tt>\n\nSupprimer et re-télécharger ?" || rm -rf "$dest"
    
    run_in_term "🚀 Git PS4 Kernel — $branch" "
        cd '$KERNELS_DIR'
        echo '=== Téléchargement kernel PS4 : $branch ==='
        git clone -b '$branch' --depth=1 https://github.com/crashniels/linux.git linux-ps4-$branch
        echo '=== Sources PS4 Kernel téléchargées ==='
        ls -la
        echo ''
        read -rp '[Entrée pour ouvrir le dossier]'
        sleep 1 && xdg-open '$KERNELS_DIR/linux-ps4-$branch'
    "
    
    yad_info "✓ Kernel PS4 $branch\n📂 <tt>$dest</tt>"
}
export -f do_git_ps4_kernel

#------------------------------------------------------------------------
# feeRnt/ps4-linux-12xx — kernels PS4 alternatifs
#------------------------------------------------------------------------
do_git_feernt_kernel() {
    # Récupérer les branches dynamiquement depuis l'API GitHub
    local branches_raw
    branches_raw=$(curl -s --max-time 8 \
        "https://api.github.com/repos/feeRnt/ps4-linux-12xx/branches" \
        2>/dev/null)

    local yad_branches=()
    if [ -n "$branches_raw" ] && echo "$branches_raw" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
        # Branches récupérées depuis l'API
        while IFS= read -r b; do
            [ -n "$b" ] && yad_branches+=("$b")
        done < <(echo "$branches_raw" | python3 -c "
import sys, json
branches = json.load(sys.stdin)
# master en premier, puis les autres triés
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

    # Fallback si API inaccessible ou vide
    if [ "${#yad_branches[@]}" -eq 0 ]; then
        yad_branches=("master" "ps4-6.1.y" "ps4-6.6.y" "ps4-5.15.y")
    fi

    local branch
    branch=$(yad --center --borders=10 \
        --title="feeRnt — ps4-linux-12xx" \
        --list \
        --text="<b>feeRnt/ps4-linux-12xx</b>\nKernels PS4 alternatifs\n<small>https://github.com/feeRnt/ps4-linux-12xx</small>\n\nSélectionne une branche :" \
        --column="Branche" \
        "${yad_branches[@]}" \
        --print-column=1 --separator="" \
        --button="Annuler:1" --button="🚀 Télécharger:0" \
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
echo '=== Téléchargement feeRnt/ps4-linux-12xx ==='
echo "Branche : $branch"
echo "Destination : $dest"
echo ''
cd '$KERNELS_DIR'
git clone -b '$branch' --depth=1 \
    https://github.com/feeRnt/ps4-linux-12xx.git \
    "feeRnt-ps4-linux-$branch"

if [ \$? -ne 0 ] || [ ! -d '$dest' ]; then
    echo ''
    echo '✗ Clonage échoué'
    echo '  Vérifiez votre connexion ou que la branche existe.'
    read -rp '[Entrée pour fermer]'
    exit 1
fi

echo ''
echo '=== Contenu ==='
ls -la '$dest'
echo ''
echo "✓ feeRnt ps4-linux-12xx ($branch) téléchargé"
echo "  $dest"
echo ''
read -rp '[Entrée pour ouvrir le dossier]'
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
        yad_info "✓ feeRnt/ps4-linux-12xx ($branch) téléchargé\n📂 <tt>$dest</tt>"
}
export -f do_git_feernt_kernel
do_git_orbis() {
    local out
    out=$(yad --center --borders=10 \
        --title="OpenOrbis PS4 Toolchain" \
        --form \
        --text="<b>Installer OpenOrbis Toolchain</b>\n\n<small>Télécharge la dernière release automatiquement depuis GitHub\nhttps://github.com/OpenOrbis/OpenOrbis-PS4-Toolchain</small>\n" \
        --field="Nom du dossier :":TEXT "Orbis" \
        --button="Annuler:1" --button="🚀 Installer:0" \
        --width=540)
    [ $? -ne 0 ] || [ -z "$out" ] && return

    local dest_name
    dest_name=$(echo "$out" | cut -d'|' -f1)
    dest_name="${dest_name//|/}"
    [ -z "$dest_name" ] && dest_name="Orbis"
    local dest="$PROJECT_DIR/$dest_name"

    # Heredoc direct — bypasse run_in_term pour éviter les problèmes
    # d'interprétation des variables imbriquées et du Python inline
    local tmpscript
    tmpscript=$(mktemp /tmp/hyb-orbis-XXXX.sh)
    cat > "$tmpscript" << ORBEOF
#!/bin/bash
set -e
cd '$PROJECT_DIR'

echo '=== Installation OpenOrbis PS4 Toolchain ==='
echo "Destination : $dest"
echo ''

echo '--- Dépendances ---'
sudo apt-get update -qq
sudo apt-get install -y clang lld make curl tar python3 2>&1 | tail -5

# libssl1.1 requis par PkgTool.Core (.NET — incompatible avec libssl3)
if ! dpkg -l libssl1.1 2>/dev/null | grep -q '^ii'; then
    echo '  → Installation libssl1.1 (requis par PkgTool.Core)...'
    TMP_SSL=\$(mktemp /tmp/libssl1.1-XXXX.deb)
    curl -L --progress-bar \
        "http://security.debian.org/debian-security/pool/updates/main/o/openssl/libssl1.1_1.1.1w-0+deb11u5_amd64.deb" \
        -o "\$TMP_SSL"
    sudo dpkg -i "\$TMP_SSL" 2>&1 | tail -3
    rm -f "\$TMP_SSL"
fi

# Variable DOTNET requise pour libicu78 (Forky n'a pas libicu66)
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
grep -q 'DOTNET_SYSTEM_GLOBALIZATION_INVARIANT' "\$HOME/.bashrc" || \
    echo 'export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1' >> "\$HOME/.bashrc"
echo '✓ Dépendances OK'
echo ''

echo '--- Récupération de la dernière release ---'
API_URL="https://api.github.com/repos/OpenOrbis/OpenOrbis-PS4-Toolchain/releases/latest"
JSON=\$(curl -s "\$API_URL")
if [ -z "\$JSON" ] || echo "\$JSON" | grep -q '"message".*"Not Found"'; then
    echo '✗ Impossible de joindre l'\''API GitHub'
    echo '  Vérifiez votre connexion internet'
    read -rp '[Entrée pour fermer]'
    exit 1
fi

VERSION=\$(echo "\$JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tag_name','?'))" 2>/dev/null)
echo "Version détectée : \$VERSION"

DOWNLOAD_URL=\$(echo "\$JSON" | python3 -c "
import sys, json
data = json.load(sys.stdin)
assets = data.get('assets', [])
# Priorité 1 : contient 'linux' + .tar.gz
for asset in assets:
    name = asset['name'].lower()
    if 'linux' in name and name.endswith('.tar.gz'):
        print(asset['browser_download_url']); break
else:
    # Priorité 2 : tout .tar.gz sauf windows/mac/darwin/osx
    for asset in assets:
        name = asset['name'].lower()
        skip = any(x in name for x in ['windows', 'win', 'mac', 'darwin', 'osx', 'macos'])
        if name.endswith('.tar.gz') and not skip:
            print(asset['browser_download_url']); break
    else:
        # Priorité 3 : premier .tar.gz disponible
        for asset in assets:
            if asset['name'].lower().endswith('.tar.gz'):
                print(asset['browser_download_url']); break
" 2>/dev/null)

if [ -z "\$DOWNLOAD_URL" ]; then
    echo '✗ Aucun fichier .tar.gz trouvé dans la release'
    echo '  Assets disponibles :'
    echo "\$JSON" | python3 -c "
import sys, json
for a in json.load(sys.stdin).get('assets',[]): print('  -', a['name'])
" 2>/dev/null
    read -rp '[Entrée pour fermer]'
    exit 1
fi
echo "URL : \$DOWNLOAD_URL"
echo ''

echo '--- Téléchargement ---'
curl -L --progress-bar "\$DOWNLOAD_URL" -o /tmp/toolchain.tar.gz
if [ ! -s /tmp/toolchain.tar.gz ]; then
    echo '✗ Téléchargement échoué ou fichier vide'
    read -rp '[Entrée pour fermer]'
    exit 1
fi
SIZE=\$(stat -c%s /tmp/toolchain.tar.gz)
echo "Taille : \$(numfmt --to=iec \$SIZE 2>/dev/null || echo \$SIZE octets)"
if [ "\$SIZE" -lt 500000 ]; then
    echo '✗ Fichier trop petit — probablement une erreur'
    rm -f /tmp/toolchain.tar.gz
    read -rp '[Entrée pour fermer]'
    exit 1
fi
echo ''

echo '--- Extraction ---'
rm -rf '$dest'
mkdir -p '$dest'
tar -xzf /tmp/toolchain.tar.gz -C '$dest' --strip-components=1 2>&1 || \
    tar -xzf /tmp/toolchain.tar.gz -C '$dest' 2>&1
rm -f /tmp/toolchain.tar.gz
echo '✓ Extraction terminée'
echo ''

echo '--- Configuration .bashrc ---'
BASHRC="\$HOME/.bashrc"
grep -q 'OO_PS4_TOOLCHAIN' "\$BASHRC" || \
    echo "export OO_PS4_TOOLCHAIN='$dest'" >> "\$BASHRC"
grep -q '$dest/bin/linux' "\$BASHRC" || \
    echo "export PATH=\"\\\$PATH:$dest/bin/linux\"" >> "\$BASHRC"
export OO_PS4_TOOLCHAIN='$dest'
export PATH="\$PATH:$dest/bin/linux"
echo '✓ Variables ajoutées dans ~/.bashrc'
echo "  OO_PS4_TOOLCHAIN=$dest"
echo ''

echo '--- Contenu du SDK ---'
ls -la '$dest'
echo ''

if [ -d '$dest/samples/hello_world' ]; then
    echo '--- Test compilation hello_world ---'
    cd '$dest/samples/hello_world'
    make 2>&1 && echo '✓ Compilation réussie 🎉' || echo '⚠ Compilation échouée (ignoré)'
    echo ''
fi

echo '============================================'
echo "✓ OpenOrbis \$VERSION installé dans :"
echo "  $dest"
echo ''
echo 'Pour utiliser dans un nouveau terminal :'
echo '  source ~/.bashrc'
echo '============================================'
echo ''
read -rp '[Entrée pour ouvrir le dossier SDK]'
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
                echo '=== Compilation payloads PS4 Linux ==='
                make
                echo ''
                echo '=== Compilation terminée ==='
                ls -la
                echo ''
                read -rp '[Entrée pour fermer]'
            "
            return
        fi
    fi

    run_in_term "🚀 Git + Compilation PS4 Linux Payloads" "
        cd '$PROJECT_DIR'
        echo '=== Téléchargement ps4-linux-payloads ==='
        git clone https://github.com/ps4boot/ps4-linux-payloads
        echo ''
        echo '=== Compilation make ==='
        cd ps4-linux-payloads/linux
        make
        echo ''
        echo '=== Terminé ==='
        ls -la
        echo ''
        read -rp '[Entrée pour ouvrir le dossier]'
        sleep 1 && xdg-open '$dest'
    "
    yad_info "✓ PS4 Linux Payloads compilés\n📂 <tt>$dest</tt>"
}
export -f do_git_payloads

do_payloads_readme() {
    local readme_text="L'hôte avec des payloads Linux précompilés fonctionne uniquement avec GoldHEN v2.4b18.5/v2.4b18.6 BinLoader.
Ouvrez simplement votre navigateur web et mettez l'hôte en cache ; il fonctionnera également hors ligne.

▶️  https://ps4boot.github.io  (bouton ci-dessous pour ouvrir)

Vous trouverez des charges utiles Linux pour votre firmware, ainsi que des charges utiles supplémentaires.
Le reste est déjà inclus dans GoldHEN.

━━━  Placement automatique des fichiers de démarrage  ━━━
Le noyau (bzImage) et initramfs.cpio.gz sont désormais automatiquement copiés dans /data/linux/boot
sur le disque interne depuis la partition FAT32 externe.
→ Aucun disque externe n'est nécessaire pour l'interface de récupération, sauf lors du premier démarrage.

━━━  Heure RTC transmise à l'initramfs  ━━━
L'heure actuelle d'OrbisOS est ajoutée à la ligne de commande du noyau (time=CURRENTTIME),
garantissant que l'heure correcte est définie au démarrage au lieu de la valeur par défaut de 1970,
même si le matériel RTC ne peut pas être lu directement.
Un initramfs préparé est nécessaire pour lire l'heure depuis la ligne de commande et la définir.

━━━  Chemin interne par défaut  ━━━
  /data/linux/boot
Le reste provient de la configuration d'initialisation initramfs.cpio.gz.

Accès sans clé USB : transférez via FTP sur votre PS4 :
  /data/linux/boot/bzImage
  /data/linux/boot/initramfs.cpio.gz

Les périphériques USB sont prioritaires : si une clé est connectée, le système utilisera
bzImage et initramfs.cpio.gz depuis cette clé.

Vous pouvez ajouter un fichier texte (bootargs.txt) pour modifier la ligne de commande.
Le fichier vram.txt vous permet de modifier la VRAM via un fichier texte.

━━━  Notes importantes  ━━━
★  Avec GoldHEN v2.4b18.5/v2.4b18.6, utilisez les fichiers .elf au lieu des fichiers .bin ;
   cela fonctionne mieux et garantit un succès à 100%.

★  N'utilisez pas les charges utiles PRO pour les formats Phat ou Slim.

★  UART (si nécessaire) — actuellement désactivé, ne fonctionne pas sur noyaux récents :
     Éolie / Belize : console=uart8250,mmio32,0xd0340000
     Baïkal          : console=uart8250,mmio32,0xC890E000"

    echo "$readme_text" | yad --center --borders=12 \
        --title="📖 README — PS4 Linux Payloads" \
        --text-info --scroll \
        --width=800 --height=580 \
        --button="🌐 Ouvrir ps4boot.github.io:2" \
        --button="Fermer:0"

    local ret=$?
    [ $ret -eq 2 ] && xdg-open "https://ps4boot.github.io" >/dev/null 2>&1 &
}
export -f do_payloads_readme

#------------------------------------------------------------------------
# 1. ps4-kexec — le payload kexec pour booter Linux depuis la PS4
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
                echo '=== Recompilation ps4-kexec ==='
                make clean 2>/dev/null; make
                echo ''
                echo '=== Fichiers produits ==='
                ls -lh *.elf *.bin 2>/dev/null || ls -lh
                echo ''
                read -rp '[Entrée pour fermer]'
            "
            return
        fi
    fi

    run_in_term "🚀 Git + Compilation ps4-kexec" "
        cd '$PROJECT_DIR'
        echo '=== Téléchargement ps4-kexec ==='
        git clone https://github.com/ps4boot/ps4-kexec
        echo ''
        echo '=== Vérification dépendances ==='
        for dep in make gcc git; do
            command -v \$dep >/dev/null 2>&1 \
                && echo \"  ✓ \$dep\" \
                || echo \"  ✗ \$dep manquant — sudo apt install \$dep\"
        done
        echo ''
        echo '=== Compilation ==='
        cd ps4-kexec && make
        echo ''
        echo '=== Fichiers produits ==='
        ls -lh *.elf *.bin 2>/dev/null || ls -lh
        echo ''
        echo 'NOTE : utilisez le .elf avec GoldHEN v2.4b18.5/v2.4b18.6 BinLoader'
        echo ''
        read -rp '[Entrée pour ouvrir le dossier]'
        sleep 1 && xdg-open '$dest'
    "
    yad_info "✓ ps4-kexec compilé\n📂 <tt>$dest</tt>\n\n<small>Utilisez le .elf avec GoldHEN BinLoader</small>"
}
export -f do_git_kexec

#------------------------------------------------------------------------
# 2. fail0verflow/ps4-linux — fork original de référence
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
                echo '=== Branches disponibles ==='
                git branch -a | head -20
                echo ''
                read -rp '[Entrée pour fermer]'
            "
        fi
        return
    fi

    local branch
    branch=$(yad --center --borders=10 \
        --title="fail0verflow/ps4-linux — Branche" \
        --list \
        --text="<b>fail0verflow/ps4-linux</b>\nFork original PS4 Linux — référence historique.\nUtile pour récupérer des configs .config ou comparer des patchs.\n\nChoisissez la branche :" \
        --column="Branche" \
        --column="Description" \
        "master"    "Branche principale" \
        "ps4"       "Branche PS4 spécifique" \
        --print-column=1 --separator="" \
        --button="Annuler:1" --button="🚀 Télécharger:0" \
        --width=500 --height=240)
    [ $? -ne 0 ] || [ -z "$branch" ] && return
    branch="${branch//|/}"

    run_in_term "🚀 Git fail0verflow/ps4-linux — $branch" "
        cd '$KERNELS_DIR'
        echo '=== Téléchargement fail0verflow/ps4-linux (shallow) ==='
        echo 'Dépôt volumineux — cela peut prendre plusieurs minutes...'
        echo ''
        git clone -b '$branch' --depth=1 https://github.com/fail0verflow/ps4-linux ps4-linux-fail0verflow
        echo ''
        echo '=== Configs .config disponibles ==='
        find '$dest' -name '.config*' 2>/dev/null | head -10
        echo ''
        echo '=== Contenu ==='
        ls -la '$dest' 2>/dev/null
        echo ''
        read -rp '[Entrée pour ouvrir le dossier]'
        sleep 1 && xdg-open '$dest' 2>/dev/null
    "
    yad_info "✓ fail0verflow/ps4-linux téléchargé\n📂 <tt>$dest</tt>"
}
export -f do_git_fail0verflow

#------------------------------------------------------------------------
# GoldHEN — télécharger la dernière release
#------------------------------------------------------------------------
do_git_goldhen() {
    local dest="$PROJECT_DIR/GoldHEN"

    local out
    out=$(yad --center --borders=10 \
        --title="GoldHEN — Dernière release" \
        --form \
        --text="<b>Télécharger la dernière release de GoldHEN</b>\n\n<small>Source : https://github.com/GoldHEN/GoldHEN/releases\nLes fichiers seront téléchargés dans :\n<tt>$PROJECT_DIR/GoldHEN/</tt></small>\n" \
        --field="Dossier destination :":TEXT "$PROJECT_DIR/GoldHEN" \
        --button="Annuler:1" --button="🚀 Télécharger:0" \
        --width=580)
    [ $? -ne 0 ] || [ -z "$out" ] && return

    dest=$(echo "$out" | cut -d'|' -f1)
    dest="${dest//|/}"
    [ -z "$dest" ] && dest="$PROJECT_DIR/GoldHEN"

    local tmpscript
    tmpscript=$(mktemp /tmp/hyb-goldhen-XXXX.sh)
    cat > "$tmpscript" << GHEOF
#!/bin/bash
echo '=== Téléchargement GoldHEN — dernière release ==='
echo "Destination : $dest"
echo ''

if ! command -v curl >/dev/null 2>&1; then
    echo '✗ curl requis : sudo apt install curl'
    read -rp '[Entrée pour fermer]'
    exit 1
fi

echo '--- Récupération infos release ---'
# /releases (sans /latest) retourne TOUTES les releases y compris pre-releases
# On prend la première (la plus récente), qu'elle soit stable ou pre-release
API_URL="https://api.github.com/repos/GoldHEN/GoldHEN/releases"
JSON_ALL=\$(curl -s "\$API_URL")
if [ -z "\$JSON_ALL" ]; then
    echo '✗ Impossible de joindre l'\''API GitHub'
    read -rp '[Entrée pour fermer]'
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
echo '--- Assets disponibles ---'
ASSETS=\$(echo "\$JSON" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for a in data.get('assets', []):
    print(a['browser_download_url'], a['name'], a.get('size', 0))
" 2>/dev/null)

if [ -z "\$ASSETS" ]; then
    echo '✗ Aucun asset trouvé dans la release'
    read -rp '[Entrée pour fermer]'
    exit 1
fi

echo "\$ASSETS" | while read url name size; do
    echo "  - \$name  (\$size octets)"
done
echo ''

echo '--- Téléchargement de tous les fichiers ---'
mkdir -p '$dest'
cd '$dest'

echo "\$ASSETS" | while read url name size; do
    echo "Téléchargement : \$name"
    curl -L --progress-bar "\$url" -o "\$name"
    if [ -s "\$name" ]; then
        echo "  ✓ \$name"
    else
        echo "  ✗ Échec : \$name"
    fi
    echo ''
done

echo ''
echo '=== Contenu du dossier GoldHEN ==='
ls -lh '$dest'
echo ''
echo "✓ GoldHEN \$VERSION téléchargé dans :"
echo "  $dest"
echo ''
read -rp '[Entrée pour ouvrir le dossier]'
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
        yad_info "✓ GoldHEN téléchargé\n📂 <tt>$dest</tt>"
}
export -f do_git_goldhen

#------------------------------------------------------------------------
# 3. Préparation clé USB de boot PS4
#------------------------------------------------------------------------
do_prepare_usb() {
    # Détecter les disques USB.
    # 1) La colonne TRAN de lsblk n'est fiable QUE sur la ligne du disque
    #    entier (sdb), pas sur ses partitions (sdb1).
    # 2) Certains boîtiers/docks USB-SATA (pont ASMedia/JMicron en mode
    #    pass-through ATA) font remonter TRAN=sata au lieu de usb -> on
    #    vérifie en complément le chemin udev réel du disque, qui traverse
    #    toujours un nœud "usbX" quand il est physiquement branché en USB.
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

    if [ "${#usb_disks[@]}" -eq 0 ]; then
        yad_err "Aucune clé USB / disque externe détecté.\nConnectez le périphérique et réessayez.\n\n<small>Vérifiez avec :\nlsblk -o NAME,SIZE,FSTYPE,TRAN\nudevadm info -q path -n /dev/sdX  (doit contenir 'usb')</small>"
        return
    fi

    # On sélectionne le DISQUE entier (pas une partition) : il va être
    # entièrement repartitionné.
    local usb_list=() d dsize dmodel
    for d in "${usb_disks[@]}"; do
        dsize=$(lsblk -dn -o SIZE "/dev/$d" 2>/dev/null | tr -d ' ')
        dmodel=$(lsblk -dn -o MODEL "/dev/$d" 2>/dev/null | sed 's/ *$//')
        usb_list+=("/dev/$d" "${dsize}  |  ${dmodel:-Périphérique USB}")
    done

    local sel_dev
    sel_dev=$(yad --center --borders=10 \
        --title="Sélectionner le disque USB" \
        --list \
        --text="<b>Préparer une clé USB de boot PS4</b>\n\nSélectionnez le <b>disque</b> USB cible :\n⚠️  <b>TOUT le contenu du disque sera EFFACÉ</b> (le disque va être entièrement repartitionné)." \
        --column="Disque" \
        --column="Taille  |  Modèle" \
        "${usb_list[@]}" \
        --print-column=1 --separator="" \
        --button="Annuler:1" --button="Sélectionner:0" \
        --width=620 --height=300)
    [ $? -ne 0 ] || [ -z "$sel_dev" ] && return
    sel_dev="${sel_dev//|/}"

    # Taille totale du disque, pour calculer le maximum possible pour la
    # partition ext4 (disque - 130 Mio pour le FAT32 - petite marge).
    local disk_bytes max_gb
    disk_bytes=$(lsblk -bdn -o SIZE "$sel_dev" 2>/dev/null)
    max_gb=$(( (disk_bytes - 140*1024*1024) / (1024*1024*1024) ))
    [ "$max_gb" -lt 1 ] && max_gb=1

    # Chercher bzImage / initramfs par défaut dans le projet
    local bzimage_default=""
    for k in "$KERNELS_DIR"/*/arch/x86/boot/bzImage; do
        [ -f "$k" ] && bzimage_default="$k" && break
    done
    if [ -z "$bzimage_default" ]; then
        local kdir
        kdir=$(cat "$CONF_DIR/kernel-src-dir.txt" 2>/dev/null)
        [ -f "$kdir/arch/x86/boot/bzImage" ] && bzimage_default="$kdir/arch/x86/boot/bzImage"
    fi
    local initramfs_default=""
    [ -f "$PROJECT_DIR/ps4-linux-payloads/linux/initramfs.cpio.gz" ] && \
        initramfs_default="$PROJECT_DIR/ps4-linux-payloads/linux/initramfs.cpio.gz"

    # Formulaire étape 1 : label FAT32 + nombre de partitions ext4
    local step1
    step1=$(yad --center --borders=10 \
        --title="Partitionner le disque USB" \
        --form \
        --text="<b>Partitionnement de $sel_dev</b>\n\n<span foreground='red'><b>⚠️  TOUT le contenu de $sel_dev sera détruit.</b></span>\n\nUne partition <b>FAT32</b> de 130 Mo sera créée en premier (reçoit bzImage / initramfs / bootargs / vram), suivie d'une ou plusieurs partitions <b>ext4</b>.\n" \
        --field="Label partition FAT32 :":TEXT              "PS4BOOT" \
        --field="Nombre de partitions ext4 (1 à 4) :":NUM   "1!1..4!1" \
        --button="Annuler:1" --button="Suivant :0" \
        --width=620)
    [ $? -ne 0 ] || [ -z "$step1" ] && return
    local lbl_fat nb_ext4
    lbl_fat=$(echo "$step1"  | cut -d'|' -f1)
    nb_ext4=$(echo "$step1"  | cut -d'|' -f2)
    [ -z "$lbl_fat" ] && lbl_fat="PS4BOOT"
    [ -z "$nb_ext4" ] && nb_ext4=1

    # Formulaire étape 2 : taille + label de chaque partition ext4
    local default_size=$(( max_gb / nb_ext4 ))
    [ "$default_size" -lt 1 ] && default_size=1
    local ext4_fields=() i
    for ((i = 1; i <= nb_ext4; i++)); do
        ext4_fields+=(--field="Taille partition ext4 #$i (Go) :":NUM "${default_size}!1..${max_gb}!1")
        ext4_fields+=(--field="Label partition ext4 #$i :":TEXT "PS4ROOT$([ "$i" -gt 1 ] && echo "$i")")
    done
    ext4_fields+=(--field="La dernière partition ext4 utilise tout l'espace restant :":CHK "TRUE")

    local step2
    step2=$(yad --center --borders=10 \
        --title="Partitions ext4" \
        --form \
        --text="<b>Configuration des partitions ext4</b>\n\nEspace disponible après le FAT32 (130 Mo) : environ ${max_gb} Go.\n<small>Si la case ci-dessous est cochée, la taille saisie pour la dernière partition est ignorée : elle prendra tout l'espace restant.</small>\n" \
        "${ext4_fields[@]}" \
        --button="Annuler:1" --button="Suivant :0" \
        --width=680)
    [ $? -ne 0 ] || [ -z "$step2" ] && return

    local -a vals
    IFS='|' read -ra vals <<< "$step2"
    local -a ext4_sizes=() ext4_labels=()
    local idx=0
    for ((i = 1; i <= nb_ext4; i++)); do
        ext4_sizes+=("${vals[$idx]}");  idx=$((idx + 1))
        ext4_labels+=("${vals[$idx]}"); idx=$((idx + 1))
        [ -z "${ext4_sizes[$((i-1))]}" ]  && ext4_sizes[$((i-1))]=$default_size
        [ -z "${ext4_labels[$((i-1))]}" ] && ext4_labels[$((i-1))]="PS4ROOT$([ "$i" -gt 1 ] && echo "$i")"
    done
    local autofill_last="${vals[$idx]}"

    # Validation de la somme des tailles demandées
    local sum=0 last_idx=$((nb_ext4 - 1))
    for ((i = 0; i < nb_ext4; i++)); do
        [ "$autofill_last" = "TRUE" ] && [ "$i" -eq "$last_idx" ] && continue
        sum=$((sum + ext4_sizes[i]))
    done
    if [ "$sum" -gt "$max_gb" ]; then
        yad_err "La somme des tailles demandées (${sum} Go) dépasse l'espace disponible (${max_gb} Go).\nRecommencez avec des tailles plus petites."
        return
    fi

    # Fichiers de boot
    local out
    out=$(yad --center --borders=10 \
        --title="Fichiers de boot" \
        --form \
        --text="<b>Fichiers copiés à la racine de la partition FAT32 « $lbl_fat »</b>\n" \
        --field="bzImage :":FL "${bzimage_default:-$PROJECT_DIR/}" \
        --field="initramfs.cpio.gz :":FL "${initramfs_default:-$PROJECT_DIR/}" \
        --field="Créer bootargs.txt :":CHK "FALSE" \
        --field="Créer vram.txt :":CHK "FALSE" \
        --field="Je confirme vouloir EFFACER $sel_dev :":CHK "FALSE" \
        --button="Annuler:1" --button="🚀 Partitionner et préparer:0" \
        --width=700)
    [ $? -ne 0 ] || [ -z "$out" ] && return

    IFS='|' read -r bzimage_src initramfs_src do_bootargs do_vram confirm_erase <<< "$out"
    bzimage_src="${bzimage_src//|/}"
    initramfs_src="${initramfs_src//|/}"

    if [ "$confirm_erase" != "TRUE" ]; then
        yad_err "Vous devez cocher la case de confirmation pour effacer $sel_dev."
        return
    fi

    local copy_bz="" copy_init=""
    [ -f "$bzimage_src" ]   && copy_bz="$bzimage_src"
    [ -f "$initramfs_src" ] && copy_init="$initramfs_src"

    local bootargs_val="" vram_val=""
    if [ "$do_bootargs" = "TRUE" ] || [ "$do_vram" = "TRUE" ]; then
        local bv_out
        bv_out=$(yad --center --borders=10 \
            --title="Contenu des fichiers texte" \
            --form \
            --text="<b>Contenu des fichiers optionnels</b>\n\n<small>bootargs.txt : arguments passés au kernel\nvram.txt     : taille VRAM en Mo (ex: 256)</small>\n" \
            --field="bootargs.txt :":TEXT "amdgpu.cik_support=1 amdgpu.si_support=1 amdgpu.dc=0 mitigations=off nopti" \
            --field="vram.txt (Mo) :":TEXT "256" \
            --button="Annuler:1" --button="OK:0" \
            --width=700)
        [ $? -ne 0 ] || [ -z "$bv_out" ] && return
        bootargs_val=$(echo "$bv_out" | cut -d'|' -f1)
        vram_val=$(echo "$bv_out"     | cut -d'|' -f2)
    fi

    # Résumé du plan de partitionnement pour la confirmation finale
    local plan_txt=" • FAT32 \"$lbl_fat\" — 130 Mo\n"
    for ((i = 0; i < nb_ext4; i++)); do
        if [ "$autofill_last" = "TRUE" ] && [ "$i" -eq "$last_idx" ]; then
            plan_txt+=" • ext4  \"${ext4_labels[$i]}\" — tout l'espace restant\n"
        else
            plan_txt+=" • ext4  \"${ext4_labels[$i]}\" — ${ext4_sizes[$i]} Go\n"
        fi
    done

    # Dernière confirmation explicite (bouton rouge)
    yad --center --borders=10 --title="⚠️ Confirmation finale" \
        --text="<span foreground='red'><b>DERNIÈRE CONFIRMATION</b></span>\n\nLe disque <b>$sel_dev</b> va être <b>entièrement effacé et repartitionné</b> :\n\n${plan_txt}\nCette action est <b>irréversible</b>.\n" \
        --button="Annuler:1" --button="Oui, effacer et partitionner:0" \
        --width=520
    [ $? -ne 0 ] && return

    # Nom des partitions : sdX1/sdX2/... en général, mais mmcblk0p1/nvme0n1p1
    # si le nom du disque se termine par un chiffre.
    partdev() {
        if [[ "$sel_dev" =~ [0-9]$ ]]; then
            echo "${sel_dev}p$1"
        else
            echo "${sel_dev}$1"
        fi
    }
    local p1; p1=$(partdev 1)
    local -a pext=()
    for ((i = 1; i <= nb_ext4; i++)); do
        pext+=("$(partdev $((i + 1)))")
    done

    # Construction des commandes parted (calcul des offsets en MiB)
    local parted_cmds="" mkfs_cmds="" start=131
    local end=""
    for ((i = 0; i < nb_ext4; i++)); do
        if [ "$autofill_last" = "TRUE" ] && [ "$i" -eq "$last_idx" ]; then
            end="100%"
        else
            end="$((start + ext4_sizes[i]*1024))MiB"
        fi
        parted_cmds+="sudo parted -s '$sel_dev' mkpart primary ext4 ${start}MiB ${end}
"
        mkfs_cmds+="echo '--- Formatage ext4 #$((i+1)) (${pext[$i]}) ---'
sudo mkfs.ext4 -F -L '${ext4_labels[$i]}' '${pext[$i]}'
"
        [ "$end" != "100%" ] && start=$((start + ext4_sizes[i]*1024))
    done

    # Résumé final (texte)
    local summary_txt="  Partition 1 (FAT32, $p1, boot)   : $lbl_fat\n"
    for ((i = 0; i < nb_ext4; i++)); do
        if [ "$autofill_last" = "TRUE" ] && [ "$i" -eq "$last_idx" ]; then
            summary_txt+="  Partition $((i+2)) (ext4,  ${pext[$i]}) : ${ext4_labels[$i]} (reste du disque)\n"
        else
            summary_txt+="  Partition $((i+2)) (ext4,  ${pext[$i]}) : ${ext4_labels[$i]} (${ext4_sizes[$i]} Go)\n"
        fi
    done

    local tmpscript
    tmpscript=$(mktemp /tmp/hyb-usb-XXXX.sh)
    cat > "$tmpscript" << UEOF
#!/bin/bash
set -e
echo '=== Préparation clé USB boot PS4 ==='
echo "Disque : $sel_dev"
echo ''

echo '--- Démontage des partitions existantes ---'
for p in \$(lsblk -lnpo NAME '$sel_dev' 2>/dev/null | tail -n +2); do
    sudo umount "\$p" 2>/dev/null || true
done

echo '--- Création de la table de partitions (msdos) ---'
sudo parted -s '$sel_dev' mklabel msdos

echo '--- Création partition 1 : FAT32 130 Mo ---'
sudo parted -s '$sel_dev' mkpart primary fat32 1MiB 131MiB
sudo parted -s '$sel_dev' set 1 boot on

echo '--- Création des partitions ext4 ---'
$parted_cmds
sudo partprobe '$sel_dev' 2>/dev/null || true
sleep 2

echo '--- Formatage FAT32 ($p1) ---'
sudo mkfs.vfat -F 32 -n '$lbl_fat' '$p1'

$mkfs_cmds

echo ''
echo '--- Montage de la partition FAT32 ---'
MNT=\$(mktemp -d /tmp/ps4usb-XXXX)
sudo mount '$p1' "\$MNT"

$([ -n "$copy_bz" ] && echo "echo '--- Copie bzImage ---'
sudo cp '$copy_bz' \"\$MNT/bzImage\"
echo '  ✓ bzImage copié'")

$([ -n "$copy_init" ] && echo "echo '--- Copie initramfs.cpio.gz ---'
sudo cp '$copy_init' \"\$MNT/initramfs.cpio.gz\"
echo '  ✓ initramfs.cpio.gz copié'")

$([ "$do_bootargs" = "TRUE" ] && echo "echo '--- Création bootargs.txt ---'
echo '$bootargs_val' | sudo tee \"\$MNT/bootargs.txt\" >/dev/null
echo '  ✓ bootargs.txt créé'")

$([ "$do_vram" = "TRUE" ] && echo "echo '--- Création vram.txt ---'
echo '$vram_val' | sudo tee \"\$MNT/vram.txt\" >/dev/null
echo '  ✓ vram.txt créé'")

echo ''
echo '=== Contenu de la partition FAT32 ($lbl_fat) ==='
ls -lh "\$MNT/" 2>/dev/null

sync
sudo umount "\$MNT"
rmdir "\$MNT" 2>/dev/null

echo ''
echo '✓ Clé USB prête — vous pouvez la retirer.'
echo -e "$summary_txt"
read -rp '[Entrée pour fermer]'
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
# 4. Transfert FTP vers la PS4 (bzImage + initramfs → /data/linux/boot)
#------------------------------------------------------------------------
PS4_FTP_IP_FILE="$CONF_DIR/ps4-ftp-ip.txt"
export PS4_FTP_IP_FILE

do_ftp_transfer() {
    local last_ip
    last_ip=$(cat "$PS4_FTP_IP_FILE" 2>/dev/null || echo "192.168.1.")

    # Chercher bzImage dans le projet
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
        --button="Annuler:1" --button="🚀 Envoyer:0" \
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

    # Vérifier que curl est disponible
    if ! command -v curl >/dev/null 2>&1; then
        yad_err "curl est requis.\n<b>sudo apt install curl</b>"
        return
    fi

    local files_to_send=()
    [ -f "$bz_src" ]   && files_to_send+=("$bz_src")
    [ -f "$init_src" ] && files_to_send+=("$init_src")

    if [ "${#files_to_send[@]}" -eq 0 ]; then
        yad_err "Aucun fichier valide sélectionné."
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
        echo "read -rp '[Entrée pour fermer]'"
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
        --button="Annuler:1" \
        --button="💾 Sauvegarder:0" \
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
        --button="Annuler:1" --button="OK:0" \
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
        yad_err "Outils manquants : <b>${missing_tools[*]}</b>\n<tt>sudo apt install ${missing_tools[*]}</tt>"
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
        --button="Annuler:1" --button="OK:0" \
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
    read -rp '[Entrée pour fermer]'
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
echo 'Pour repackager → relancez le builder et choisissez "Repackager"'
echo ''
read -rp '[Entrée pour ouvrir le dossier]'
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
                --title="Sélectionner l'initramfs à extraire" \
                --file --filename="$PROJECT_DIR/" \
                --file-filter="initramfs | *.cpio.gz *.cpio *.gz" \
                --button="Annuler:1" --button="Sélectionner:0" \
                --width=860 --height=540)
            [ $? -ne 0 ] || [ -z "$src_cpio" ] && return

            local tmpscript
            tmpscript=$(mktemp /tmp/hyb-extract-initramfs-XXXX.sh)
            cat > "$tmpscript" << EXEOF
#!/bin/bash
echo '=== Extraction initramfs ==='
mkdir -p '$INITRAMFS_DIR'
cd '$INITRAMFS_DIR'
echo "Source : $src_cpio"
echo ''
case "$src_cpio" in
    *.gz) zcat '$src_cpio' | cpio -idm --quiet ;;
    *)    cpio -idm --quiet < '$src_cpio' ;;
esac
echo '✓ Extraction terminée'
echo ''
echo '=== Contenu ==='
ls -la
echo ''
read -rp '[Entrée pour ouvrir le dossier]'
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
                yad_err "Dossier initramfs introuvable :\n<tt>$INITRAMFS_DIR</tt>\nCréez d'abord la structure avec 'Créer'." && return

            local out_file="$PROJECT_DIR/initramfs.cpio.gz"
            local out_choice
            out_choice=$(yad --center --borders=10 \
                --title="Destination du repackage" \
                --form \
                --text="<b>Repackager en initramfs.cpio.gz</b>\n\nSource : <tt>$INITRAMFS_DIR</tt>" \
                --field="Fichier de sortie :":FL "$out_file" \
                --button="Annuler:1" --button="🚀 Repackager:0" \
                --width=680)
            [ $? -ne 0 ] || [ -z "$out_choice" ] && return
            out_file=$(echo "$out_choice" | cut -d'|' -f1)

            local tmpscript
            tmpscript=$(mktemp /tmp/hyb-repack-initramfs-XXXX.sh)
            cat > "$tmpscript" << RPEOF
#!/bin/bash
echo '=== Repackage initramfs ==='
echo "Source  : $INITRAMFS_DIR"
echo "Sortie  : $out_file"
echo ''
cd '$INITRAMFS_DIR'
find . | cpio -o -H newc 2>/dev/null | gzip -9 > '$out_file'
echo "✓ Créé : $out_file"
echo ""
ls -lh '$out_file'
echo ''
echo 'Vous pouvez maintenant :'
echo '  → Copier sur clé USB  (onglet : Préparer clé USB)'
echo '  → Transférer via FTP  (onglet : Transfert FTP PS4)'
echo ''
read -rp '[Entrée pour fermer]'
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
                yad_err "Dossier initramfs introuvable :\n<tt>$INITRAMFS_DIR</tt>\nCréez d'abord la structure." && return

            local script_name
            local out_s
            out_s=$(yad --center --borders=10 \
                --title="Ajouter un script à l'initramfs" \
                --form \
                --text="<b>Ajouter un script dans l'initramfs</b>\n\nLe script sera créé dans <tt>$INITRAMFS_DIR/</tt>" \
                --field="Nom du script :":TEXT "custom-init.sh" \
                --field="Contenu :":TXT "#!/bin/sh\n# Script personnalisé\necho 'Hello from PS4 initramfs'\n" \
                --button="Annuler:1" --button="Créer:0" \
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
# Al-Azif — profil GitHub
#------------------------------------------------------------------------
do_open_url_alazif() {
    xdg-open "https://github.com/Al-Azif" >/dev/null 2>&1 &
    yad_info "🐙 <b>Al-Azif</b>

Ouverture du profil GitHub...

<small>Vous y trouverez ses outils PS4 :
payloads, exploits, firmware dumps et plus.</small>

<tt>https://github.com/Al-Azif</tt>"
}
export -f do_open_url_alazif

#------------------------------------------------------------------------
# Ouvrir le dossier projet
#------------------------------------------------------------------------
do_open_project_dir() {
    xdg-open "$PROJECT_DIR" >/dev/null 2>&1 &
    yad_info "📂 Projet ouvert :\n<tt>$PROJECT_DIR</tt>"
}

tab_git_ps4() {
    yad --plug="$KEY" --tabnum=10 \
        --form --scroll \
        --image="/usr/share/hybryde/SquareGlass/Java 1.png" --image-on-top \
        --text="<big><b><span foreground='#F48FB1'>🚀 GIT PS4 — Kernels + Orbis + Payloads + Déploiement</span></b></big>

<b>PROJET :</b> <tt>$PROJECT_DIR</tt>

Télécharge, compile et déploie tout l'écosystème PS4 Linux.\n" \
        \
        --field="":LBL "" \
        --field="<b>— KERNELS PS4 (crashniels/linux) —</b>":LBL "" \
        --field="  🚀 crashniels/linux — kernel PS4 (branche au choix)":BTN 'bash -c "do_git_ps4_kernel"' \
        --field="  🚀 feeRnt/ps4-linux-12xx — kernel PS4 (branches auto)":BTN 'bash -c "do_git_feernt_kernel"' \
        --field="  🗂  fail0verflow/ps4-linux (référence originale)":BTN 'bash -c "do_git_fail0verflow"' \
        --field="  🐙 Al-Azif — profil GitHub (payloads, outils PS4)":BTN 'bash -c "do_open_url_alazif"' \
        --field="  🎮 GoldHEN — télécharger la dernière release":BTN 'bash -c "do_git_goldhen"' \
        \
        --field="":LBL "" \
        --field="<b>— ORBIS (SDK PS4) —</b>":LBL "" \
        --field="  🚀 OpenOrbis PS4 Toolchain (dernière release auto)":BTN 'bash -c "do_git_orbis"' \
        \
        --field="":LBL "" \
        --field="<b>— PAYLOADS LINUX (ps4boot) —</b>":LBL "" \
        --field="  🚀 ps4-linux-payloads — télécharger + compiler":BTN 'bash -c "do_git_payloads"' \
        --field="  📖 README GoldHEN / bzImage / initramfs":BTN 'bash -c "do_payloads_readme"' \
        --field="  ⚡ ps4-kexec — payload kexec (maillon de boot)":BTN 'bash -c "do_git_kexec"' \
        \
        --field="":LBL "" \
        --field="<b>— DÉPLOIEMENT —</b>":LBL "" \
        --field="  💾 Préparer une clé USB de boot PS4":BTN 'bash -c "do_prepare_usb"' \
        --field="  📡 Transfert FTP → /data/linux/boot/ sur la PS4":BTN 'bash -c "do_ftp_transfer"' \
        \
        --field="":LBL "" \
        --field="<b>— CONFIGURATION KERNEL —</b>":LBL "" \
        --field="  ⚙  Éditer bootargs.txt / vram.txt":BTN 'bash -c "do_edit_bootargs"' \
        \
        --field="":LBL "" \
        --field="<b>— INITRAMFS BUILDER —</b>":LBL "" \
        --field="  🛠  Créer / extraire / repackager un initramfs.cpio.gz":BTN 'bash -c "do_build_initramfs"' \
        --field="  <small><i>→ Basé sur busybox statique — supporte le script init PS4 RTC</i></small>":LBL "" \
        \
        --field="":LBL "" \
        --field="<b>— Projet —</b>":LBL "" \
        --field="  📂 Ouvrir PROJECT-PS4/":BTN 'bash -c "do_open_project_dir"' \
        \
        --field="Kernels  : <tt>$KERNELS_DIR</tt>":LBL "" \
        --field="Orbis    : <tt>$ORBIS_DIR</tt>":LBL "" \
        --field="Payloads : <tt>$PROJECT_DIR/ps4-linux-payloads</tt>":LBL "" \
        --field="kexec    : <tt>$PROJECT_DIR/ps4-kexec</tt>":LBL "" \
        --field="initramfs: <tt>$INITRAMFS_DIR</tt>":LBL "" \
        \
        "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" \
        &
}

#========================================================================

#========================================================================
# ONGLET 13 — Téléchargements DionKill (scraping live)
#========================================================================

# ── Formater une taille en octets → lisible ────────────────────────────
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

# ── Récupérer la taille d'un fichier distant (HEAD + Content-Length) ───
do_dl_get_size() {
    local url="$1"
    local bytes
    bytes=$(curl -sI --max-time 12 -L "$url" \
        | awk 'tolower($1)=="content-length:"{val=$2} END{print val+0}' \
        | tr -d '\r')
    echo "${bytes:-0}"
}
export -f do_dl_get_size

# ── Téléchargement wget avec reprise (-c) et terminal ─────────────────
do_dl_wget() {
    local url="$1"
    local dest="$2"
    mkdir -p "$(dirname "$dest")"

    # Taille avant download
    local size_bytes size_str
    size_bytes=$(do_dl_get_size "$url")
    size_str=$(do_dl_fmt_size "$size_bytes")

    # Échapper & pour Pango dans les champs YAD
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
echo "║  ⬇  PS4 Tools — Téléchargement                                 ║"
echo "╚═════════════════════════════════════════════════════════════════╝"
echo ""
echo "  Fichier : $(basename "$dest")"
echo "  Taille  : $size_str"
echo "  Dest    : $(dirname "$dest")"
echo ""
echo "  URL : $url"
echo ""
echo "  (wget -c  →  reprise automatique si fichier partiel)"
echo "─────────────────────────────────────────────────────────────────"
echo ""
wget -c --show-progress --progress=bar:force "$url" -O "${dest}.part"
RET=\$?
echo ""
if [ \$RET -eq 0 ]; then
    mv -f "${dest}.part" "$dest"
    echo "  ✓ Succès — fichier disponible :"
    echo "    $dest"
else
    echo "  ✗ Erreur (code \$RET)"
    echo "    Le fichier partiel est conservé : ${dest}.part"
    echo "    Relancez pour reprendre le téléchargement."
fi
echo ""
read -rp "[Entrée pour fermer]"
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

# ── GitHub API : lister les assets d'une release ──────────────────────
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

# ── Sélection interactive d'un asset GitHub avec liste YAD ────────────
do_dl_pick_github() {
    local gh_url="$1"
    local dest_dir="$2"
    local entry_name="$3"

    # Spinner pendant l'appel API
    local PID_W
    yad --center --borders=10 --title="GitHub API…" \
        --text="🔄 <b>Récupération des assets GitHub…</b>\n\n<small><tt>$gh_url</tt></small>" \
        --no-buttons --width=520 &
    PID_W=$!

    local assets
    assets=$(do_dl_github_assets "$gh_url")
    local api_ret=$?
    kill "$PID_W" 2>/dev/null; wait "$PID_W" 2>/dev/null

    if [ $api_ret -ne 0 ] || [ -z "$assets" ]; then
        yad_confirm "⚠  Aucun asset binaire trouvé via l'API GitHub.\n\n<b>$entry_name</b>\n<small><tt>$gh_url</tt></small>\n\nOuvrir la page dans le navigateur ?" \
            && xdg-open "$gh_url" &
        return
    fi

    # Construire les arguments liste YAD
    # Col 1 (HD) = URL (print-column=1), Col 2 = Tag, Col 3 = Fichier, Col 4 = Taille
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
            --text="<b>Release :</b> <tt>$first_tag</tt>\n\nSélectionnez le fichier à télécharger :\n\n<small>💡 Préférez <tt>bzImage_Clang_thinLTO</tt> si disponible · Reprise auto avec <tt>-c</tt></small>\n" \
            --column="URL":HD \
            --column="Tag":TEXT \
            --column="Fichier":TEXT \
            --column="Taille":TEXT \
            "${list_args[@]}" \
            --print-column=1 \
            --button="Fermer:1" \
            --button="🌐 Navigateur:3" \
            --button="⬇ Télécharger:0" \
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
            --button="Annuler:1" \
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
                    --button="Annuler:1" --button="Suivant:0" \
                    --width=380) || return
                mega_pass=$(yad --center --borders=10 \
                    --title="Connexion Mega.nz" \
                    --entry --entry-label="Mot de passe :" \
                    --hide-text \
                    --button="Annuler:1" --button="Se connecter:0" \
                    --width=380) || return
                mega-login "$mega_user" "$mega_pass"
                if [ $? -ne 0 ]; then
                    yad_err "❌ Échec de connexion à Mega.\n\nVérifiez vos identifiants."
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
    echo "  ✓ Succès — fichier disponible dans :"
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
read -rp "[Entrée pour fermer]"
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

    [ -z "$url" ] && yad_err "Aucune URL associée à cette entrée." && return

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
        # Mega.nz → mega-get (mega-cmd) si disponible, sinon navigateur
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
        yad_err "Dépendances manquantes : <b>${missing[*]}</b>\n\n<tt>sudo apt install ${missing[*]}</tt>"
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
        yad_err "❌ Impossible de contacter <tt>dionkill.github.io</tt>\n\nVérifiez votre connexion internet."
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
            --title="⬇  Téléchargements PS4 Linux — DionKill" \
            --list \
            --text="<big><b><span foreground='#4FC3F7'>⬇  Téléchargements PS4 Linux</span></b></big>\n<small>Source : <tt>https://dionkill.github.io/ps4-linux-tutorial/files.html</tt>  —  <b>$nb_entries entrées</b></small>

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
            --button="⬇ Télécharger:0" \
            --button="Fermer:1" \
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
        --text="<big><b><span foreground='#4FC3F7'>⬇  Téléchargements PS4 Linux</span></b></big>
<span foreground='#81D4FA'>Scraping live · DionKill · Kernels, Initramfs, Distros</span>

<b>Destinations automatiques :</b>
  🐧 Kernels    → <tt>$DL_KERNELS_DIR</tt>
  💾 Initramfs  → <tt>$DL_INITRAMFS_DIR</tt>
  📦 Distros    → <tt>$DL_DISTROS_DIR</tt>

<small><i>La liste est lue en direct depuis dionkill.github.io à chaque ouverture.
Mega.nz → mega-get (mega-cmd) · Forum / YouTube → navigateur automatique.
GitHub releases → sélection d'asset via GitHub API.
Reprise de téléchargement interrompu : wget -c</i></small>\n" \
        \
        --field="":LBL "" \
        --field="<b>— Gestionnaire de téléchargements —</b>":LBL "" \
        --field="  ⬇  Ouvrir le gestionnaire (scraping live + liste YAD)":BTN 'bash -c "do_dl_manager"' \
        --field="  <small><i>→ Scrape dionkill.github.io · tri par type · taille avant download · reprise wget -c</i></small>":LBL "" \
        \
        --field="":LBL "" \
        --field="<b>— Dossiers de destination —</b>":LBL "" \
        --field="  📂 Ouvrir kernels  (<tt>system/kernels</tt>)":BTN "bash -c \"xdg-open '$DL_KERNELS_DIR' &\"" \
        --field="  📂 Ouvrir initramfs (<tt>system/initramfs</tt>)":BTN "bash -c \"xdg-open '$DL_INITRAMFS_DIR' &\"" \
        --field="  📂 Ouvrir distros  (<tt>system/distros</tt>)":BTN "bash -c \"xdg-open '$DL_DISTROS_DIR' &\"" \
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
# ONGLET 11 — Communauté PS4 Linux
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
Ressources communautaires, tutoriels, téléchargements et aide en ligne.\n" \
        \
        --field="":LBL "" \
        --field="<b>— Dionkill — PS4 Linux Tutorial —</b>":LBL "" \
        --field="  🌐 Ouvrir ps4-linux-tutorial (dionkill.github.io)":BTN 'bash -c "do_open_url_dionkill"' \
        --field="  <small><i>All In One pour PS4 : bzImage, initramfs, tutorials, fichiers prêts à l'emploi.</i></small>":LBL "" \
        \
        --field="":LBL "" \
        --field="<b>— noob404 — PS4Linux.com —</b>":LBL "" \
        --field="  🌐 Ouvrir ps4linux.com (noob404)":BTN 'bash -c "do_open_url_ps4linux"' \
        --field="  <small><i>Forum, aide, tutoriels, téléchargements et autres ressources PS4 Linux.</i></small>":LBL "" \
        \
        --field="":LBL "" \
        --field="<b>— Liens utiles —</b>":LBL "" \
        --field="  <small><tt>https://dionkill.github.io/ps4-linux-tutorial/files.html</tt></small>":LBL "" \
        --field="  <small><tt>https://ps4linux.com/downloads/#PS4_Linux_Kernel_Source</tt></small>":LBL "" \
        \
        "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" \
        &
}

# LANCEMENT DES ONGLETS EN ARRIÈRE-PLAN
#========================================================================

# Exports onglet 11 — toutes les fonctions doivent être définies avant cet appel
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

# Exports onglet communauté
export -f do_open_url_dionkill
export -f do_open_url_ps4linux
export -f tab_communaute

# Exports onglet 13 — téléchargements DionKill
export -f do_dl_fmt_size
export -f do_dl_get_size
export -f do_dl_wget
export -f do_dl_github_assets
export -f do_dl_pick_github
export -f do_dl_dispatch
export -f do_dl_manager
export -f tab_downloads

#========================================================================
# ONGLET 14 — Crédits & Remerciements
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
# ONGLET 5 — Hub (Communauté + Docs + Téléchargements)
#========================================================================

tab_hub() {
    # ── Construire les champs docs dynamiquement ──────────────────────
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
        --text="<big><b><span foreground='${C_HUB}'>🌍 Hub PS4 Linux</span></b></big>
<span foreground='${C_SECTION}'>Communauté  ·  Documentation  ·  Téléchargements DionKill</span>\n" \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ 🌍 Communauté ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</span></b>":LBL "" \
        \
        --field="  🐙 <b>theflow0</b> — Pionnier PS4 Linux (kernel, kexec, drivers)":BTN \
            'bash -c "do_open_url_theflow"' \
        --field="  <small><tt>https://github.com/theflow0</tt></small>":LBL "" \
        \
        --field="  📖 <b>Dionkill</b> — PS4 Linux Tutorial (All-In-One)":BTN \
            'bash -c "do_open_url_dionkill"' \
        --field="  <small><tt>https://dionkill.github.io/ps4-linux-tutorial/</tt></small>":LBL "" \
        \
        --field="  🌍 <b>noob404</b> — PS4Linux.com (forum, aide, ressources)":BTN \
            'bash -c "do_open_url_ps4linux"' \
        --field="  <small><tt>https://ps4linux.com</tt></small>":LBL "" \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ ⬇  Téléchargements DionKill ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</span></b>":LBL "" \
        --field="  <small>Kernels → <tt>$DL_KERNELS_DIR</tt></small>":LBL "" \
        --field="  <small>Initramfs → <tt>$DL_INITRAMFS_DIR</tt></small>":LBL "" \
        --field="  <small>Distros → <tt>$DL_DISTROS_DIR</tt></small>":LBL "" \
        --field="  ⬇  Ouvrir le gestionnaire (scraping live + liste)":BTN \
            'bash -c "do_dl_manager"' \
        --field="  📂 Ouvrir le dossier system/":BTN \
            "bash -c \"xdg-open '$PROJECT_DIR/system' &\"" \
        \
        --field="":LBL "" \
        --field="<b><span foreground='${C_SECTION}'>━━ 📖 Documentation PDF ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</span></b>":LBL "" \
        --field="  <small>🔍 Aperçu = texte page 1 + bouton lecteur  ·  📂 Ouvrir = lecteur PDF direct</small>":LBL "" \
        "${fields_docs[@]}" \
        \
        "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" \
        &
}
export -f tab_hub

#========================================================================
# LANCEMENT DES ONGLETS EN ARRIÈRE-PLAN
#========================================================================

# Exports infrastructure
export -f log_entry
export -f do_show_logs
export -f do_open_settings
export -f notify_ps4
export -f do_check_deps_full

# Exports onglet dashboard
export -f tab_dashboard

# Exports onglet systeme
export -f tab_systeme

# Exports onglet mesa_dev
export -f tab_mesa_dev

# Exports onglet kernel_boot
export -f tab_kernel_boot

# Exports onglet 11 — fonctions git (déjà exportées plus haut)
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

# Exports onglet communauté / hub
export -f do_open_url_dionkill
export -f do_open_url_ps4linux
export -f tab_communaute
export -f tab_hub

# Exports onglet 13 — téléchargements DionKill
export -f do_dl_fmt_size
export -f do_dl_get_size
export -f do_dl_wget
export -f do_dl_github_assets
export -f do_dl_pick_github
export -f do_dl_dispatch
export -f do_dl_manager
export -f tab_downloads

# Exports crédits
export -f tab_credits

# ── Lancement en parallèle ────────────────────────────────────────────
tab_dashboard   &
tab_systeme     &
tab_mesa_dev    &
tab_kernel_boot &
tab_hub         &
tab_credits     &

#========================================================================
# FENÊTRE PRINCIPALE
#========================================================================

yad --notebook \
    --window-icon="applications-system" \
    --title="Hybryde PS4 Tools v2.0" \
    --width=1000 --height=740 \
    --image="$LOGO" \
    --image-on-top \
    --text="<span size='x-large'><b><span foreground='${C_TITRE}'>Hybryde PS4 Tools</span></b></span>  <small><span foreground='${C_SECTION}'>v2.0 — by Triki1</span></small>
<small><span foreground='${C_SECTION}'>Tableau de bord  ·  Système  ·  Mesa &amp; Dev  ·  Kernel &amp; Boot  ·  Hub  ·  Crédits</span></small>" \
    --button="⚙ Préférences:2" \
    --button="📋 Logs:3" \
    --button="Fermer:0" \
    --key="$KEY" \
    --tab="🏠 Tableau de bord" \
    --tab="💿 Système &amp; Stockage" \
    --tab="🔧 Mesa &amp; Dev" \
    --tab="🐧 Kernel &amp; Boot" \
    --tab="🌍 Hub PS4 Linux" \
    --tab="🏆 Crédits" \
    --active-tab=1

ret=$?
case $ret in
    2) do_open_settings ;;
    3) do_show_logs     ;;
esac
