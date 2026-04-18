#!/bin/bash

# Script de instalação automática do VPS Reinstaller
# Detecta arquitetura e baixa o binário correto do GitHub

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configurações
GITHUB_USER="nandoslayer"  # ⚠️ ALTERE AQUI
GITHUB_REPO="vps-reinstaller"  # ⚠️ ALTERE AQUI
VERSION="latest"  # ou específica como "v1.0.0"

clear
echo -e "${CYAN}════════════════════════════════════${NC}"
echo -e "${CYAN}   🚀 VPS Reinstaller - Instalacion Automática${NC}"
echo -e "${CYAN}═════════════════════════════${NC}"
echo ""

# Detectar arquitetura
echo -e "${BLUE}🔍 Detectando arquitetura de sistema...${NC}"
ARCH=$(uname -m)
echo -e "   Arquitetura detectada: ${YELLOW}$ARCH${NC}"

case $ARCH in
    x86_64)
        BINARY_NAME="vps-reinstaller-x86_64"
        echo -e "   ${GREEN}✅ Compatível: Intel/AMD 64-bit${NC}"
        ;;
    aarch64|arm64)
        BINARY_NAME="vps-reinstaller-aarch64"
        echo -e "   ${GREEN}✅ Compatível: ARM 64-bit${NC}"
        ;;
    *)
        echo -e "   ${RED}❌ Arquitetura não suportada: $ARCH${NC}"
        echo ""
        echo "Arquiteturas suportadas:"
        echo "  • x86_64 (Intel/AMD 64-bit)"
        echo "  • aarch64 (ARM 64-bit)"
        exit 1
        ;;
esac

echo ""

# Verificar se wget ou curl está disponível
if command -v wget &> /dev/null; then
    DOWNLOADER="wget"
    DOWNLOAD_CMD="wget -q --show-progress"
elif command -v curl &> /dev/null; then
    DOWNLOADER="curl"
    DOWNLOAD_CMD="curl -L -o"
else
    echo -e "${RED}❌ Erro: wget ou curl no encontrado!${NC}"
    echo "Instale um dos dois:"
    echo "  • Debian/Ubuntu: apt install wget"
    exit 1
fi

echo -e "${BLUE}📥 Usando: ${YELLOW}$DOWNLOADER${NC}"
echo ""

# Construir URL do GitHub
if [ "$VERSION" = "latest" ]; then
    DOWNLOAD_URL="https://github.com/$GITHUB_USER/$GITHUB_REPO/releases/latest/download/$BINARY_NAME"
else
    DOWNLOAD_URL="https://github.com/$GITHUB_USER/$GITHUB_REPO/releases/download/$VERSION/$BINARY_NAME"
fi

echo -e "${BLUE}📦 Baixando binário do GitHub...${NC}"
echo -e "   URL: ${CYAN}$DOWNLOAD_URL${NC}"
echo ""

# Baixar arquivo
if [ "$DOWNLOADER" = "wget" ]; then
    wget -q --show-progress -O vps-reinstaller "$DOWNLOAD_URL"
else
    curl -L --progress-bar -o vps-reinstaller "$DOWNLOAD_URL"
fi

if [ $? -ne 0 ]; then
    echo ""
    echo -e "${RED}❌ Error al bajar o binário!${NC}"
    echo ""
    echo "Verifique se:"
    echo "  • A release existe no GitHub"
    echo "  • O arquivo $BINARY_NAME foi enviado"
    echo "  • Você tem acesso à internet"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Download concluído!${NC}"

# Dar permissão de execucion
echo -e "${BLUE}🔧 Configurando permissões...${NC}"
chmod +x vps-reinstaller

# Verificar tamanho do arquivo
SIZE=$(ls -lh vps-reinstaller | awk '{print $5}')
echo -e "   Tamanho do binário: ${YELLOW}$SIZE${NC}"

echo ""
echo -e "${GREEN}══════════════════════════════${NC}"
echo -e "${GREEN}✅ Instalação concluída com sucesso!${NC}"
echo -e "${GREEN}══════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}🚀 Para ejecutar, digite:${NC}"
echo -e "   ${CYAN}./vps-reinstaller${NC}"
echo ""
echo -e "${RED}⚠️  ATENCION:${NC}"
echo -e "   • Este programa va ${RED}BORRAR TODOS LOS DATOS${NC} DE TU VPS"
echo -e "   • HAGA ${YELLOW}BACKUP${NC} antes de Continuar"
echo -e "   • Vos ${RED}perdera axeso SSH${NC} temporarmente"
echo ""

# Perguntar se quer ejecutar ahora
if [ -t 1 ] && [ -e /dev/tty ]; then
    echo ""
    read -r -p "Desea ejecutar ahora? (s/N): " REPLY < /dev/tty
    echo ""
else
    REPLY="n"
fi

if [[ "$REPLY" =~ ^[Ss]$ ]]; then
    echo ""
    ./vps-reinstaller
else
    echo ""
    echo -e "${BLUE}👍 Execute quando estiver pronto: ${CYAN}./vps-reinstaller${NC}"
fi
