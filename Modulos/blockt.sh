#!/bin/bash
# blockt.sh - Bloqueo de torrent con iptables (cadena propia TORRENT_BLOCK)
#
# Bloquea:
#   1) Trafico BitTorrent (puertos clasicos, handshake, trackers, DHT)
#   2) Paginas de torrent por dominio (DNS, SNI de HTTPS, Host de HTTP)
#      -> la lista esta en /etc/torrent-block/domains.txt (editable)
#
# Uso:
#   ./blockt.sh              -> menu interactivo
#   ./blockt.sh on           -> aplica el bloqueo + persistente al reiniciar
#   ./blockt.sh off          -> quita el bloqueo + quita la persistencia
#   ./blockt.sh status       -> estado
#   ./blockt.sh list         -> ver dominios bloqueados
#   ./blockt.sh add <dom>    -> agregar dominio o palabra (ej: nyaa.si, rarbg)
#   ./blockt.sh del <dom>    -> quitar dominio o palabra
#   ./blockt.sh apply|remove -> solo reglas (lo usa systemd)
#
# Solo toca su propia cadena: no vacia ni modifica otras reglas del firewall.

CHAIN="TORRENT_BLOCK"
BIN="/usr/local/sbin/torrent-block"
SERVICE_NAME="torrent-block.service"
SERVICE="/etc/systemd/system/$SERVICE_NAME"
CONF_DIR="${TB_CONF_DIR:-/etc/torrent-block}"
DOMAINS_FILE="$CONF_DIR/domains.txt"

# Patrones de contenido (cualquier protocolo)
GENERIC=("BitTorrent protocol" "info_hash" "peer_id=" "announce.php?passkey=" ".torrent")
# Patrones DHT (solo UDP, para evitar falsos positivos)
UDP_DHT=("get_peers" "announce_peer" "find_node")

if [[ $EUID -ne 0 ]]; then
    echo "Ejecuta este script como root."
    exit 1
fi

# ---------- utilidades ----------

ipt_list() {
    local c
    for c in iptables ip6tables; do
        command -v "$c" >/dev/null 2>&1 && echo "$c"
    done
}

ensure_iptables() {
    if ! command -v iptables >/dev/null 2>&1; then
        if command -v apt-get >/dev/null 2>&1; then
            echo "Instalando iptables..."
            apt-get install -y iptables >/dev/null 2>&1
        fi
    fi
    if ! command -v iptables >/dev/null 2>&1; then
        echo "No se pudo encontrar/instalar iptables."
        return 1
    fi
    modprobe xt_string 2>/dev/null
    return 0
}

fw_active() {
    iptables -w -C OUTPUT -j "$CHAIN" >/dev/null 2>&1
}

# ---------- lista de dominios ----------

write_default_domains() {
    mkdir -p "$CONF_DIR"
    cat > "$DOMAINS_FILE" <<'EOF'
# Dominios/palabras de paginas de torrent (uno por linea, minimo 5 caracteres).
# Una palabra sin punto (ej: piratebay) bloquea cualquier dominio que la contenga,
# lo que tambien cubre espejos (piratebay10.xyz, etc).
piratebay
1337x
rarbg
nyaa.si
limetorrents
torrentz2
kickass
yts.mx
torlock
torrentgalaxy
magnetdl
zooqle
bitsearch
torrentdownloads
rutracker
eztv.re
tgx.rs
# Palabra generica: bloquea cualquier dominio que contenga "torrent"
# (borrala si bloquea algo legitimo, ej. sitios de noticias sobre el tema)
torrent
EOF
}

valid_domain() {
    [[ "$1" =~ ^[a-z0-9][a-z0-9.-]{4,}$ ]] && [[ "$1" != *..* ]]
}

load_domains() {
    [[ -f "$DOMAINS_FILE" ]] || write_default_domains
    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        line="${line//[[:space:]]/}"
        line="${line,,}"
        [[ -z "$line" ]] && continue
        valid_domain "$line" && echo "$line"
    done < "$DOMAINS_FILE"
}

# En DNS los puntos se codifican como bytes de longitud: nyaa.si -> |04|nyaa|02|si
dns_pattern() {
    local d="$1" out="" p
    if [[ "$d" != *.* ]]; then
        echo "$d"
        return
    fi
    local IFS=.
    for p in $d; do
        out+=$(printf '|%02x|%s' "${#p}" "$p")
    done
    echo "$out"
}

cmd_list() {
    echo "Dominios bloqueados ($DOMAINS_FILE):"
    load_domains | sed 's/^/  - /'
}

cmd_add() {
    local d="${1,,}"
    if ! valid_domain "$d"; then
        echo "Dominio invalido (minimo 5 caracteres; solo letras, numeros, '.' y '-')."
        return 1
    fi
    [[ -f "$DOMAINS_FILE" ]] || write_default_domains
    if grep -qxF "$d" "$DOMAINS_FILE"; then
        echo "Ya estaba en la lista."
        return 0
    fi
    echo "$d" >> "$DOMAINS_FILE"
    echo "Agregado: $d"
    fw_active && fw_apply
}

cmd_del() {
    local d="${1,,}"
    if ! grep -qxF "$d" "$DOMAINS_FILE" 2>/dev/null; then
        echo "No esta en la lista."
        return 1
    fi
    grep -vxF "$d" "$DOMAINS_FILE" > "$DOMAINS_FILE.tmp" && mv "$DOMAINS_FILE.tmp" "$DOMAINS_FILE"
    echo "Quitado: $d"
    fw_active && fw_apply
}

# ---------- nucleo ----------

fw_apply() {
    ensure_iptables || return 1
    local ipt parent s d dns fail=0
    local -a STR_OPTS=(--algo bm) DOMS

    # Ignorar mayusculas/minusculas si el sistema lo soporta
    iptables -m string --help 2>&1 | grep -q -- '--icase' && STR_OPTS+=(--icase)
    mapfile -t DOMS < <(load_domains)

    for ipt in $(ipt_list); do
        # Crear (o vaciar) solo nuestra cadena
        "$ipt" -w -N "$CHAIN" 2>/dev/null
        "$ipt" -w -F "$CHAIN"

        # Puertos clasicos de BitTorrent
        "$ipt" -w -A "$CHAIN" -p tcp --dport 6881:6889 -j DROP || fail=1
        "$ipt" -w -A "$CHAIN" -p udp --dport 6881:6889 -j DROP || fail=1

        # Firmas de BitTorrent en el contenido del paquete
        for s in "${GENERIC[@]}"; do
            "$ipt" -w -A "$CHAIN" -m string "${STR_OPTS[@]}" --string "$s" -j DROP || fail=1
        done
        for s in "${UDP_DHT[@]}"; do
            "$ipt" -w -A "$CHAIN" -p udp -m string "${STR_OPTS[@]}" --string "$s" -j DROP || fail=1
        done

        # Paginas de torrent por dominio
        for d in "${DOMS[@]}"; do
            dns=$(dns_pattern "$d")
            # Consultas DNS (UDP y TCP 53)
            "$ipt" -w -A "$CHAIN" -p udp --dport 53 -m string "${STR_OPTS[@]}" --hex-string "$dns" -j DROP || fail=1
            "$ipt" -w -A "$CHAIN" -p tcp --dport 53 -m string "${STR_OPTS[@]}" --hex-string "$dns" -j DROP || fail=1
            # HTTP (Host), HTTPS y DNS-over-TLS (SNI del ClientHello)
            "$ipt" -w -A "$CHAIN" -p tcp -m multiport --dports 80,443,853 \
                -m string "${STR_OPTS[@]}" --string "$d" -j DROP || fail=1
        done

        # Enganchar la cadena en OUTPUT (trafico del servidor, ej. tuneles SSH/proxy)
        # y en FORWARD (trafico enrutado, ej. VPN). Sin duplicar el salto.
        for parent in OUTPUT FORWARD; do
            "$ipt" -w -C "$parent" -j "$CHAIN" >/dev/null 2>&1 || \
                "$ipt" -w -I "$parent" 1 -j "$CHAIN" || fail=1
        done
    done

    if [[ $fail -ne 0 ]]; then
        echo "Aviso: alguna regla fallo (revisa que el modulo xt_string este disponible)."
        return 1
    fi
    return 0
}

fw_remove() {
    local ipt parent
    for ipt in $(ipt_list); do
        for parent in OUTPUT FORWARD; do
            while "$ipt" -w -C "$parent" -j "$CHAIN" >/dev/null 2>&1; do
                "$ipt" -w -D "$parent" -j "$CHAIN"
            done
        done
        "$ipt" -w -F "$CHAIN" >/dev/null 2>&1
        "$ipt" -w -X "$CHAIN" >/dev/null 2>&1
    done
    return 0
}

# ---------- persistencia (systemd) ----------

persist_on() {
    if ! command -v systemctl >/dev/null 2>&1; then
        echo "systemd no encontrado: el bloqueo NO sera persistente al reiniciar."
        return 1
    fi

    local src
    src=$(readlink -f "$0" 2>/dev/null)
    if [[ ! -f "$src" ]]; then
        echo "No se pudo ubicar el script para instalarlo; ejecutalo desde un archivo."
        return 1
    fi
    [[ "$src" != "$BIN" ]] && install -m 755 "$src" "$BIN"

    cat > "$SERVICE" <<EOF
[Unit]
Description=Bloqueo de torrent (iptables, cadena $CHAIN)
Wants=network-pre.target
Before=network-pre.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=$BIN apply
ExecStop=$BIN remove

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME" >/dev/null 2>&1
    return 0
}

persist_off() {
    if command -v systemctl >/dev/null 2>&1 && [[ -f "$SERVICE" ]]; then
        systemctl disable "$SERVICE_NAME" >/dev/null 2>&1
        rm -f "$SERVICE"
        systemctl daemon-reload
    fi
    rm -f "$BIN"
}

# ---------- acciones ----------

do_on() {
    if [[ -e /etc/Plus-torrent ]]; then
        echo -e "\033[1;33m[!] Se detecto /etc/Plus-torrent (version vieja del script)."
        echo -e "    Quita primero esas reglas con la opcion de remover de la version vieja.\033[0m"
    fi
    if fw_apply; then
        persist_on && echo "Persistencia al reiniciar: activada."
        echo -e "\033[1;32mBLOQUEO DE TORRENT APLICADO\033[0m"
    else
        echo -e "\033[1;31mNo se pudo aplicar el bloqueo completo.\033[0m"
        return 1
    fi
}

do_off() {
    fw_remove
    persist_off
    echo -e "\033[1;33mTORRENT LIBERADO. Bloqueo y persistencia removidos.\033[0m"
    echo "(La lista de dominios se conserva en $DOMAINS_FILE)"
}

do_status() {
    if fw_active; then
        echo -e "\033[1;32mEstado: ACTIVO\033[0m"
    else
        echo -e "\033[1;31mEstado: INACTIVO\033[0m"
    fi
    if command -v systemctl >/dev/null 2>&1 && systemctl is-enabled "$SERVICE_NAME" >/dev/null 2>&1; then
        echo "Persistencia al reiniciar: si"
    else
        echo "Persistencia al reiniciar: no"
    fi
    echo "Dominios en la lista: $(load_domains | wc -l)"
}

menu_interactivo() {
    local op d
    while true; do
        clear
        echo -e "\E[44;1;37m           FIREWALL BLOQUEO TORRENT           \E[0m"
        echo ""
        do_status
        echo ""
        if fw_active; then
            echo " 1) Remover bloqueo"
        else
            echo " 1) Aplicar bloqueo"
        fi
        echo " 2) Ver dominios bloqueados"
        echo " 3) Agregar dominio"
        echo " 4) Quitar dominio"
        echo " 0) Salir"
        echo ""
        read -r -p "Opcion: " op
        case "$op" in
            1) if fw_active; then do_off; else do_on; fi; sleep 2 ;;
            2) cmd_list; echo ""; read -r -p "Enter para continuar..." _ ;;
            3) read -r -p "Dominio o palabra a bloquear: " d; cmd_add "$d"; sleep 2 ;;
            4) read -r -p "Dominio o palabra a quitar: " d; cmd_del "$d"; sleep 2 ;;
            0) break ;;
        esac
    done
    # Si se ejecuta desde un panel que define "menu", volver a el
    command -v menu >/dev/null 2>&1 && menu
}

case "$1" in
    on)      do_on ;;
    off)     do_off ;;
    status)  do_status ;;
    list)    cmd_list ;;
    add)     cmd_add "$2" ;;
    del)     cmd_del "$2" ;;
    apply)   fw_apply ;;
    remove)  fw_remove ;;
    "")      menu_interactivo ;;
    *)       echo "Uso: $0 [on|off|status|list|add <dom>|del <dom>|apply|remove]"; exit 1 ;;
esac
