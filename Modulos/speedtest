#!/bin/bash
FECHA=$(date +"%Y-%m-%d")
cor1='\033[1;31m'
cor2='\033[0;34m'
cor3='\033[1;35m'
clear
scor='\033[0m'
echo -e "\E[44;1;37m    INSTALADOR UDP @diegovip7      \E[0m"
echo ""
echo -e "
\e[1;31m[\e[1;36m01\e[1;31m] \e[1;37m• \e[1;33mUDP DEBIAN  \e[ [1;31m
[\e[1;36m02\e[1;31m] \e[1;37m• \e[1;33mTest Velocidad UDP \e[1;31m  \e[1;31m
[\e[1;36m03\e[1;31m] \e[1;37m• \e[1;33mUDP Donweb by Joaquin 🇦🇷 \e[1;31m      
[\e[1;36m04\e[1;31m] \e[1;37m• \e[1;33mUDP UBUNTU 18\e[1;31m      
[\e[1;36m05\e[1;31m] \e[1;37m• \e[1;33mUDP AUTO INSTALACION \e[1;31m  
[\e[1;36m06\e[1;31m] \e[1;37m• \e[1;33mIR A Menu UDP \e[1;31m        
[\e[1;36m07\e[1;31m] \e[1;37m• \e[1;33mUDP by Redjoker256 \e[1;31m
[\e[1;36m08\e[1;31m] \e[1;37m• \e[1;33mIR AL MENU 🏠\e[1;31m
[\e[1;36m09\e[1;31m] \e[1;37m• \e[1;33mSALIR ❌ \e[1;31m"

#leemos del teclado sentado
read n

case $n in
        1) clear

 rm -rf /root/install.sh && wget https://raw.githubusercontent.com/vpsvip7/1s/main/install.sh && chmod 777 install.sh && ./install.sh
            echo -ne "\n\033[1;31mListo \033[1;33mComando menu  \033[1;32mPara terminar de instalar!\033[0m"; read
            udp
           ;;
        2) clear
        speedtest
           echo -ne "\n\033[1;31mListo \033[1;33mComando menu  \033[1;32mPara terminar de instalar!\033[0m"; read
            udp
            ;;
        3) clear
            wget https://raw.githubusercontent.com/joaquin1444/udp/main/install_udp.sh -O install_udp.sh && chmod +x install_udp.sh && ./install_udp.sh
             sleep 6
           ;; 
        4) clear
     rm -rf /root/UDPserver.sh &&
             wget https://raw.githubusercontent.com/vpsvip7/2d/main/UDPserver.sh && chmod 777 UDPserver.sh && ./UDPserver.sh
            echo -ne "\n\033[1;31mEnter \033[1;33m Para volver al  \033[1;32mMenu!\033[0m"; read
            udp
           ;;
        5) clear
        wget https://raw.githubusercontent.com/vpsvip7/1s/main/udp-custom.sh -O install-udp && chmod +x install-udp && ./install-udp
        echo -ne "\n\033[1;31mEnter \033[1;33m Para volver al  \033[1;32mMenu!\033[0m"; read
         ;;
        6) udp
           ;;
        7)     git clone https://github.com/Redjoker256/Udpcustom.git && cd Udpcustom && chmod +x install.sh && ./install.sh 
           menu  ;;
         8)  menu
            ;;
          9)  exit
             ;;
        *) echo "Opción Incorrecta";;
esac