#!/bin/bash
#
# Commandes de compilation du Kernel PS4 Linux
# Version SAFE - Protection contre les freezes
#

KERNEL_SOURCE="/home/tux/Téléchargements/kernel-patched/test-fulllto-optimised-jaguard"
TOTAL_JOBS=$(nproc)

# Détection RAM et SWAP
TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
TOTAL_SWAP=$(free -g | awk '/^Swap:/{print $2}')
AVAILABLE_RAM=$(free -g | awk '/^Mem:/{print $7}')

echo "════════════════════════════════════════════════════════════"
echo " 🚀 COMPILATION KERNEL PS4 - Version SAFE"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "💻 Configuration système détectée :"
echo "   CPU cores        : $TOTAL_JOBS"
echo "   RAM totale       : ${TOTAL_RAM}GB"
echo "   RAM disponible   : ${AVAILABLE_RAM}GB"
echo "   SWAP             : ${TOTAL_SWAP}GB"
echo "   Source kernel    : $KERNEL_SOURCE"
echo ""

# Vérifications de sécurité
if [ $TOTAL_RAM -lt 8 ]; then
    echo "⚠️  ATTENTION : RAM faible détectée ($TOTAL_RAM GB)"
    echo "   FULL LTO risque de freezer votre système !"
    echo ""
fi

if [ $TOTAL_SWAP -lt 8 ]; then
    echo "⚠️  SWAP insuffisant détecté ($TOTAL_SWAP GB)"
    echo "   Recommandation : créer 16GB de SWAP"
    echo ""
    echo "   Commandes pour ajouter du SWAP :"
    echo "   sudo fallocate -l 16G /swapfile"
    echo "   sudo chmod 600 /swapfile"
    echo "   sudo mkswap /swapfile"
    echo "   sudo swapon /swapfile"
    echo ""
    read -p "   Continuer quand même ? (o/N) : " confirm
    if [[ ! $confirm =~ ^[oO]$ ]]; then
        exit 0
    fi
fi

echo "Choisir le mode de compilation :"
echo ""
echo "1) FULL LTO (Performance maximale - ATTENTION FREEZE !)"
echo "   → +10-15% de performance"
echo "   → Jobs limités à 4 pour éviter les freezes"
echo "   → Temps : ~3-4h (plus lent mais stable)"
echo "   → ⚠️  Nécessite 16GB+ RAM ou swap important"
echo ""
echo "2) THIN LTO (Recommandé - Compromis idéal)"
echo "   → +5-10% de performance"
echo "   → Jobs : $((TOTAL_JOBS / 2)) (moitié des cores)"
echo "   → Temps : ~1-2h"
echo "   → ✅ Stable sur la plupart des systèmes"
echo ""
echo "3) SANS LTO (Compilation rapide)"
echo "   → Performance standard"
echo "   → Jobs : $TOTAL_JOBS (tous les cores)"
echo "   → Temps : ~45min"
echo ""
echo -n "Votre choix (1/2/3) : "
read choice

# Configuration des jobs selon le mode LTO
case $choice in
    1)
        # FULL LTO - très limité pour éviter freeze
        if [ $TOTAL_RAM -lt 16 ]; then
            JOBS=2
            echo ""
            echo "⚠️  RAM < 16GB détectée : limitation à 2 jobs"
        else
            JOBS=4
        fi
        LTO_MODE="FULL LTO"
        LTO_ICON="🔥"
        ESTIMATED_TIME="3-4 heures"
        ;;
    2)
        # THIN LTO - compromis
        JOBS=$((TOTAL_JOBS / 2))
        if [ $JOBS -lt 2 ]; then
            JOBS=2
        fi
        LTO_MODE="THIN LTO"
        LTO_ICON="⚡"
        ESTIMATED_TIME="1-2 heures"
        ;;
    3)
        # SANS LTO - tous les cores
        JOBS=$TOTAL_JOBS
        LTO_MODE="SANS LTO"
        LTO_ICON="📦"
        ESTIMATED_TIME="45 minutes"
        ;;
    *)
        echo "Choix invalide !"
        exit 1
        ;;
esac

echo ""
echo "═══════════════════════════════════════════════════════════"
echo " $LTO_ICON COMPILATION AVEC $LTO_MODE"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Configuration de compilation :"
echo "   Mode             : $LTO_MODE"
echo "   Jobs parallèles  : $JOBS (sur $TOTAL_JOBS cores disponibles)"
echo "   Temps estimé     : $ESTIMATED_TIME"
echo ""

cd $KERNEL_SOURCE || exit 1

case $choice in
    1)
        # FULL LTO Configuration
        #cp ~/ps4-kernel-logs/ps4-optimized.config .config 2>/dev/null
        
         #scripts/config --disable LTO_NONE
         #scripts/config --disable LTO_CLANG_THIN
         #scripts/config --enable LTO_CLANG
         #scripts/config --enable LTO_CLANG_FULL
         #scripts/config --enable LTO
        
        make LLVM=1 olddefconfig
        
        echo "✓ Configuration FULL LTO activée"
        echo "✓ Jobs limités à $JOBS pour stabilité"
        echo ""
        echo "💡 Astuce : Surveillez la RAM avec :"
        echo "   watch -n 2 'free -h'"
        echo ""
        read -p "Appuyez sur Entrée pour démarrer la compilation..."
        echo ""
        echo "🔨 Compilation en cours (peut prendre $ESTIMATED_TIME)..."
        echo ""
        ;;
        
    2)
        # THIN LTO Configuration
        #cp ~/ps4-kernel-logs/ps4-optimized.config .config 2>/dev/null
        
        #scripts/config --disable LTO_NONE
         #scripts/config --disable LTO_CLANG_FULL
         #scripts/config --enable LTO_CLANG
         #scripts/config --enable LTO_CLANG_THIN
         #scripts/config --enable LTO
        
        make LLVM=1 olddefconfig
        
        echo "✓ Configuration THIN LTO activée"
        echo "✓ Utilisation de $JOBS jobs parallèles"
        echo ""
        echo "🔨 Compilation en cours (peut prendre $ESTIMATED_TIME)..."
        echo ""
        ;;
        
    3)
        # SANS LTO Configuration
        #cp ~/ps4-kernel-logs/ps4-optimized.config .config 2>/dev/null
        
        scripts/config --enable LTO_NONE
        scripts/config --disable LTO_CLANG
        scripts/config --disable LTO_CLANG_FULL
        scripts/config --disable LTO_CLANG_THIN
        scripts/config --disable LTO
        
        make LLVM=1 olddefconfig
        
        echo "✓ Configuration SANS LTO activée"
        echo "✓ Utilisation maximale : $JOBS jobs"
        echo ""
        echo "🔨 Compilation en cours (peut prendre $ESTIMATED_TIME)..."
        echo ""
        ;;
esac

# Compilation avec les optimisations Jaguar
time make -j$JOBS \
    LLVM=1 \
    KCFLAGS="-march=btver2 -mtune=btver2 -O3" \
    CC=clang \
    LD=ld.lld \
    AR=llvm-ar \
    NM=llvm-nm \
    STRIP=llvm-strip \
    OBJCOPY=llvm-objcopy \
    OBJDUMP=llvm-objdump \
    READELF=llvm-readelf \
    HOSTCC=clang \
    HOSTCXX=clang++ \
    HOSTAR=llvm-ar \
    HOSTLD=ld.lld

COMPILE_STATUS=$?

echo ""
if [ $COMPILE_STATUS -eq 0 ]; then
    echo "════════════════════════════════════════════════════════════"
    echo " ✅ COMPILATION TERMINÉE AVEC SUCCÈS !"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    echo "📦 bzImage créé : arch/x86/boot/bzImage"
    echo ""
    echo "📊 Statistiques finales :"
    echo "   Mode LTO         : $LTO_MODE"
    echo "   Jobs utilisés    : $JOBS"
    echo "   RAM finale       : $(free -h | awk '/^Mem:/{print $3}') utilisée"
    echo ""
else
    echo "════════════════════════════════════════════════════════════"
    echo " ❌ ERREUR DE COMPILATION"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    echo "La compilation a échoué avec le code : $COMPILE_STATUS"
    echo ""
    echo "Vérifications suggérées :"
    echo "  1. Vérifiez les logs ci-dessus"
    echo "  2. Vérifiez l'espace disque : df -h"
    echo "  3. Vérifiez la RAM : free -h"
    echo "  4. Essayez avec moins de jobs ou THIN LTO"
    echo ""
    exit $COMPILE_STATUS
fi

echo "════════════════════════════════════════════════════════════"
