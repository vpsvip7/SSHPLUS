#!/bin/bash
 #by @vps10
 ADM_inst="/etc/SSHPlus/Slow/install" && [[ ! -d ${ADM_inst} ]] && exit
 ADM_slow="/etc/SSHPlus/Slow/Key" && [[ ! -d ${ADM_slow} ]] && exit
 info(){
 	clear
 	nodata(){
 		echo -e " ........ "
echo -e "!NO SLOWDNS INFORMACION!"
 		exit 0
 	}
 
 	if [[ -e  ${ADM_slow}/domain_ns ]]; then
 		ns=$(cat ${ADM_slow}/domain_ns)
 		if [[ -z "$ns" ]]; then
 			nodata
 			exit 0
 		fi
 	else
 		nodata
 		exit 0
 	fi
 
 	if [[ -e ${ADM_slow}/server.pub ]]; then
 		key=$(cat ${ADM_slow}/server.pub)
 		if [[ -z "$key" ]]; then
 			nodata
 			exit 0
 		fi
 	else
 		nodata
 		exit 0
 	fi
 
 	echo -e "No datos "
 echo -e "Your NS (Nameserver): $(cat ${ADM_slow}/domain_ns)"
 	echo -e "Your public key: $(cat ${ADM_slow}/server.pub)"
 	
 	exit 0
 }
 
 drop_port(){
     local portasVAR=$(lsof -V -i tcp -P -n | grep -v "ESTABLISHED" |grep -v "COMMAND" | grep "LISTEN")
     local NOREPEAT
     local reQ
     local Port
     unset DPB
     while read port; do
         reQ=$(echo ${port}|awk '{print $1}')
         Port=$(echo {$port} | awk '{print $9}' | awk -F ":" '{print $2}')
         [[ $(echo -e $NOREPEAT|grep -w "$Port") ]] && continue
         NOREPEAT+="$Port\n"
 
         case ${reQ} in
         	sshd|dropbear|stunnel4|stunnel|python|python3)DPB+=" $reQ:$Port";;
             *)continue;;
         esac
     done <<< "${portasVAR}"
  }
 
 ini_slow(){
echo -e " INSTALADO SLOWDNS "
 	drop_port
 	n=1
     for i in $DPB; do
         proto=$(echo $i|awk -F ":" '{print $1}')
         proto2=$(printf '%-12s' "$proto")
         port=$(echo $i|awk -F ":" '{print $2}')
         echo -e " $(msg -verd "[$n]") $(msg -verm2 ">") $(msg -ama "$proto2")$(msg -azu "$port")"
         drop[$n]=$port
         num_opc="$n"
         let n++ 
     done
     opc=$(selection_fun $num_opc)
     echo "${drop[$opc]}" > ${ADM_slow}/puerto
     PORT=$(cat ${ADM_slow}/puerto)
    echo -e "SLOWDNS INSTALLER"
     echo -e " $(msg -ama "Connection port through SlowDNS:") $(msg -verd "$PORT")"
 
     unset NS
     while [[ -z $NS ]]; do
echo -e "Your NS domain (Nameserver): "
     	read NS
     	tput cuu1 && tput dl1
     done
     echo "$NS" > ${ADM_slow}/domain_ns
     echo -e " $(msg -ama "Your NS domain (Nameserver)") $(msg -verd "$NS")"
     echo -e "Espere..... "
 
     if [[ ! -e ${ADM_inst}/dns-server ]]; then
  echo -e " Downloading binary...."
     	if wget -O ${ADM_inst}/dns-server https://raw.githubusercontent.com/khaledagn/VPS-AGN_English_Official/master/LINKS-LIBRARIES/dns-server &>/dev/null ; then
     		chmod +x ${ADM_inst}/dns-server
echo -e "[OK]"
     	else
echo -e "[fail]"
echo -e "Could not download binary"
echo -e "Installation canceled"
     		
     		exit 0
     	fi
     	echo -e "Espere.. "
     fi
 
     [[ -e "${ADM_slow}/server.pub" ]] && pub=$(cat ${ADM_slow}/server.pub)
 
     if [[ ! -z "$pub" ]]; then
echo -e " Use existing key [Y/N]: "
     	read ex_key
 
     	case $ex_key in
     		s|S|y|Y) tput cuu1 && tput dl1
     			 echo -e " $(msg -ama "Your key:") $(msg -verd "$(cat ${ADM_slow}/server.pub)")";;
     		n|N) tput cuu1 && tput dl1
     			 rm -rf ${ADM_slow}/server.key
     			 rm -rf ${ADM_slow}/server.pub
     			 ${ADM_inst}/dns-server -gen-key -privkey-file ${ADM_slow}/server.key -pubkey-file ${ADM_slow}/server.pub &>/dev/null
     			 echo -e " $(msg -ama "Your key::") $(msg -verd "$(cat ${ADM_slow}/server.pub)")";;
     		*);;
     	esac
     else
     	rm -rf ${ADM_slow}/server.key
     	rm -rf ${ADM_slow}/server.pub
     	${ADM_inst}/dns-server -gen-key -privkey-file ${ADM_slow}/server.key -pubkey-file ${ADM_slow}/server.pub &>/dev/null
     	echo -e " $(msg -ama "Your key:") $(msg -verd "$(cat ${ADM_slow}/server.pub)")"
     fi

   echo -e "   Iniciando SlowDNS...."
 
     iptables -I INPUT -p udp --dport 5300 -j ACCEPT
     iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300
 
     if screen -dmS slowdns ${ADM_inst}/dns-server -udp :5300 -privkey-file ${ADM_slow}/server.key $NS 127.0.0.1:$PORT ; then
     	echo -e "Successfully!!!"
     else
echo -e "With failure!!!"
     fi
     exit 0
 }
 
 reset_slow(){
 	clear
echo -e " Reiniciando SlowDNS...."
 	screen -ls | grep slowdns | cut -d. -f1 | awk '{print $1}' | xargs kill
 	NS=$(cat ${ADM_slow}/domain_ns)
 	PORT=$(cat ${ADM_slow}/puerto)
 	if screen -dmS slowdns /etc/slowdns/dns-server -udp :5300 -privkey-file /root/server.key $NS 127.0.0.1:$PORT ;then
 		echo -e "Successfully!!!"
 	else
echo -e "With failure!!!"
 	fi
 	exit 0
 }
 stop_slow(){
 	clear
 	echo -e "...... "
echo -e "  Pararando SlowDNS...."
 	if screen -ls | grep slowdns | cut -d. -f1 | awk '{print $1}' | xargs kill ; then
echo -e "Successfully!!!"
 	else
echo -e "With failure!!!"
 	fi
 	exit 0
 }
 
 while :
 do
 	clear
 	echo -e " ........ "
echo -e "INSTALADOR SLOWDNS "
 	clear
echo -e "\E[44;1;37m       ELEGIR   UNA   OPCION      \E[0m"
echo -e "  [\033[1;36m1:\033[1;31m] \033[1;37m• \033[1;32mIniciar -Reiniciar Psi \033[1;31m"
echo -e "  [\033[1;36m2:\033[1;31m] \033[1;37m• \033[1;33mVerificar Screen \033[1;31m    "
echo -e "   [\033[1;36m3:\033[1;31m] \033[1;37m• \033[1;33mVer Puertos Activos \033[1;31m      \E[0m"
echo  -e "    [\033[1;36m4\033[1;31m] \033[1;37m• \033[1;33mVer Codigo Tarjet \033[1;31m  "
echo  -e  "  [\033[1;36m5:\033[1;31m] \033[1;37m• \033[1;33mTestear Velocidad \033[1;31m  "
echo  -e  "   [\033[1;36m5:\033[1;31m] \033[1;37m• \033[1;33mProbar Velocidsd \033[1;31m  "
echo  -e " [\033[1;36m7:\033[1;31m] \033[1;37m• \033[1;33mLimpiar Ram \033[1;31m"
echo  -e "[\033[1;36m8:\033[1;31m] \033[1;37m• \033[1;33mBorrar Psiphon \033[1;31m "
echo  -e "[\033[1;36m41\033[1;31m] \033[1;37m• \033[1;33mVer Conectados \033[1;31m "
 
 	case $opcion in
 		1)info;;
 		2)ini_slow;;
 		3)reset_slow;;
 		4)stop_slow;;
 		5)wget -q -O slow.sh https://raw.githubusercontent.com/joaquin1444/instalador/refs/heads/main/slow.sh && chmod +x slow.sh && ./slow.sh;;
 		0)exit;;
 	esac
 done
  