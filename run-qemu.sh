#!/bin/sh
# =============================================================================
# run-qemu.sh — lance Kiddux dans QEMU avec le son activé.
#
# QEMU n'émule aucune carte son par défaut : on ajoute ici une carte Intel HDA
# (reconnue nativement par Linux) reliée au serveur audio de l'hôte (PipeWire,
# ou PulseAudio en repli — fourni par pipewire-pulse).
#
# Usage :
#   ./run-qemu.sh                  # démarre le live (son activé), amorçage BIOS
#   ./run-qemu.sh --uefi           # amorçage UEFI (firmware OVMF) : affiche le
#                                  #   thème GRUB « kids » ; sinon c'est le menu
#                                  #   BIOS (isolinux) qui est utilisé
#   ./run-qemu.sh autre.iso        # sur une autre image
#   ./run-qemu.sh --install        # live + disque de 20 Go pour tester l'install
#   ./run-qemu.sh --installed      # démarre le système installé sur ce disque
#
# En UEFI, l'installateur enregistre l'entrée de démarrage dans la NVRAM du
# firmware (fichier kids-test-ovmf-vars.fd). Elle est donc conservée d'un lancement
# à l'autre pour --install / --installed, et réinitialisée à chaque nouvelle
# --install. Sans elle, OVMF ne sait pas amorcer le disque et GRUB tombe sur son
# invite de commande (grub>).
#
# Dépannage (QEMU qui plante ou ne démarre pas) :
#   --display=TYPE   choisit l'affichage : gtk,gl=off, spice-app, vnc=:0, none…
#                    (voir `qemu-system-x86_64 -display help` ; SDL n'est pas
#                    toujours compilé). Si GTK plante : GDK_BACKEND=x11 ou
#                    GTK_THEME=Adwaita devant la commande, ou --display=vnc=:0
#   --no-audio       désactive la carte son
#   --no-kvm         émulation pure (lent) si /dev/kvm est indisponible
#
# Les options se combinent (ex. « ./run-qemu.sh --uefi --install »).
# =============================================================================
set -e

ISO="kiddux-amd64.hybrid.iso"
DISK="kids-test.qcow2"
INSTALL=0
INSTALLED=0
UEFI=0
DISPLAY_OPT=""
NO_AUDIO=0
NO_KVM=0
for arg in "$@"; do
    case "$arg" in
        --display=*) DISPLAY_OPT="${arg#--display=}" ;;
        --no-audio)  NO_AUDIO=1 ;;
        --no-kvm)    NO_KVM=1 ;;
        --install)   INSTALL=1 ;;
        --installed) INSTALLED=1 ;;
        --uefi)      UEFI=1 ;;
        *.iso)       ISO="$arg" ;;
        -*)          echo "Option inconnue : $arg (voir l'en-tête de $0)" >&2; exit 1 ;;
    esac
done

# Options communes : mémoire, cœurs (KVM si disponible).
set -- -m 2048 -smp 2
if [ "$NO_KVM" -eq 0 ]; then
    if [ -w /dev/kvm ]; then
        set -- "$@" -enable-kvm
    else
        echo "Avertissement : /dev/kvm inaccessible, émulation lente (TCG)." >&2
    fi
fi

# Carte son Intel HDA. Backend : pipewire si disponible, sinon pulseaudio.
# Attention : sur openSUSE, ces backends sont des modules séparés ; s'ils sont
# absents, QEMU plante (segfault) au lieu d'afficher une erreur. On vérifie donc
# la liste réellement disponible avant de les demander.
if [ "$NO_AUDIO" -eq 0 ]; then
    AUDIO=""
    DRIVERS="$(qemu-system-x86_64 -audiodev help 2>/dev/null)"
    for d in pipewire pa; do
        if printf '%s\n' "$DRIVERS" | grep -qx "$d"; then AUDIO="$d"; break; fi
    done
    if [ -n "$AUDIO" ]; then
        set -- "$@" -audiodev "${AUDIO},id=snd0" \
               -device ich9-intel-hda -device hda-duplex,audiodev=snd0
    else
        echo "Avertissement : aucun backend audio (pipewire/pa) dans QEMU, pas de son." >&2
        echo "  openSUSE : sudo zypper install qemu-audio-pipewire   (ou qemu-audio-pa)" >&2
    fi
fi

[ -n "$DISPLAY_OPT" ] && set -- "$@" -display "$DISPLAY_OPT"

# --uefi : amorçage par firmware UEFI (OVMF). C'est le seul mode où l'on voit le
# thème GRUB « kids » (l'ISO amorce GRUB en UEFI, isolinux en BIOS). On copie les
# variables NVRAM dans un fichier inscriptible (l'original est en lecture seule),
# puis on branche code + vars en pflash sur une machine q35.
if [ "$UEFI" -eq 1 ]; then
    OVMF_CODE=""
    OVMF_VARS=""
    # Chemins Debian/Ubuntu, Fedora (edk2), puis openSUSE (qemu-ovmf-x86_64).
    for c in /usr/share/OVMF/OVMF_CODE_4M.fd /usr/share/OVMF/OVMF_CODE.fd \
             /usr/share/ovmf/OVMF_CODE.fd /usr/share/edk2/x64/OVMF_CODE.4m.fd \
             /usr/share/edk2/ovmf/OVMF_CODE.fd \
             /usr/share/qemu/ovmf-x86_64-4m-code.bin \
             /usr/share/qemu/ovmf-x86_64-code.bin; do
        [ -f "$c" ] && { OVMF_CODE="$c"; break; }
    done
    for v in /usr/share/OVMF/OVMF_VARS_4M.fd /usr/share/OVMF/OVMF_VARS.fd \
             /usr/share/ovmf/OVMF_VARS.fd /usr/share/edk2/x64/OVMF_VARS.4m.fd \
             /usr/share/edk2/ovmf/OVMF_VARS.fd \
             /usr/share/qemu/ovmf-x86_64-4m-vars.bin \
             /usr/share/qemu/ovmf-x86_64-vars.bin; do
        [ -f "$v" ] && { OVMF_VARS="$v"; break; }
    done
    if [ -z "$OVMF_CODE" ] || [ -z "$OVMF_VARS" ]; then
        echo "Firmware UEFI (OVMF) introuvable." >&2
        echo "  Debian/Ubuntu : sudo apt install ovmf" >&2
        echo "  openSUSE      : sudo zypper install qemu-ovmf-x86_64" >&2
        echo "  Fedora        : sudo dnf install edk2-ovmf" >&2
        exit 1
    fi
    if [ "$INSTALL" -eq 1 ] || [ "$INSTALLED" -eq 1 ]; then
        # NVRAM liée au disque de test : conservée pour que --installed retrouve
        # l'entrée de démarrage créée par Calamares ; neuve pour chaque --install.
        VARS_RW="kids-test-ovmf-vars.fd"
        if [ "$INSTALL" -eq 1 ] || [ ! -f "$VARS_RW" ]; then
            [ "$INSTALLED" -eq 1 ] && [ "$INSTALL" -eq 0 ] && \
                echo "Avertissement : pas de NVRAM UEFI conservée ($VARS_RW) ; le disque risque de ne pas démarrer (grub>). Refaire une installation avec --uefi --install." >&2
            cp -f "$OVMF_VARS" "$VARS_RW"
        fi
    else
        # Live seul : NVRAM jetable, réinitialisée à chaque lancement.
        VARS_RW="kids-ovmf-vars.fd"
        cp -f "$OVMF_VARS" "$VARS_RW"
    fi
    set -- "$@" -machine q35 \
           -drive if=pflash,format=raw,unit=0,readonly=on,file="$OVMF_CODE" \
           -drive if=pflash,format=raw,unit=1,file="$VARS_RW"
fi

if [ "$INSTALLED" -eq 1 ] && [ "$INSTALL" -eq 0 ]; then
    # Démarrer le système déjà installé : disque uniquement, sans CD.
    [ -f "$DISK" ] || { echo "Disque introuvable : $DISK (lance d'abord ./run-qemu.sh --install)" >&2; exit 1; }
    set -- "$@" -drive file="$DISK",format=qcow2 -boot c
else
    # Démarrer le live depuis l'ISO.
    [ -f "$ISO" ] || { echo "ISO introuvable : $ISO" >&2; exit 1; }
    set -- "$@" -cdrom "$ISO" -boot d
    if [ "$INSTALL" -eq 1 ]; then
        # Disque cible pour tester l'installation (créé une seule fois).
        [ -f "$DISK" ] || qemu-img create -f qcow2 "$DISK" 20G
        set -- "$@" -drive file="$DISK",format=qcow2
    fi
fi

exec qemu-system-x86_64 "$@"
