#!/bin/sh
# -----------------------------------------------------------------------------
# Nettoie les artefacts de construction (chroot, binary, ISO...).
#
# Par défaut, le cache des paquets téléchargés est conservé pour accélérer
# les reconstructions. Pour tout supprimer, y compris le cache :
#     sudo lb clean --purge
#
# À lancer AVANT un build pour repartir de zéro, PAS entre le build et le test :
# « lb clean » supprime les artefacts binaires, Y COMPRIS l'ISO produite.
# On n'emploie « sudo » que si l'on n'est pas déjà root (cas du conteneur).
# -----------------------------------------------------------------------------
set -e

if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi

$SUDO lb clean
