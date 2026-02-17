#!/bin/bash

# Colores para mejor visualización
red='\033[1;31m'
green='\033[1;32m'
yellow='\033[1;33m'
blue='\033[1;34m'
purple='\033[1;35m'
cyan='\033[1;36m'
white='\033[1;37m'
reset='\033[0m'

fun_bar () {
    comando[0]="$1"
    comando[1]="$2"
    (
        [[ -e $HOME/fim ]] && rm $HOME/fim
        ${comando[0]} > /dev/null 2>&1
        ${comando[1]} > /dev/null 2>&1
        touch $HOME/fim
    ) > /dev/null 2>&1 &
    tput civis
    echo -e "${red}---------------------------------------------------${white}"
    echo -ne "${yellow}    ESPERE..${purple}["
    while true; do
        for((i=0; i<18; i++)); do
            echo -ne "${blue}#"
            sleep 0.1s  # Reducido para ser más rápido
        done
        [[ -e $HOME/fim ]] && rm $HOME/fim && break
        echo -e "${yellow}"
        sleep 1s
        tput cuu1
        tput dl1
        echo -ne "${white}    ESPERE SENTADO..${purple}["
    done
    echo -e "${purple}]${white} -${green} INSTALADO !${white}"
    tput cnorm
    echo -e "${red}---------------------------------------------------${white}"
}

# Función para verificar errores
check_error() {
    if [ $? -eq 0 ]; then
        echo -e "${green}[OK]${white} $1"
    else
        echo -e "${red}[ERROR]${white} $1"
        exit 1
    fi
}

clear && clear
echo -e "${red}———————————————————————————————————————————————————${white}"
echo -e "${green}              WS+ SSL |2025 ${white}"
echo -e "${red}———————————————————————————————————————————————————${white}"
echo -e "${cyan}              SCRIPT AUTOCONFIGURACION ${white}"
echo -e "${red}———————————————————————————————————————————————————${white}"
echo -e "${white}Requisitos: puerto libre ,80 y el 443"
echo

# Verificar sistema operativo
if ! grep -q "Ubuntu" /etc/os-release; then
    echo -e "${red}Este script está diseñado para Ubuntu${white}"
    exit 1
fi

# Obtener versión de Ubuntu
UBUNTU_VERSION=$(lsb_release -rs)
echo -e "${yellow}Detectado Ubuntu $UBUNTU_VERSION${white}"

# Actualizar repositorios primero
echo -e "${yellow}Actualizando repositorios...${white}"
apt-get update -qq > /dev/null 2>&1
check_error "Actualización de repositorios"

echo -e "${yellow}                 INSTALANDO SSL... ${white}"
inst_ssl () {
    # Instalar stunnel4
    apt-get install stunnel4 -y > /dev/null 2>&1
    check_error "Instalación de stunnel4"
    
    # Configurar stunnel
    echo -e "client = no\n[SSL]\ncert = /etc/stunnel/stunnel.pem\naccept = 443\nconnect = 127.0.0.1:80" > /etc/stunnel/stunnel.conf
    
    # Generar certificado SSL
    openssl genrsa -out stunnel.key 2048 > /dev/null 2>&1
    (echo "" ; echo "" ; echo "" ; echo "" ; echo "" ; echo "" ; echo "@cloudflare") | \
    openssl req -new -key stunnel.key -x509 -days 1000 -out stunnel.crt > /dev/null 2>&1
    
    cat stunnel.crt stunnel.key > stunnel.pem
    mv stunnel.pem /etc/stunnel/
    
    # Habilitar y reiniciar stunnel
    sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel4
    systemctl enable stunnel4 > /dev/null 2>&1
    systemctl restart stunnel4 > /dev/null 2>&1
    
    # Limpiar archivos temporales
    rm -f stunnel.crt stunnel.key /root/stunnel.crt /root/stunnel.key 2>/dev/null
}
fun_bar 'inst_ssl'

echo -e "${yellow}                 CONFIGURANDO SSL.. ${white}"
fun_bar 'inst_ssl'  # ¿Esto es necesario ejecutarlo dos veces?

echo -e "${yellow}                 CONFIGURANDO PYTHON3.. ${white}"
inst_py () {
    # Matar procesos en puerto 80
    fuser -k 80/tcp > /dev/null 2>&1
    pkill -f python3 > /dev/null 2>&1
    
    # Instalar dependencias
    apt-get install python3 screen net-tools -y > /dev/null 2>&1
    check_error "Instalación de Python3 y screen"
    
    # Obtener puerto SSH de manera más robusta
    SSH_PORT=$(ss -tlnp | grep sshd | awk '{print $4}' | cut -d':' -f2 | head -n1)
    if [ -z "$SSH_PORT" ]; then
        SSH_PORT="22"  # Puerto por defecto si no se encuentra
    fi
    echo -e "${green}Puerto SSH detectado: $SSH_PORT${white}"
    
    # Crear script Python3 mejorado
    cat > /tmp/proxy.py << 'EOF'
import socket
import threading
import select
import sys
import time
import getopt

# CONFIG
LISTENING_ADDR = '0.0.0.0'
LISTENING_PORT = 1080
PASS = ''

# CONST
BUFLEN = 4096 * 4
TIMEOUT = 60
DEFAULT_HOST = "127.0.0.1:SSH_PORT_22"
RESPONSE = 'HTTP/1.1 101 <b><font color="yellow"> SSL+PY </color></b><font color="gray">internet_premium</font>\r\nConnection: Upgrade\r\nUpgrade: websocket\r\n\r\nHTTP/1.1 200 Connection Established\r\n\r\n'

class Server(threading.Thread):
    def __init__(self, host, port):
        threading.Thread.__init__(self)
        self.running = False
        self.host = host
        self.port = port
        self.threads = []
        self.threadsLock = threading.Lock()
        self.logLock = threading.Lock()
        self.daemon = True

    def run(self):
        self.soc = socket.socket(socket.AF_INET)
        self.soc.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.soc.settimeout(2)
        try:
            self.soc.bind((self.host, self.port))
            self.soc.listen(0)
            self.running = True
        except Exception as e:
            print(f"Error binding to {self.host}:{self.port} - {e}")
            return

        try:
            while self.running:
                try:
                    c, addr = self.soc.accept()
                    c.setblocking(1)
                except socket.timeout:
                    continue
                
                conn = ConnectionHandler(c, self, addr)
                conn.start()
                self.addConn(conn)
        finally:
            self.running = False
            self.soc.close()

    def addConn(self, conn):
        with self.threadsLock:
            if self.running:
                self.threads.append(conn)

    def removeConn(self, conn):
        with self.threadsLock:
            if conn in self.threads:
                self.threads.remove(conn)

    def close(self):
        self.running = False
        with self.threadsLock:
            for c in self.threads:
                c.close()

class ConnectionHandler(threading.Thread):
    def __init__(self, socClient, server, addr):
        threading.Thread.__init__(self)
        self.clientClosed = False
        self.targetClosed = True
        self.client = socClient
        self.client_buffer = ''
        self.server = server
        self.log = f'Connection: {addr[0]}:{addr[1]}'
        self.daemon = True

    def close(self):
        if not self.clientClosed:
            try:
                self.client.close()
            except:
                pass
            finally:
                self.clientClosed = True
        
        if not self.targetClosed:
            try:
                self.target.close()
            except:
                pass
            finally:
                self.targetClosed = True

    def run(self):
        try:
            self.client_buffer = self.client.recv(BUFLEN)
            
            hostPort = self.findHeader(self.client_buffer, 'X-Real-Host')
            
            if hostPort == '':
                hostPort = DEFAULT_HOST

            if hostPort != '':
                if hostPort.startswith('127.0.0.1') or hostPort.startswith('localhost'):
                    self.method_CONNECT(hostPort)
                else:
                    self.client.send(b'HTTP/1.1 403 Forbidden!\r\n\r\n')
            else:
                self.client.send(b'HTTP/1.1 400 NoXRealHost!\r\n\r\n')
        except Exception as e:
            self.log += f' - error: {str(e)}'
        finally:
            self.close()
            self.server.removeConn(self)

    def findHeader(self, head, header):
        try:
            head_str = head.decode('utf-8', errors='ignore')
            aux = head_str.find(header + ': ')
            if aux == -1:
                return ''
            
            aux = head_str.find(':', aux)
            head_str = head_str[aux+2:]
            aux = head_str.find('\r\n')
            
            if aux == -1:
                return ''
            
            return head_str[:aux].strip()
        except:
            return ''

    def connect_target(self, host):
        i = host.find(':')
        if i != -1:
            port = int(host[i+1:])
            host = host[:i]
        else:
            port = 80

        self.target = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.targetClosed = False
        self.target.connect((host, port))

    def method_CONNECT(self, path):
        self.log += f' - CONNECT {path}'
        self.connect_target(path)
        self.client.sendall(RESPONSE.encode())
        self.client_buffer = ''
        self.doCONNECT()

    def doCONNECT(self):
        socs = [self.client, self.target]
        count = 0
        error = False
        while not error:
            count += 1
            try:
                (recv, _, err) = select.select(socs, [], socs, 3)
                if err:
                    error = True
                if recv:
                    for in_ in recv:
                        try:
                            data = in_.recv(BUFLEN)
                            if data:
                                if in_ is self.target:
                                    self.client.send(data)
                                else:
                                    self.target.send(data)
                                count = 0
                            else:
                                error = True
                                break
                        except:
                            error = True
                            break
                if count >= TIMEOUT:
                    error = True
            except:
                error = True

def main():
    print(f"\nPython3 Proxy corriendo en {LISTENING_ADDR}:{LISTENING_PORT}")
    print(f"Redirigiendo a {DEFAULT_HOST}")
    print("Presiona Ctrl+C para detener\n")
    
    server = Server(LISTENING_ADDR, LISTENING_PORT)
    server.start()
    
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\nDeteniendo servidor...")
        server.close()

if __name__ == '__main__':
    # Parse arguments
    for i in range(len(sys.argv)):
        if sys.argv[i] == '-p' and i+1 < len(sys.argv):
            LISTENING_PORT = int(sys.argv[i+1])
        if sys.argv[i] == '-b' and i+1 < len(sys.argv):
            LISTENING_ADDR = sys.argv[i+1]
    
    main()
EOF

    # Reemplazar placeholder con el puerto SSH real
    sed -i "s/SSH_PORT_22/${SSH_PORT}/g" /tmp/proxy.py
    
    # Mover a ubicación final
    mv /tmp/proxy.py /usr/local/bin/proxy.py
    chmod +x /usr/local/bin/proxy.py
    
    # Crear servicio systemd para mayor estabilidad
    cat > /etc/systemd/system/python-proxy.service << EOF
[Unit]
Description=Python3 Proxy Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /usr/local/bin/proxy.py -p 80
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # Detener procesos existentes
    pkill -f python3 > /dev/null 2>&1
    sleep 2
    
    # Iniciar con systemd
    systemctl daemon-reload
    systemctl enable python-proxy.service > /dev/null 2>&1
    systemctl start python-proxy.service
    
    # Verificar que el servicio está corriendo
    sleep 3
    if systemctl is-active --quiet python-proxy.service; then
        echo -e "${green}Servicio Python3 proxy iniciado correctamente${white}"
    else
        # Fallback a screen si systemd falla
        echo -e "${yellow}Usando fallback con screen...${white}"
        screen -dmS pythonwe python3 /usr/local/bin/proxy.py -p 80
    fi
}
fun_bar 'inst_py'

# Verificación final
echo -e "${green}===================================================${white}"
echo -e "${green}           INSTALACIÓN COMPLETADA${white}"
echo -e "${green}===================================================${white}"
echo -e "${white}Servicios instalados:${white}"
echo -e "  • ${cyan}stunnel4${white} - Puerto 443 → 80"
echo -e "  • ${cyan}Python3 Proxy${white} - Puerto 80 → SSH:$SSH_PORT"
echo
echo -e "${yellow}Para verificar el estado:${white}"
echo "  systemctl status stunnel4"
echo "  systemctl status python-proxy.service"
echo "  o"
echo "  screen -ls (para ver sesión pythonwe)"
echo
echo -e "${green}===================================================${white}"

# Limpiar archivos temporales
rm -f proxy.py /tmp/proxy.py 2>/dev/null