#!/bin/bash
set -euo pipefail

# S'assurer que modprobe/swapon/etc. sont trouvés (PATH parfois incomplet avec sudo/systemd)
export PATH="/usr/sbin:/sbin:/usr/bin:/bin:${PATH}"

# --- Configuration ---
SIZE="2G"
DEVICE="/dev/zram0"
PRIORITY=100

echo "==> Setup ZRAM swap (${SIZE}) sur ${DEVICE}"

# 1. Charger le module zram si besoin
if ! lsmod | grep -q '^zram'; then
    echo "Chargement du module zram..."
    modprobe zram num_devices=1
fi

# 2. Si zram0 existe déjà et est actif en swap, on désactive proprement avant de reconfigurer
if swapon --show=NAME --noheadings | grep -q "^${DEVICE}$"; then
    echo "Désactivation du swap existant sur ${DEVICE}..."
    swapoff "${DEVICE}"
fi

# 3. Réinitialiser le device s'il a déjà une taille configurée
if [ -e "/sys/block/zram0/disksize" ]; then
    CURRENT_SIZE=$(cat /sys/block/zram0/disksize)
    if [ "${CURRENT_SIZE}" != "0" ]; then
        echo "Reset du device zram0..."
        echo 1 > /sys/block/zram0/reset
    fi
fi

# 4. Si zram0 n'existe pas du tout, on le crée via hot_add
if [ ! -e "/sys/block/zram0" ]; then
    echo 1 > /sys/class/zram-control/hot_add
fi

# 5. Configurer l'algorithme de compression (zstd = bon compromis ratio/CPU)
if [ -e "/sys/block/zram0/comp_algorithm" ]; then
    if grep -q "zstd" /sys/block/zram0/comp_algorithm; then
        echo "zstd" > /sys/block/zram0/comp_algorithm
        echo "Algorithme de compression : zstd"
    fi
fi

# 6. Définir la taille
echo "${SIZE}" > /sys/block/zram0/disksize

# 7. Créer et activer le swap
mkswap "${DEVICE}"
swapon -p "${PRIORITY}" "${DEVICE}"

echo "==> ZRAM configuré avec succès :"
swapon --show
