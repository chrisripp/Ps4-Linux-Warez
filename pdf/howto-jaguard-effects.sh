#!/bin/bash
# show_effect.sh

FICHIER="$1"

if [ -z "$FICHIER" ]; then
    echo "Usage: $0 <fichier.txt>"
    exit 1
fi

if [ ! -f "$FICHIER" ]; then
    echo "Erreur: $FICHIER n'existe pas"
    exit 1
fi

# Appeler Python avec le contenu du fichier
cat "$FICHIER" | python3 << 'EOF'
import sys
from terminaltexteffects.effects.effect_matrix import Matrix

text = sys.stdin.read()
effect = Matrix(text)

with effect.terminal_output() as terminal:
    for frame in effect:
        terminal.print(frame)
EOF
