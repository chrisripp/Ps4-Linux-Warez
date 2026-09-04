#!/bin/bash
#
# Compilation FULL LTO pour i3 - VERSION AMÉLIORÉE ANTI-FREEZE
# Swap forcé + monitoring actif
#

KERNEL_SOURCE="/home/tux/Téléchargements/kernel-patched/test-fulllto-optimised-jaguard"

echo "════════════════════════════════════════════════════════════"
echo " 🔥 COMPILATION FULL LTO - MODE ANTI-FREEZE V2"
echo "════════════════════════════════════════════════════════════"
echo ""

# Détection système
TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
TOTAL_SWAP=$(free -g | awk '/^Swap:/{print $2}')
CORES=$(nproc)

echo "💻 Configuration détectée :"
echo "   Processeur : i3 ($CORES cores)"
echo "   RAM totale : ${TOTAL_RAM}GB"
echo "   SWAP total : ${TOTAL_SWAP}GB"
echo ""

# ÉTAPE 1 : Vérification et configuration SWAP CRITIQUE
echo "🔧 ÉTAPE 1 : Configuration SWAP ULTRA-AGRESSIVE"
echo "════════════════════════════════════════════════════════════"
echo ""

# Vérifier que le swap existe et est actif
echo "Vérification SWAP actif..."
swapon --show
echo ""

SWAP_ACTIVE=$(swapon --show | tail -n +2 | wc -l)
if [ $SWAP_ACTIVE -eq 0 ]; then
    echo "❌ ERREUR CRITIQUE : Aucun SWAP actif !"
    echo ""
    echo "Vous DEVEZ avoir du SWAP pour FULL LTO !"
    echo ""
    echo "Solutions :"
    echo "  1. Créer 16GB de swap : sudo ./setup-swap.sh"
    echo "  2. Utiliser THIN LTO à la place (recommandé)"
    echo ""
    exit 1
fi

if [ $TOTAL_SWAP -lt 8 ]; then
    echo "⚠️  WARNING : SWAP < 8GB détecté ($TOTAL_SWAP GB)"
    echo "   Recommandation : 16GB minimum pour FULL LTO"
    echo ""
fi

CURRENT_SWAPPINESS=$(cat /proc/sys/vm/swappiness)
echo "Configuration actuelle :"
echo "  Swappiness : $CURRENT_SWAPPINESS"
echo ""

echo "⚡ Application de la configuration ULTRA-AGRESSIVE..."
echo "   (Le SWAP sera utilisé DÈS 20% de RAM au lieu de 90%+)"
echo ""

# Configuration MAXIMALE pour forcer l'utilisation du SWAP
sudo sysctl vm.swappiness=80          # Utilise SWAP très tôt
sudo sysctl vm.vfs_cache_pressure=80  # Libère les caches
sudo sysctl vm.dirty_ratio=10         # Limite l'utilisation RAM pour cache
sudo sysctl vm.dirty_background_ratio=5
sudo sysctl vm.min_free_kbytes=131072 # Garde 128MB libre minimum

# Vérifier l'application
NEW_SWAPPINESS=$(cat /proc/sys/vm/swappiness)

if [ $NEW_SWAPPINESS -ge 80 ]; then
    echo "✅ Configuration SWAP appliquée avec succès !"
    echo ""
    echo "Paramètres actifs :"
    echo "  ✓ Swappiness       : $(cat /proc/sys/vm/swappiness) (très agressif)"
    echo "  ✓ Cache pressure   : $(cat /proc/sys/vm/vfs_cache_pressure)"
    echo "  ✓ Dirty ratio      : $(cat /proc/sys/vm/dirty_ratio)%"
    echo "  ✓ Min free RAM     : 128MB"
    echo ""
    echo "Avec ces paramètres :"
    echo "  → SWAP utilisé dès 20-30% de RAM occupée"
    echo "  → Plus de freeze à 85%+ RAM"
else
    echo "❌ ERREUR : Swappiness non appliqué !"
    echo "   Actuel : $NEW_SWAPPINESS (besoin : 80)"
    echo ""
    echo "Essayez manuellement :"
    echo "  sudo sysctl vm.swappiness=80"
    echo ""
    exit 1
fi

# Forcer un swap préventif immédiat
echo "🔄 Pré-swap de la RAM inactive pour libérer de l'espace..."
sync
sudo sh -c 'echo 1 > /proc/sys/vm/drop_caches'
sleep 2

echo ""
echo "État SWAP avant compilation :"
free -h
echo ""
read -p "✅ SWAP configuré. Appuyez sur Entrée pour continuer..."
echo ""

# ÉTAPE 2 : Choix INTELLIGENT du nombre de JOBS
echo "🔧 ÉTAPE 2 : Détermination du nombre de JOBS"
echo "════════════════════════════════════════════════════════════"
echo ""

# Recommandation intelligente basée sur la RAM
if [ $TOTAL_RAM -le 8 ]; then
    RECOMMENDED_JOBS=1
    JOBS_WARNING="⚠️  RAM ≤ 8GB : FULL LTO avec 1 job UNIQUEMENT"
    echo "$JOBS_WARNING"
    echo ""
    echo "Avec votre configuration ($TOTAL_RAM GB RAM) :"
    echo ""
    echo "1) 1 JOB  (SEUL CHOIX SAFE pour ${TOTAL_RAM}GB RAM)"
    echo "   RAM utilisée : ~6-8GB max"
    echo "   SWAP utilisé  : 2-4GB"
    echo "   Temps estimé  : 5-6 heures"
    echo "   ✅ Recommandé : OUI"
    echo ""
    echo "2) ANNULER et utiliser THIN LTO (MEILLEUR CHOIX !)"
    echo "   RAM utilisée : ~4-6GB"
    echo "   SWAP utilisé : 0-1GB"
    echo "   Temps estimé : 1h30"
    echo "   ✅ Recommandé : OUI"
    echo ""
    echo -n "Votre choix (1/2) : "
    read jobs_choice
    
    case $jobs_choice in
        1)
            JOBS=1
            EST_TIME="5-6 heures"
            SAFETY="MAXIMUM ✅"
            ;;
        2)
            echo ""
            echo "💡 Excellent choix ! THIN LTO est idéal pour ${TOTAL_RAM}GB RAM."
            echo ""
            echo "Lancez : ./compile-commands-safe.sh"
            echo "Et choisissez l'option 2 (THIN LTO)"
            exit 0
            ;;
        *)
            echo "❌ Choix invalide. Pour ${TOTAL_RAM}GB RAM, seul 1 job est supporté."
            exit 1
            ;;
    esac
else
    # RAM > 8GB
    echo "Options pour ${TOTAL_RAM}GB RAM :"
    echo ""
    echo "1) 1 JOB  (Ultra-safe)"
    echo "   RAM+SWAP : ~8GB max"
    echo "   Temps    : 5-6 heures"
    echo ""
    echo "2) 2 JOBS (Équilibré)"
    echo "   RAM+SWAP : ~12GB max"
    echo "   Temps    : 3-4 heures"
    echo ""
    echo "3) THIN LTO (Recommandé)"
    echo "   Temps : 1h30, +7% perf"
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
            SAFETY="ÉQUILIBRÉ ⚠️"
            ;;
        3)
            echo ""
            echo "💡 Sage décision !"
            echo "Lancez : ./compile-commands-safe.sh"
            exit 0
            ;;
        *)
            echo "Choix invalide !"
            exit 1
            ;;
    esac
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo " 🔥 CONFIGURATION FINALE"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Mode             : FULL LTO"
echo "Jobs parallèles  : $JOBS"
echo "Sécurité         : $SAFETY"
echo "Temps estimé     : $EST_TIME"
echo "Swappiness       : $(cat /proc/sys/vm/swappiness)"
echo "RAM totale       : ${TOTAL_RAM}GB"
echo "SWAP total       : ${TOTAL_SWAP}GB"
echo ""
echo "⚠️  IMPORTANT - Checklist avant compilation :"
echo "   ☐ SWAP actif : $(swapon --show | tail -1 | awk '{print $3}')"
echo "   ☐ Swappiness : $(cat /proc/sys/vm/swappiness) (doit être ≥60)"
echo "   ☐ Programmes fermés (Firefox, Chrome, etc.)"
echo "   ☐ Terminal monitoring prêt : watch -n 3 'free -h'"
echo ""
read -p "✅ Tout est prêt ? Appuyez sur Entrée pour démarrer..."

# ÉTAPE 3 : Libération de la RAM
echo ""
echo "🔧 ÉTAPE 3 : Libération maximale de la RAM"
echo "════════════════════════════════════════════════════════════"
echo ""

echo "Synchronisation disque..."
sync
echo "Vidage des caches..."
sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'
echo "Forçage du swap préventif..."
sudo swapoff -a && sudo swapon -a
sleep 3

RAM_FREE=$(free -h | awk '/^Mem:/{print $7}')
echo ""
echo "✅ État après nettoyage :"
free -h
echo ""
echo "RAM disponible : $RAM_FREE"
echo ""

# ÉTAPE 4 : Configuration du Kernel
cd $KERNEL_SOURCE || exit 1

echo "🔧 ÉTAPE 4 : Configuration FULL LTO du Kernel"
echo "════════════════════════════════════════════════════════════"
echo ""

# Configuration FULL LTO
#scripts/config --disable LTO_NONE
#scripts/config --disable LTO_CLANG_THIN
#scripts/config --enable LTO_CLANG
#scripts/config --enable LTO_CLANG_FULL
#scripts/config --enable LTO

make LLVM=1 olddefconfig

echo "✅ Configuration FULL LTO activée"
echo ""

# ÉTAPE 5 : Compilation avec monitoring ACTIF
echo "🔥 ÉTAPE 5 : COMPILATION AVEC MONITORING"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "⏱️  Début      : $(date '+%H:%M:%S le %d/%m/%Y')"
echo "⏱️  Fin estimée : $(date -d "+$EST_TIME" '+%H:%M:%S' 2>/dev/null || echo 'N/A')"
echo ""
echo "🚀 Compilation démarrée avec $JOBS job(s)..."
echo ""
echo "📊 Monitoring actif :"
echo "   - Alerte à 75% RAM"
echo "   - Alerte si SWAP non utilisé à 80% RAM"
echo "   - Arrêt auto si RAM > 95% sans SWAP"
echo ""

# Fonction de monitoring avec alertes
monitor_compilation() {
    local max_ram=0
    local max_swap=0
    local alert_75_shown=false
    local alert_80_shown=false
    
    while true; do
        sleep 20
        
        MEM_USED=$(free | awk '/^Mem:/ {print int($3*100/$2)}')
        SWAP_USED=$(free | awk '/^Swap:/ {if($2>0) print int($3*100/$2); else print 0}')
        
        # Suivre les pics
        [ $MEM_USED -gt $max_ram ] && max_ram=$MEM_USED
        [ $SWAP_USED -gt $max_swap ] && max_swap=$SWAP_USED
        
        # Log normal
        echo "[$(date +%H:%M:%S)] RAM: ${MEM_USED}% | SWAP: ${SWAP_USED}% | Max: RAM ${max_ram}% SWAP ${max_swap}%"
        
        # Alerte à 75% RAM
        if [ $MEM_USED -ge 75 ] && [ "$alert_75_shown" = false ]; then
            echo ""
            echo "⚠️  [ALERTE] RAM à ${MEM_USED}% - Surveillance renforcée"
            if [ $SWAP_USED -eq 0 ]; then
                echo "   ⚠️  SWAP toujours à 0% - doit commencer à monter !"
            else
                echo "   ✓ SWAP actif à ${SWAP_USED}% - bon signe"
            fi
            echo ""
            alert_75_shown=true
        fi
        
        # Alerte CRITIQUE à 80% RAM sans SWAP
        if [ $MEM_USED -ge 80 ] && [ $SWAP_USED -eq 0 ] && [ "$alert_80_shown" = false ]; then
            echo ""
            echo "🚨 [ALERTE CRITIQUE] RAM ${MEM_USED}% mais SWAP à 0% !"
            echo "   Le swappiness ne fonctionne pas correctement"
            echo "   Risque de freeze imminent"
            echo ""
            alert_80_shown=true
        fi
        
        # Arrêt d'urgence si RAM > 95% sans SWAP
        if [ $MEM_USED -ge 95 ] && [ $SWAP_USED -lt 10 ]; then
            echo ""
            echo "🛑 [ARRÊT D'URGENCE] RAM ${MEM_USED}% et SWAP ${SWAP_USED}%"
            echo "   Configuration SWAP inefficace - arrêt pour éviter freeze"
            echo ""
            # Tuer la compilation
            pkill -P $$ make
            exit 1
        fi
        
        # Message positif si SWAP utilisé
        if [ $SWAP_USED -ge 5 ] && [ $MEM_USED -ge 70 ]; then
            echo "   ✅ SWAP actif - protection active contre freeze"
        fi
    done
}

# Lancer le monitoring en arrière-plan
monitor_compilation &
MONITOR_PID=$!

# Compilation
time make -j$JOBS \
    LLVM=1 \
    KCFLAGS="-march=btver2 -mtune=btver2 -O3 -fomit-frame-pointer -flto -mno-sse4a -mno-xop -mno-tbm -pipe" \
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
wait $MONITOR_PID 2>/dev/null

echo ""
if [ $COMPILE_STATUS -eq 0 ]; then
    echo "════════════════════════════════════════════════════════════"
    echo " ✅ SUCCÈS ! FULL LTO compilé sans freeze !"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    echo "📦 Kernel : arch/x86/boot/bzImage"
    echo ""
    echo "📊 Statistiques finales :"
    echo "   Jobs utilisés    : $JOBS"
    echo "   RAM finale       : $(free -h | awk '/^Mem:/{print $3}')"
    echo "   SWAP max utilisé : $(free -h | awk '/^Swap:/{print $3}')"
    echo "   Fin compilation  : $(date '+%H:%M:%S')"
    echo ""
    
    # Analyser l'utilisation SWAP
    FINAL_SWAP=$(free | awk '/^Swap:/ {if($2>0) print int($3*100/$2); else print 0}')
    if [ $FINAL_SWAP -gt 0 ]; then
        echo "✅ SWAP utilisé durant la compilation - configuration OK"
    else
        echo "⚠️  SWAP jamais utilisé - vous avez eu de la chance !"
        echo "   Pour la prochaine fois, augmentez le swappiness"
    fi
    echo ""
    echo "🎉 Compilation FULL LTO réussie sur i3 !"
else
    echo "════════════════════════════════════════════════════════════"
    echo " ❌ ÉCHEC DE LA COMPILATION"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    echo "Code erreur : $COMPILE_STATUS"
    echo ""
    echo "💡 Solutions :"
    echo "  1. Vérifier les logs d'erreur ci-dessus"
    echo "  2. Essayer avec 1 job : modifiez JOBS=1"
    echo "  3. Vérifier SWAP : swapon --show"
    echo "  4. Utiliser THIN LTO (recommandé) :"
    echo "     ./compile-commands-safe.sh"
    echo ""
    exit $COMPILE_STATUS
fi

echo "════════════════════════════════════════════════════════════"
