#!/usr/bin/env bash
# ==============================================================================
#  mesa-installdir-merge.sh
#  Fusionne les builds i386 et amd64 de Mesa dans un dossier output unifié.
#  Doit être lancé en root.
# ==============================================================================

set -euo pipefail

# --- Vérification root ---
if [[ "$EUID" -ne 0 ]]; then
    echo "[ERREUR] Ce script doit être lancé en root (sudo ou su)." >&2
    exit 1
fi

# --- Chemins ---
BASE="/home/ps4linux/mesa-git/installdir"
SRC_I386="${BASE}/build-i386-opt/install"
SRC_AMD64="${BASE}/build-amd64-opt/install"
OUTPUT="${BASE}/output"
OUT_USR="${OUTPUT}/usr"
OUT_LIB_I386="${OUT_USR}/lib/i386-linux-gnu"
OUT_LIB_AMD64="${OUT_USR}/lib/x86_64-linux-gnu"

# --- Vérification des sources ---
for dir in "$SRC_I386" "$SRC_AMD64"; do
    if [[ ! -d "$dir" ]]; then
        echo "[ERREUR] Dossier source introuvable : $dir" >&2
        exit 1
    fi
done

echo "=== Création de l'arborescence output ==="
mkdir -p "$OUT_LIB_I386"
mkdir -p "$OUT_LIB_AMD64"
echo "  [OK] ${OUT_LIB_I386}"
echo "  [OK] ${OUT_LIB_AMD64}"

# ==============================================================================
# ÉTAPE 1 — Copie du build i386
# ==============================================================================
echo ""
echo "=== Copie build i386 → ${OUT_USR} ==="

for dir in bin share include; do
    if [[ -d "${SRC_I386}/${dir}" ]]; then
        echo "  Copie i386/${dir} ..."
        cp -a "${SRC_I386}/${dir}" "${OUT_USR}/"
        echo "  [OK] ${dir}"
    else
        echo "  [WARN] ${SRC_I386}/${dir} absent, ignoré."
    fi
done

echo "  Copie contenu i386/lib/ → ${OUT_LIB_I386} ..."
if [[ -d "${SRC_I386}/lib" ]]; then
    cp -a "${SRC_I386}/lib/." "${OUT_LIB_I386}/"
    echo "  [OK] lib i386"
else
    echo "  [WARN] ${SRC_I386}/lib absent, ignoré."
fi

# ==============================================================================
# ÉTAPE 2 — Copie du build amd64 (écrase les fichiers existants)
# ==============================================================================
echo ""
echo "=== Copie build amd64 → ${OUT_USR} (écrasement) ==="

for dir in bin include share; do
    if [[ -d "${SRC_AMD64}/${dir}" ]]; then
        echo "  Copie amd64/${dir} ..."
        cp -af "${SRC_AMD64}/${dir}/." "${OUT_USR}/${dir}/"
        echo "  [OK] ${dir}"
    else
        echo "  [WARN] ${SRC_AMD64}/${dir} absent, ignoré."
    fi
done

echo "  Copie contenu amd64/lib/ → ${OUT_LIB_AMD64} ..."
if [[ -d "${SRC_AMD64}/lib" ]]; then
    cp -a "${SRC_AMD64}/lib/." "${OUT_LIB_AMD64}/"
    echo "  [OK] lib amd64"
else
    echo "  [WARN] ${SRC_AMD64}/lib absent, ignoré."
fi

# ==============================================================================
# ÉTAPE 3 — Copie de etc (amd64) → output/
# ==============================================================================
echo ""
echo "=== Copie amd64/etc/ → ${OUTPUT} ==="
if [[ -d "${SRC_AMD64}/etc" ]]; then
    cp -a "${SRC_AMD64}/etc" "${OUTPUT}/"
    echo "  [OK] etc"
else
    echo "  [WARN] ${SRC_AMD64}/etc absent, ignoré."
fi

# ==============================================================================
# Résumé
# ==============================================================================
echo ""
echo "=== Terminé ! Arborescence output ==="
find "$OUTPUT" -maxdepth 4 -print | sort
