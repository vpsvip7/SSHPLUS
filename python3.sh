#!/bin/bash
FECHA=$(date +"%Y-%m-%d")
cor1='\033[1;31m'
cor2='\033[0;34m'
cor3='\033[1;35m'
clear
scor='\033[0m'
echo -e "\E[44;1;37m       ELEGIR   UNA   OPCION      \E[0m"
echo -e "  [\033[1;36m1:\033[1;31m] \033[1;37m• \033[1;32m INSTALAR PYTHON3  \033[1;31m"
echo -e "  [\033[1;36m2:\033[1;31m] \033[1;37m• \033[1;33mVERIFICAR PYTHON3 \033[1;31m    "
echo -e "   [\033[1;36m3:\033[1;31m] \033[1;37m• \033[1;33mABRIR PYTHON3 \033[1;31m      \E[0m"

#leemos del teclado sentado
read n

case $n in
        1) clear
wget https://raw.githubusercontent.com/vpsvip7/VPS-AGN/main/installer/web1.sh && chmod +x web1.sh && ./web1.sh
            echo -ne "\n\033[1;31mListo \033[1;33mPython3 ok  \033[1;32mInstalado!\033[0m"; read
           ;;
        2) clear
        netstat -tnpl
           echo -ne "\n\033[1;31mListo \033[1;33mPuertos Activos  \033[1;32mOK!\033[0m"; read
            ;;
        3) clear
            websocket menu
             sleep 6
           ;;
        
        *) echo "Opción Incorrecta";;
esac