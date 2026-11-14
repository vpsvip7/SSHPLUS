#!/bin/bash
# Instala y activa BadVPN (udpgw) en el puerto 7300 sin hacer ninguna pregunta.
# Se puede ejecutar varias veces: si ya está activo en ese puerto, no lo toca.

PUERTO=7300
BIN=/bin/badvpn-udpgw
AUTOSTART=/etc/autostart
URL="https://www.dropbox.com/s/48b36clnxkkurlz/badvpn-udpgw"
ARGS="--listen-addr 127.0.0.1:$PUERTO --max-clients 10000 --max-connections-for-client 8"

G="\033[1;32m"; R="\033[1;31m"; Y="\033[1;33m"; N="\033[0m"

[[ $EUID -ne 0 ]] && { echo -e "${R}Ejecute este script como root.${N}"; exit 1; }

es_binario() { [[ -s $1 && $(head -c 4 "$1" | tail -c 3) == ELF ]]; }

echo -e "${Y}INSTALANDO BADVPN EN EL PUERTO $PUERTO...${N}"

# 1) screen (hace falta para dejarlo corriendo en segundo plano)
if ! command -v screen >/dev/null 2>&1; then
    apt-get install -y screen >/dev/null 2>&1 || { apt-get update >/dev/null 2>&1; apt-get install -y screen >/dev/null 2>&1; }
    command -v screen >/dev/null 2>&1 || { echo -e "${R}No se pudo instalar screen.${N}"; exit 1; }
fi

# 2) binario de badvpn-udpgw
if ! es_binario "$BIN"; then
    tmp=$(mktemp)
    for u in "$URL" "$URL?dl=1"; do
        wget -q -O "$tmp" "$u" && es_binario "$tmp" && break
    done
    if ! es_binario "$tmp"; then
        rm -f "$tmp"
        echo -e "${R}No se pudo descargar badvpn-udpgw (revise internet o el enlace).${N}"
        exit 1
    fi
    mv -f "$tmp" "$BIN"
fi
chmod 755 "$BIN"

# 3) iniciar (si ya escucha en ese puerto, no se toca)
if ss -ltn 2>/dev/null | grep -q "127.0.0.1:$PUERTO "; then
    echo -e "${G}BadVPN ya estaba activo en el puerto $PUERTO.${N}"
else
    screen -dmS udpvpn "$BIN" $ARGS
    sleep 1
    if ! ss -ltn 2>/dev/null | grep -q "127.0.0.1:$PUERTO "; then
        echo -e "${R}BadVPN no quedó escuchando en el puerto $PUERTO.${N}"
        exit 1
    fi
fi

# 4) arranque automático (reemplaza cualquier línea anterior de udpvpn)
touch "$AUTOSTART"
sed -i '/udpvpn/d' "$AUTOSTART"
echo "ps x | grep 'udpvpn' | grep -v 'grep' || screen -dmS udpvpn $BIN $ARGS --client-socket-sndbuf 10000" >> "$AUTOSTART"

echo -e "${G}BADVPN ACTIVADO CON EXITO EN EL PUERTO $PUERTO${N}"
