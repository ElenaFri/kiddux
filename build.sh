#!/bin/sh
# -----------------------------------------------------------------------------
# Construit l'image ISO debian-minimal-kids.
#
# « lb build » télécharge les paquets Debian et assemble le système ;
# cela nécessite les droits root et une connexion internet.
# Le journal complet est enregistré dans build.log (ignoré par Git).
#
# live-build est un outil Debian : sur un hôte non-Debian (openSUSE, Fedora...),
# construire dans un conteneur/VM Debian trixie (voir README, « Construire »).
# On n'emploie « sudo » que si l'on n'est pas déjà root (cas du conteneur).
# -----------------------------------------------------------------------------
set -e

if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi

$SUDO lb build 2>&1 | tee build.log
