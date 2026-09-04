#!/bin/bash
#
# Compilation FULL LTO pour i3 - MODE ULTRA-CONSERVATEUR
# Optimisé pour éviter les freezes sur systèmes à RAM limitée
#

KERNEL_SOURCE="/home/tux/Téléchargements/kernel-patched/test-fulllto-optimised-jaguard"

echo "════════════════════════════════════════════════════════════"
echo " 🔥 COMPILATION FULL LTO - MODE i3 ULTRA-SAFE"
echo "════════════════════════════════════════════════════════════"
echo ""

# Détection système
TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
TOTAL_SWAP=$(free -g | awk '/^Swap:/{print $2}')
CORES=$(nproc)

echo "💻 Configuration détectée :"
echo "   Processeur : i3 ($CORES cores)"
echo "   RAM totale : ${TOTAL_RAM}GB"
echo "   SWAP       : ${TOTAL_SWAP}GB"
echo ""

# ÉTAPE 1 : Configuration SWAP critique
echo "🔧 ÉTAPE 1 : Configuration SWAP pour FULL LTO"
echo "════════════════════════════════════════════════════════════"
echo ""

CURRENT_SWAPPINESS=$(cat /proc/sys/vm/swappiness)
echo "Swappiness actuel : $CURRENT_SWAPPINESS"

if [ $CURRENT_SWAPPINESS -lt 60 ]; then
    echo ""
    echo "⚠️  ATTENTION : Swappiness trop bas !"
    echo "   Le système refuse d'utiliser le SWAP → freeze assuré"
    echo ""
    echo "Application de la configuration optimale pour FULL LTO..."
    
    sudo sysctl vm.swappiness=60
    sudo sysctl vm.vfs_cache_pressure=50
    
    echo "✓ Swappiness réglé à 60 (SWAP utilisé plus tôt)"
    echo "✓ Cache pressure réglé à 50"
else
    echo "✓ Swappiness OK ($CURRENT_SWAPPINESS)"
fi

echo ""
read -p "Appuyez sur Entrée pour continuer..."
echo ""

# ÉTAPE 2 : Choix du nombre de JOBS
echo "🔧 ÉTAPE 2 : Choix du nombre de JOBS parallèles"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Pour FULL LTO sur i3, recommandations selon votre RAM :"
echo ""
echo "1) 1 JOB  (Ultra-safe - AUCUN risque de freeze)"
echo "   RAM utilisée : ~6-8GB max"
echo "   Temps estimé : 5-6 heures"
echo "   ✅ Recommandé si RAM ≤ 8GB"
echo ""
echo "2) 2 JOBS (Compromis - Risque faible)"
echo "   RAM utilisée : ~10-12GB max"
echo "   Temps estimé : 3-4 heures"
echo "   ⚠️  Nécessite 12GB+ RAM ou swap actif"
echo ""
echo "3) ANNULER et utiliser THIN LTO (Sage choix !)"
echo "   RAM utilisée : ~4-6GB"
echo "   Temps estimé : 1h30"
echo "   ✅ Performance similaire sans les galères"
echo ""
echo -n "Votre choix (1/2/3) : "
read jobs_choice

case $jobs_choice in
    1)
        JOBS=1
        EST_TIME="5-6 heures"
        SAFETY="MAXIMUM ✅"
        ;;
    2)
        JOBS=2
        EST_TIME="3-4 heures"
        SAFETY="MOYEN ⚠️"
        
        if [ $TOTAL_RAM -lt 10 ]; then
            echo ""
            echo "⚠️  AVERTISSEMENT : RAM détectée < 10GB"
            echo "   2 jobs risquent de freezer"
            echo ""
            read -p "Continuer quand même ? (o/N) : " confirm
            if [[ ! $confirm =~ ^[oO]$ ]]; then
                echo "Compilation annulée. Relancez avec 1 job."
                exit 0
            fi
        fi
        ;;
    3)
        echo ""
        echo "Sage décision ! THIN LTO est un meilleur choix pour i3."
        echo "Utilisez plutôt : ./compile-commands-safe.sh"
        echo "Et choisissez l'option 2 (THIN LTO)"
        exit 0
        ;;
    *)
        echo "Choix invalide !"
        exit 1
        ;;
esac

echo ""
echo "════════════════════════════════════════════════════════════"
echo " 🔥 CONFIGURATION FINALE"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Mode compilation  : FULL LTO"
echo "Jobs parallèles   : $JOBS"
echo "Sécurité          : $SAFETY"
echo "Temps estimé      : $EST_TIME"
echo "Swappiness        : $(cat /proc/sys/vm/swappiness)"
echo ""
echo "⚠️  IMPORTANT :"
echo "   - Fermez TOUS les programmes inutiles"
echo "   - Ne touchez pas au PC pendant la compilation"
echo "   - Surveillez avec : watch -n 5 'free -h'"
echo ""
read -p "Tout est prêt ? Appuyez sur Entrée pour démarrer..."

# ÉTAPE 3 : Préparation finale
echo ""
echo "🔧 ÉTAPE 3 : Libération de la RAM"
echo "════════════════════════════════════════════════════════════"
echo ""

# Vider les caches pour libérer de la RAM
echo "Libération des caches système..."
sync
sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'
sleep 2

RAM_FREE=$(free -h | awk '/^Mem:/{print $7}')
echo "✓ RAM disponible : $RAM_FREE"
echo ""

# ÉTAPE 4 : Compilation
cd $KERNEL_SOURCE || exit 1

echo "🔧 ÉTAPE 4 : Configuration du Kernel"
echo "════════════════════════════════════════════════════════════"
echo ""

# Configuration FULL LTO
#scripts/config --disable LTO_NONE
#scripts/config --disable LTO_CLANG_THIN
#scripts/config --enable LTO_CLANG
#scripts/config --enable LTO_CLANG_FULL
#scripts/config --enable LTO

make LLVM=1 olddefconfig

echo "✓ Configuration FULL LTO activée"
echo ""

echo "🔥 ÉTAPE 5 : COMPILATION EN COURS"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "⏱️  Début : $(date +%H:%M:%S)"
echo "⏱️  Fin estimée : $(date -d "+$EST_TIME" +%H:%M:%S 2>/dev/null || echo 'N/A')"
echo ""
echo "💡 Surveillez la RAM dans un autre terminal :"
echo "   watch -n 5 'free -h && echo && swapon --show'"
echo ""
echo "🚀 Compilation démarrée avec $JOBS job(s)..."
echo ""

# Compilation avec monitoring intégré
(
    while true; do
        sleep 30
        MEM_USED=$(free | awk '/^Mem:/ {print int($3*100/$2)}')
        SWAP_USED=$(free | awk '/^Swap:/ {if($2>0) print int($3*100/$2); else print 0}')
        echo "[$(date +%H:%M:%S)] RAM: ${MEM_USED}% | SWAP: ${SWAP_USED}%"
        
        if [ $MEM_USED -gt 95 ] && [ $SWAP_USED -eq 0 ]; then
            echo "⚠️  ALERTE : RAM critique mais SWAP non utilisé !"
        fi
    done
) &
MONITOR_PID=$!

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

# Arrêter le monitoring
kill $MONITOR_PID 2>/dev/null

echo ""
if [ $COMPILE_STATUS -eq 0 ]; then
    echo "════════════════════════════════════════════════════════════"
    echo " ✅ SUCCÈS ! FULL LTO compilé sur i3 !"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    echo "📦 bzImage : arch/x86/boot/bzImage"
    echo ""
    echo "📊 Statistiques finales :"
    echo "   Jobs utilisés    : $JOBS"
    echo "   RAM max          : $(free -h | awk '/^Mem:/{print $3}')"
    echo "   SWAP max         : $(free -h | awk '/^Swap:/{print $3}')"
    echo "   Durée totale     : Voir ci-dessus"
    echo ""
    echo "🎉 Bravo ! FULL LTO réussi malgré l'i3 !"
else
    echo "════════════════════════════════════════════════════════════"
    echo " ❌ ÉCHEC DE LA COMPILATION"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    echo "Code erreur : $COMPILE_STATUS"
    echo ""
    echo "Solutions :"
    echo "  1. Réessayez avec 1 job au lieu de $JOBS"
    echo "  2. Vérifiez que le SWAP est actif : swapon --show"
    echo "  3. Augmentez le SWAP à 16GB minimum"
    echo ""
    exit $COMPILE_STATUS
fi
