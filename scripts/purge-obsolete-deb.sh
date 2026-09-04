#!/bin/bash
echo "Supprimer les paquets obsoletes" 
apt list '?obsolete'
sudo apt purge '?obsolete'
