#!/bin/bash

# Script de compilation de libdrm et Mesa pour Fedora 42
# Supporte les builds 32-bit et 64-bit
# Usage: ./build_mesa.sh [--64bit-only]

set -e

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
echo_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
echo_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Variables de configuration
INSTALL_PREFIX="$HOME/mesa"
PROJECTS_DIR="$HOME/Projects"
BUILD_32BIT=true

# Parser les arguments
if [[ "$1" == "--64bit-only" ]]; then
    BUILD_32BIT=false
    echo_info "Mode 64-bit uniquement activé"
fi

# Fonction pour vérifier si on est root
check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        echo_error "Ne pas exécuter ce script en tant que root!"
        exit 1
    fi
}

# Installation des dépendances
install_dependencies() {
    echo_info "Installation des dépendances de build pour Mesa..."
    
    # Dépendances de base pour Mesa
    sudo dnf builddep -y mesa
    
    # Dépendances pour libdrm
    sudo dnf builddep -y libdrm
    
    # Outils de build essentiels
    sudo dnf install -y \
        git \
        meson \
        ninja-build \
        cmake \
        gcc \
        gcc-c++ \
        python3-mako \
        bison \
        flex
    
    if $BUILD_32BIT; then
        echo_info "Installation des dépendances 32-bit..."
        
        # pkg-config 32-bit
        sudo dnf install -y pkgconf-pkg-config.i686
        
        # Bibliothèques de développement 32-bit
        sudo dnf install -y \
            glibc-devel.i686 \
            libdrm-devel.i686 \
            elfutils-libelf-devel.i686 \
            wayland-devel.i686 \
            libffi-devel.i686 \
            libxcb-devel.i686 \
            libXau-devel.i686 \
            libX11-devel.i686 \
            libXext-devel.i686 \
            libXfixes-devel.i686 \
            libxshmfence-devel.i686 \
            libXxf86vm-devel.i686 \
            libXrandr-devel.i686 \
            libXrender-devel.i686 \
            libclc-devel.i686 \
            expat-devel.i686 \
            zlib-devel.i686
        
        # LLVM 32-bit (peut entrer en conflit avec la version 64-bit)
        echo_warn "Installation de llvm-devel.i686..."
        echo_warn "Cela peut nécessiter de désinstaller temporairement llvm-devel.x86_64"
        sudo dnf install -y llvm-devel.i686 || echo_warn "Échec de l'installation de llvm-devel.i686"
    fi
    
    echo_info "Toutes les dépendances sont installées!"
}

# Créer les répertoires nécessaires
setup_directories() {
    echo_info "Création des répertoires..."
    mkdir -p "$PROJECTS_DIR"
    mkdir -p "$INSTALL_PREFIX"
    
    if $BUILD_32BIT; then
        mkdir -p ~/.local/share/meson/cross
    fi
}

# Créer le fichier de cross-compilation pour 32-bit
create_cross_file() {
    if ! $BUILD_32BIT; then
        return
    fi
    
    echo_info "Création du fichier de cross-compilation 32-bit..."
    
    cat > ~/.local/share/meson/cross/gcc-i686 << 'EOF'
[binaries]
c='gcc'
cpp='g++'
ar='ar'
strip='strip'
pkg-config='i686-redhat-linux-gnu-pkg-config'
llvm-config='/usr/bin/llvm-config-32'

[built-in options]
c_args=['-m32', '-march=native']
c_link_args=['-m32']
cpp_args=['-m32', '-march=native']
cpp_link_args=['-m32']

[host_machine]
system='linux'
cpu_family='x86'
cpu='x86'
endian='little'
EOF
    
    echo_info "Fichier de cross-compilation créé: ~/.local/share/meson/cross/gcc-i686"
}

# Compiler libdrm
build_libdrm() {
    echo_info "=== Compilation de libdrm ==="
    
    cd "$PROJECTS_DIR"
    
    if [ ! -d "drm" ]; then
        echo_info "Clonage du dépôt libdrm..."
        git clone https://gitlab.freedesktop.org/mesa/drm.git
    else
        echo_info "Mise à jour du dépôt libdrm..."
        cd drm
        git pull
        cd ..
    fi
    
    cd drm
    
    # Build 64-bit
    echo_info "Compilation libdrm 64-bit..."
    meson setup build64 \
        --prefix="$INSTALL_PREFIX" \
        --libdir=lib64 \
        -Dbuildtype=release
    
    ninja -C build64
    ninja -C build64 install
    
    # Build 32-bit
    if $BUILD_32BIT; then
        echo_info "Compilation libdrm 32-bit..."
        meson setup build32 \
            --cross-file gcc-i686 \
            --prefix="$INSTALL_PREFIX" \
            --libdir=lib \
            -Dbuildtype=release
        
        ninja -C build32
        ninja -C build32 install
    fi
    
    echo_info "libdrm compilé avec succès!"
}

# Compiler Mesa
build_mesa() {
    echo_info "=== Compilation de Mesa ==="
    
    cd "$PROJECTS_DIR"
    
    if [ ! -d "mesa" ]; then
        echo_info "Clonage du dépôt Mesa..."
        git clone https://gitlab.freedesktop.org/mesa/mesa.git
    else
        echo_info "Mise à jour du dépôt Mesa..."
        cd mesa
        git pull
        cd ..
    fi
    
    cd mesa
    
    # Build 64-bit avec drivers Intel et AMD
    echo_info "Compilation Mesa 64-bit..."
    meson setup build64 \
        --prefix="$INSTALL_PREFIX" \
        --libdir=lib64 \
        -Dgallium-drivers=radeonsi,llvmpipe,softpipe,iris,zink \
        -Dvulkan-drivers=intel,amd \
        -Dvideo-codecs=h264dec,h264enc,h265dec,h265enc,vc1dec \
        -Dbuildtype=release
    
    ninja -C build64
    ninja -C build64 install
    
    # Build 32-bit
    if $BUILD_32BIT; then
        echo_info "Compilation Mesa 32-bit..."
        meson setup build32 \
            --cross-file gcc-i686 \
            --prefix="$INSTALL_PREFIX" \
            --libdir=lib \
            -Dgallium-drivers=radeonsi,llvmpipe,softpipe,iris,zink \
            -Dvulkan-drivers=intel,amd \
            -Dvideo-codecs=h264dec,h264enc,h265dec,h265enc,vc1dec \
            -Dbuildtype=release
        
        ninja -C build32
        ninja -C build32 install
    fi
    
    echo_info "Mesa compilé avec succès!"
}

# Créer le script de lancement
create_run_script() {
    echo_info "Création du script mesa-run.sh..."
    
    cat > "$HOME/mesa-run.sh" << 'EOF'
#!/bin/sh

MESA=$HOME/mesa
LD_LIBRARY_PATH=$MESA/lib64:$MESA/lib:$LD_LIBRARY_PATH \
LIBGL_DRIVERS_PATH=$MESA/lib64/dri:$MESA/lib/dri \
VK_ICD_FILENAMES=$MESA/share/vulkan/icd.d/radeon_icd.x86_64.json:$MESA/share/vulkan/icd.d/radeon_icd.x86.json:$MESA/share/vulkan/icd.d/intel_icd.x86_64.json:$MESA/share/vulkan/icd.d/intel_icd.x86.json \
LIBVA_DRIVERS_PATH=$MESA/lib64/dri:$MESA/lib/dri \
VDPAU_DRIVER_PATH=$MESA/lib64/vdpau \
OCL_ICD_VENDORS=$MESA/etc/OpenCL/vendors/rusticl.icd \
    exec "$@"
EOF
    
    chmod +x "$HOME/mesa-run.sh"
    
    echo_info "Script créé: ~/mesa-run.sh"
}

# Créer le script source
create_source_script() {
    echo_info "Création du script mesa.sh pour sourcing..."
    
    cat > "$HOME/mesa.sh" << 'EOF'
#!/bin/sh

MESA=$HOME/mesa

export LD_LIBRARY_PATH=$MESA/lib64:$MESA/lib:$LD_LIBRARY_PATH
export LIBGL_DRIVERS_PATH=$MESA/lib64/dri:$MESA/lib/dri
export VK_ICD_FILENAMES=$MESA/share/vulkan/icd.d/radeon_icd.x86_64.json:$MESA/share/vulkan/icd.d/radeon_icd.x86.json:$MESA/share/vulkan/icd.d/intel_icd.x86_64.json:$MESA/share/vulkan/icd.d/intel_icd.x86.json
export LIBVA_DRIVERS_PATH=$MESA/lib64/dri:$MESA/lib/dri
export VDPAU_DRIVER_PATH=$MESA/lib64/vdpau
export OCL_ICD_VENDORS=$MESA/etc/OpenCL/vendors/rusticl.icd

echo "Mesa custom environment loaded from $MESA"
EOF
    
    chmod +x "$HOME/mesa.sh"
    
    echo_info "Script créé: ~/mesa.sh"
}

# Afficher les instructions finales
print_usage() {
    echo ""
    echo_info "========================================"
    echo_info "Compilation terminée avec succès!"
    echo_info "========================================"
    echo ""
    echo "Mesa et libdrm ont été installés dans: $INSTALL_PREFIX"
    echo ""
    echo "Pour utiliser votre build Mesa personnalisé:"
    echo ""
    echo "1. Avec le script de lancement (recommandé pour tester un jeu):"
    echo "   ~/mesa-run.sh vkcube"
    echo "   ~/mesa-run.sh glxgears"
    echo ""
    echo "2. Pour Steam, dans les options de lancement du jeu:"
    echo "   ~/mesa-run.sh %command%"
    echo ""
    echo "3. Avec source (pour tous les programmes lancés depuis un terminal):"
    echo "   source ~/mesa.sh"
    echo "   vkcube"
    echo ""
    echo "Pour vérifier la version:"
    echo "   ~/mesa-run.sh vulkaninfo | grep -i driver"
    echo "   ~/mesa-run.sh glxinfo | grep -i version"
    echo ""
}

# Fonction principale
main() {
    echo_info "Script de compilation Mesa + libdrm pour Fedora 42"
    echo_info "=================================================="
    
    check_not_root
    install_dependencies
    setup_directories
    create_cross_file
    build_libdrm
    build_mesa
    create_run_script
    create_source_script
    print_usage
}

# Exécution
main
