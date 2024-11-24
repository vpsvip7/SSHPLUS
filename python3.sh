#!/bin/bash
FECHA=$(date +"%Y-%m-%d")
cor1='\033[1;31m'
cor2='\033[0;34m'
cor3='\033[1;35m'
clear
scor='\033[0m'
echo -e "\E[44;1;37m       ELEGIR   UNA   OPCION      \E[0m"
echo -e "  [\033[1;36m1:\033[1;31m] \033[1;37m• \033[1;32mIniciar -Reiniciar Psi \033[1;31m"
echo -e "  [\033[1;36m2:\033[1;31m] \033[1;37m• \033[1;33mVerificar Screen \033[1;31m    "
echo -e "   [\033[1;36m3:\033[1;31m] \033[1;37m• \033[1;33mVer Puertos Activos \033[1;31m      \E[0m"
echo  -e "    [\033[1;36m4\033[1;31m] \033[1;37m• \033[1;33mVer Codigo Tarjet \033[1;31m  "
echo  -e  "  [\033[1;36m5:\033[1;31m] \033[1;37m• \033[1;33mTestear Velocidad \033[1;31m  "
echo  -e  "   [\033[1;36m5:\033[1;31m] \033[1;37m• \033[1;33mProbar Velocidsd \033[1;31m  "
echo  -e " [\033[1;36m7:\033[1;31m] \033[1;37m• \033[1;33mLimpiar Ram \033[1;31m"
echo  -e "     [\033[1;36m8:\033[1;31m] \033[1;37m• \033[1;33mBorrar Psiphon \033[1;31m "
echo  -e "  [\033[1;36m41\033[1;31m] \033[1;37m• \033[1;33mVer Conectados \033[1;31m "

#leemos del teclado sentado
read n

case $n in
        1) clear
cd /root/psi && screen -dmS PSI ./psiphond run
            echo -ne "\n\033[1;31mListo \033[1;33mPsiphon Iniciado o  \033[1;32mReiniciado!\033[0m"; read
           ;;
        2) clear
        which screen
           sleep 5 
            ;;
        3) clear
            netstat -tnpl
             sleep 6
           ;; 
        4) clear
             cd /root/psi&&cat /root/psi/server-entry.dat;echo ''
            sleep 15
           ;;
        5) speedtest
        echo -ne "\n\033[1;31mEnter \033[1;33m Para volver al  \033[1;32mMenu!\033[0m"; read
         ;;
        6) apt update 
             menu;;
        7)     sync & sysctl -w vm.drop_caches=3 
           menu   ;;
         8)  rm -rf /root/psi
             menu;;
          9)  ./verconectados.sh
             menu;;
        *) echo "Opción Incorrecta";;
esac