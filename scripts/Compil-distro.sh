#

cd ..
echo "Vous êtes dans le répertoire : $PWD" 
ls
red=’\033[31m’
reset=’\033[0m’
echo -e "\033[1;31mAvez vous edité la commande, pour créer votre custom Trixie ?"
echo "Le plus simple est d'utiliser worker, les commandes sont configurées."
echo "bouton EDIT tar.xz Distro"
echo "Nous allons utiliser cette commande de base :"
echo "sudo tar -cvf ps4trixie-full.tar.xz --exclude=/ps4trixie-full.tar.xz --exclude=/media/ps4linux --exclude=/var/cache --one-file-system / -I "xz -9""
echo "vous retrouverez votre distro custom a la racine /"
sudo tar -cvf ps4trixie-full.tar.xz --exclude=/ps4trixie-full.tar.xz --exclude=/media/ps4linux --exclude=/var/cache --one-file-system / -I "xz -9"
