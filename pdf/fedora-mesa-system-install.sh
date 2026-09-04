#!/bin/bash

# Script d'installation système de Mesa et libdrm pour Fedora 42
# ATTENTION: Ce script va remplacer les bibliothèques Mesa système!
# Usage: sudo ./install_mesa_system.sh

set -e

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
echo_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
echo_error() { echo -e "${RED}[ERROR]${NC} $1"; }
echo_question() { echo -e "${BLUE}[QUESTION]${NC} $1"; }

# Variables
PROJECTS_DIR="$HOME/Projects"
BUILD_32BIT=true
BACKUP_DIR="/var/backups/mesa-backup-$(date +%Y%m%d-%H%M%S)"

# Vérifier si on est root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo_error "Ce script doit être exécuté avec sudo!"
        echo "Usage: sudo $0"
        exit 1
    fi
}

# Récupérer le vrai utilisateur (celui qui a fait sudo)
get_real_user() {
    if [ -n "$SUDO_USER" ]; then
        REAL_USER="$SUDO_USER"
        REAL_HOME=$(eval echo ~$SUDO_USER)
    else
        REAL_USER="$USER"
        REAL_HOME="$HOME"
    fi
    PROJECTS_DIR="$REAL_HOME/Projects"
    echo_info "Utilisateur détecté: $REAL_USER (home: $REAL_HOME)"
}

# Afficher un avertissement
show_warning() {
    echo ""
    echo_warn "╔═══════════════════════════════════════════════════════════╗"
    echo_warn "║                    ⚠️  AVERTISSEMENT  ⚠️                   ║"
    echo_warn "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    echo "Ce script va:"
    echo "  • REMPLACER les bibliothèques Mesa système"
    echo "  • Installer une version de développement de Mesa"
    echo "  • Potentiellement rendre votre système instable"
    echo ""
    echo "Avant de continuer:"
    echo "  ✓ Créez un point de restauration système"
    echo "  ✓ Assurez-vous d'avoir accès à un TTY (Ctrl+Alt+F3)"
    echo "  ✓ Sauvegardez vos données importantes"
    echo ""
    echo "Les anciennes bibliothèques seront sauvegardées dans:"
    echo "  $BACKUP_DIR"
    echo ""
}

# Demander confirmation
ask_confirmation() {
    echo_question "Voulez-vous vraiment continuer? (tapez 'OUI' en majuscules): "
    read -r confirmation
    
    if [ "$confirmation" != "OUI" ]; then
        echo_info "Installation annulée."
        exit 0
    fi
}

# Vérifier que les sources sont disponibles
check_sources() {
    echo_info "Vérification des sources compilées..."
    
    if [ ! -d "$PROJECTS_DIR/mesa" ]; then
        echo_error "Le répertoire Mesa n'existe pas: $PROJECTS_DIR/mesa"
        echo "Veuillez d'abord compiler Mesa avec le script de build."
        exit 1
    fi
    
    if [ ! -d "$PROJECTS_DIR/drm" ]; then
        echo_error "Le répertoire libdrm n'existe pas: $PROJECTS_DIR/drm"
        echo "Veuillez d'abord compiler libdrm avec le script de build."
        exit 1
    fi
    
    if [ ! -d "$PROJECTS_DIR/mesa/build64" ]; then
        echo_error "Mesa n'a pas été compilé. Répertoire build64 manquant."
        exit 1
    fi
    
    if [ ! -d "$PROJECTS_DIR/drm/build64" ]; then
        echo_error "libdrm n'a pas été compilé. Répertoire build64 manquant."
        exit 1
    fi
    
    echo_info "Sources trouvées et prêtes à l'installation."
}

# Créer une sauvegarde des bibliothèques système
backup_system_libs() {
    echo_info "Création d'une sauvegarde des bibliothèques système..."
    
    mkdir -p "$BACKUP_DIR"
    
    # Sauvegarder les bibliothèques Mesa
    if [ -d /usr/lib64/dri ]; then
        echo_info "Sauvegarde de /usr/lib64/dri..."
        cp -a /usr/lib64/dri "$BACKUP_DIR/dri-lib64"
    fi
    
    if [ -d /usr/lib/dri ]; then
        echo_info "Sauvegarde de /usr/lib/dri..."
        cp -a /usr/lib/dri "$BACKUP_DIR/dri-lib"
    fi
    
    # Sauvegarder les ICD Vulkan
    if [ -d /usr/share/vulkan/icd.d ]; then
        echo_info "Sauvegarde de /usr/share/vulkan/icd.d..."
        cp -a /usr/share/vulkan/icd.d "$BACKUP_DIR/vulkan-icd"
    fi
    
    # Sauvegarder libdrm
    echo_info "Sauvegarde des bibliothèques libdrm..."
    find /usr/lib64 -name "libdrm*.so*" -exec cp -a {} "$BACKUP_DIR/" \; 2>/dev/null || true
    if $BUILD_32BIT; then
        find /usr/lib -name "libdrm*.so*" -exec cp -a {} "$BACKUP_DIR/" \; 2>/dev/null || true
    fi
    
    # Créer un script de restauration
    cat > "$BACKUP_DIR/restore.sh" << 'EOF'
#!/bin/bash
set -e
echo "Restauration des bibliothèques Mesa système..."

BACKUP_DIR="$(dirname "$0")"

if [ -d "$BACKUP_DIR/dri-lib64" ]; then
    echo "Restauration de /usr/lib64/dri..."
    rm -rf /usr/lib64/dri
    cp -a "$BACKUP_DIR/dri-lib64" /usr/lib64/dri
fi

if [ -d "$BACKUP_DIR/dri-lib" ]; then
    echo "Restauration de /usr/lib/dri..."
    rm -rf /usr/lib/dri
    cp -a "$BACKUP_DIR/dri-lib" /usr/lib/dri
fi

if [ -d "$BACKUP_DIR/vulkan-icd" ]; then
    echo "Restauration de /usr/share/vulkan/icd.d..."
    rm -rf /usr/share/vulkan/icd.d
    cp -a "$BACKUP_DIR/vulkan-icd" /usr/share/vulkan/icd.d
fi

echo "Restauration des bibliothèques libdrm..."
cp -a "$BACKUP_DIR"/libdrm*.so* /usr/lib64/ 2>/dev/null || true
cp -a "$BACKUP_DIR"/libdrm*.so* /usr/lib/ 2>/dev/null || true

ldconfig

echo "Restauration terminée!"
echo "Redémarrez votre système ou relancez votre session."
EOF
    
    chmod +x "$BACKUP_DIR/restore.sh"
    
    echo_info "Sauvegarde créée dans: $BACKUP_DIR"
    echo_info "Pour restaurer, exécutez: sudo $BACKUP_DIR/restore.sh"
}

# Installer libdrm sur le système
install_libdrm_system() {
    echo_info "=== Installation système de libdrm ==="
    
    cd "$PROJECTS_DIR/drm"
    
    # Reconfigurer pour installation système 64-bit
    echo_info "Configuration libdrm 64-bit pour /usr..."
    meson configure build64 --prefix=/usr --libdir=/usr/lib64
    ninja -C build64 install
    
    if $BUILD_32BIT && [ -d build32 ]; then
        echo_info "Configuration libdrm 32-bit pour /usr..."
        meson configure build32 --prefix=/usr --libdir=/usr/lib
        ninja -C build32 install
    fi
    
    ldconfig
    echo_info "libdrm installé sur le système!"
}

# Installer Mesa sur le système
install_mesa_system() {
    echo_info "=== Installation système de Mesa ==="
    
    cd "$PROJECTS_DIR/mesa"
    
    # Reconfigurer pour installation système 64-bit
    echo_info "Configuration Mesa 64-bit pour /usr..."
    meson configure build64 --prefix=/usr --libdir=/usr/lib64
    ninja -C build64 install
    
    if $BUILD_32BIT && [ -d build32 ]; then
        echo_info "Configuration Mesa 32-bit pour /usr..."
        meson configure build32 --prefix=/usr --libdir=/usr/lib
        ninja -C build32 install
    fi
    
    ldconfig
    echo_info "Mesa installé sur le système!"
}

# Vérifier l'installation
verify_installation() {
    echo_info "=== Vérification de l'installation ==="
    
    echo ""
    echo "Version OpenGL:"
    glxinfo | grep "OpenGL version" || echo_warn "glxinfo non disponible"
    
    echo ""
    echo "Drivers Mesa disponibles:"
    ls -la /usr/lib64/dri/*.so 2>/dev/null || echo_warn "Aucun driver trouvé"
    
    echo ""
    echo "ICD Vulkan:"
    ls -la /usr/share/vulkan/icd.d/*.json 2>/dev/null || echo_warn "Aucun ICD trouvé"
}

# Instructions post-installation
print_post_install() {
    echo ""
    echo_info "╔═══════════════════════════════════════════════════════════╗"
    echo_info "║           Installation système terminée!                  ║"
    echo_info "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    echo "Prochaines étapes:"
    echo ""
    echo "1. REDÉMARREZ votre système ou au minimum votre session:"
    echo "   sudo systemctl reboot"
    echo ""
    echo "2. Pour vérifier que tout fonctionne après redémarrage:"
    echo "   glxinfo | grep Mesa"
    echo "   vulkaninfo | grep driverName"
    echo ""
    echo "3. En cas de problème (écran noir, etc.):"
    echo "   • Accédez au TTY: Ctrl+Alt+F3"
    echo "   • Connectez-vous"
    echo "   • Restaurez: sudo $BACKUP_DIR/restore.sh"
    echo "   • Redémarrez: sudo systemctl reboot"
    echo ""
    echo "4. Pour revenir aux packages Fedora officiels:"
    echo "   sudo dnf reinstall mesa-* libdrm"
    echo ""
    echo_warn "Note: Cette version de Mesa ne sera PAS mise à jour par DNF!"
    echo_warn "Pour les mises à jour, recompilez et réinstallez manuellement."
    echo ""
}

# Créer un script de mise à jour
create_update_script() {
    cat > "/usr/local/bin/update-custom-mesa" << EOF
#!/bin/bash
# Script de mise à jour de Mesa personnalisé

set -e

echo "Mise à jour de Mesa et libdrm personnalisés..."

cd "$PROJECTS_DIR/drm"
git pull
meson configure build64 --prefix=/usr --libdir=/usr/lib64
ninja -C build64 install
if [ -d build32 ]; then
    meson configure build32 --prefix=/usr --libdir=/usr/lib
    ninja -C build32 install
fi

cd "$PROJECTS_DIR/mesa"
git pull
meson configure build64 --prefix=/usr --libdir=/usr/lib64
ninja -C build64 install
if [ -d build32 ]; then
    meson configure build32 --prefix=/usr --libdir=/usr/lib
    ninja -C build32 install
fi

ldconfig

echo "Mise à jour terminée! Redémarrez votre session."
EOF
    
    chmod +x /usr/local/bin/update-custom-mesa
    echo_info "Script de mise à jour créé: /usr/local/bin/update-custom-mesa"
}

# Fonction principale
main() {
    check_root
    get_real_user
    
    show_warning
    ask_confirmation
    
    check_sources
    backup_system_libs
    
    echo ""
    echo_info "Début de l'installation système..."
    echo ""
    
    install_libdrm_system
    install_mesa_system
    create_update_script
    
    verify_installation
    print_post_install
}

# Exécution
main
