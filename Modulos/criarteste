#!/bin/bash
blanco='\033[38;5;231m'
amarillo='\033[38;5;228m'
azul='\033[38;5;14m'
morado='\033[38;5;147m'
moradoL='\033[38;5;54m'
rojo='\033[0;31m'
verde='\033[38;5;148m'
verdeR='\033[38;5;40m'
yellow='\033[0;33m'
rosa='\033[38;5;213m'
melon='\033[38;5;208m'
guinda='\033[38;5;161m'
azulR="\033[38;5;18m"
cierre='\033[0m'
bar1="\e[1;30m◚◚◚◚◚◚◚◚◚◚◚◚◚◚◚◚◚◚◚◚◚◚◚◚◚◚◚◚◚◚◚\e[0m"
bar2="\033[38;5;226m------------------------------------------------------\033[0m"
bar3="\033[38;5;226m------------------- = MENU = ------------------------\033[0m"
#PATH DE ARCHVOS
dir_token=/etc/token
file_token=$dir_token/BD
file_pass=$dir_token/.passw
file_client=$dir_token/.clientes
#DIRECTORIOS
mkdir_dir (){
  if [ -d $dir_token ]; then
	    echo
	    else
	     mkdir $dir_token
fi
if [ -f $file_token ]; then
	    echo
	    else
	     touch $file_token
       chmod 755 $file_token
fi
if [ -f $file_pass ]; then
	    echo
	    else
	     touch $file_passw
       chmod 755 $file_pass
fi
if [ -f $file_client ]; then
	    echo
	    else
	     touch $file_client
       chmod 755 $file_client
fi
}
#HORA DE MEXICO
echo "America/Mexico_City" > /etc/timezone
ln -fs /usr/share/zoneinfo/America/Mexico_City /etc/localtime > /dev/null 2>&1
dpkg-reconfigure --frontend noninteractive tzdata > /dev/null 2>&1
#MENSAJE DE BINEVENIDA
msg () {
echo -e "$bar1"
    echo -e "${rojo}#########################################${cierre}"
    echo -e "${rojo}#    ${verde}Bienvenido${blanco}, Gracias por utilizar Onlycode ${verdeR}VPN     ${rojo}# ${cierre}"
    echo -e "${rojo}#    ${blanco}Este SCRIPT autoriza su TOKEN ID para usar${cierre}        ${rojo}# ${cierre}"
    echo -e "${rojo}#    ${blanco}Nuestra apk...                            ${cierre}        ${rojo}# ${cierre}"
    echo -e "${rojo}#   ${melon}-----------------------------------------------    ${rojo}#${cierre}"
    echo -e "${rojo}#          ${blanco}dev: ${moradoL}@dankelthaher ${blanco}- ${amarillo}Onlycode ${verdeR}VPN${cierre}           ${rojo}#${cierre}"
    echo -e "${rojo}############################################${cierre}"
    echo -e "$bar1"
}
#DEFINE CONTRASEÑA UNICA
define (){
	mkdir_dir
echo -e "$bar1"
echo -e "${rojo}ANTES DE COMENZAR DEBE ingresar UNA contraseña"
echo -e "$bar2"
read -p "$(echo -e "${amarillo}[ingrese]: ${cierre}")" pass
echo -e "$pass" >> $file_pass
echo -e "$bar1"
}
#FUNCION DE CREACION DE USUARIOS
crear () {
    clear
    TITLE="${blanco}Onlycode ${verdeR}VPN"
echo -e "$TITLE"
echo -e ""
echo -e " AUTORIZAR TOKEN ID"
echo -e "$bar1"
echo -e ""
echo -e "${blanco}Ingrese el Nombre del Usuario${cierre}"
echo -e "$bar2"
read -p $'\e[32m  [ingrese]: \e[0m' usr
echo -e "$bar1"
echo -e "${blanco}Ingrese el TOKEN que desea Autorizar${cierre}"
echo -e "$bar2"
read -p $'\e[32m  [TOKEN ID]: \e[0m' token

# Check If Username Exist, Else Proceed
egrep "^$token" /etc/passwd >/dev/null
if [ $? -eq 0 ]; then
clear
echo -e "$bar1"
echo -e "$TITLE"
echo ""
echo -e "\e[31m El TOKEN ya existe en su servidor, intente con otro Token\e[0m."
exit 0
else
echo -e "$bar2"
read -p $'\e[32m  Dias activos: \e[0m' Days
echo -e "$bar1"
clear
sleep 1
IPADDR=$(wget -4qO- http://ipinfo.io/ip)
Today=`date +%s`
Days_Detailed=$(( $Days * 86400 ))
Expire_On=$(($Today + $Days_Detailed))
Expiration=$(date -u --date="1970-01-01 $Expire_On sec GMT" +%Y/%m/%d)
Expiration_Display=$(date -u --date="1970-01-01 $Expire_On sec GMT" '+%d %b %Y')
opensshport="$(netstat -ntlp | grep -i ssh | grep -i 0.0.0.0 | awk '{print $4}' | cut -d: -f2 | xargs | sed -e 's/ /, /g' )"
dropbearport="$(netstat -nlpt | grep -i dropbear | grep -i 0.0.0.0 | awk '{print $4}' | cut -d: -f2 | xargs | sed -e 's/ /, /g')"
stunnel4port="$(netstat -nlpt | grep -i stunnel4 | grep -i 0.0.0.0 | awk '{print $4}' | cut -d: -f2 | xargs | sed -e 's/ /, /g')"
openvpnport="$(netstat -nlpt | grep -i openvpn | grep -i 0.0.0.0 | awk '{print $4}' | cut -d: -f2 | xargs | sed -e 's/ /, /g')"
pyport="$(netstat -nlpt | grep -i python | grep -i 0.0.0.0 | awk '{print $4}' | cut -d: -f2 | xargs | sed -e 's/ /, /g')"
squidport="$(cat /etc/squid/squid.conf | grep -i http_port | awk '{print $2}' | xargs | sed -e 's/ /, /g')"
useradd -m -s /bin/false -e $Expiration $token > /dev/null
egrep "^$token" /etc/passwd &> /dev/null
DIA=`date +"%d/%m/%Y"`
HORA=`date +"%H:%M"`
echo -e "$(cat $file_pass)\n$(cat $file_pass)\n" | passwd $token &> /dev/null
echo -e "$token" >> $file_token
echo -e "$usr  $token  $DIA     $HORA"  >> $file_client
clear
echo -e "$bar1"
echo -e "$TITLE"
echo -e "$bar2"
echo ""
echo -e " Datos del Usuario:"
echo -e "\e[32m  Token ID: \e[0m"$token
echo -e "\e[32m  Caducidad de la cuenta: \e[0m"$Expiration_Display
echo -e ""
echo -e "$bar1"
echo -e "\e[32m  Host/IP: \e[0m"$IPADDR
echo -e "\e[32m  Perto OpenSSH: \e[0m"$opensshport
echo -e "\e[32m  Puerto Dropbear: \e[0m"$dropbearport
echo -e "\e[32m  Puerto SSL: \e[0m"$stunnel4port
echo -e "\e[32m  Puertos Squid: \e[0m"$squidport
echo -e "\e[32m  Puertos Openvpn: \e[0m"$openvpnport
echo -e "\e[32m  Puertos python: \e[0m"$pyport
echo -e "$bar1"
fi
}
#ELIMINAR ID
eliminar () {
  unset token
  echo -e "$TITLE"
echo -e ""
    i=1
	for total in `cat $file_token`; do
	[[ -f "$total" ]] && continue
	option_id[$i]="$total"
    echo -e "$bar1"
	echo -e "${azul} [$i] > $blanco$total"
	let i++
    done
	i=$(($i - 1))
    echo -e "$bar1"
	while [[ -z ${option_id[$slct_option]} ]]; do
read -p "seleccione [1-$i]: " slct_option
tput cuu1 && tput dl1
done
token="${option_id[$slct_option]}"
sleep 2
egrep "^$token" /etc/passwd &> /dev/null
if [ $? -eq 0 ]; then
  userdel -f $token
  rm -rf /home/$token
  sed -i "s;$token;;g" $file_token
  sed -i '/^$/d' $file_token
  sed -i "/$token/d" $file_client
  sed -i '/^$/d' $file_client
	clear
	echo -e ""
  echo -e "$TITLE"
  echo -e "$bar1"
	echo -e " TOKEN Eliminado con Exito"
	echo -e "$bar1"
else
	clear
	echo -e ""
  echo -e "$TITLE"
  echo -e "$bar1"
	echo -e " El TOKEN que ingresaste no existe"
	echo -e "$bar1"
fi
}
#EDITAR TOKEN
editar (){
unset token
  echo -e "$TITLE"
echo -e ""
    i=1
	for total in `cat $file_token`; do
	[[ -f "$total" ]] && continue
	option_id[$i]="$total"
    echo -e "$bar1"
	echo -e "${azul} [$i] > $blanco$total"
	let i++
    done
	i=$(($i - 1))
    echo -e "$bar1"
	while [[ -z ${option_id[$slct_option]} ]]; do
read -p "seleccione [1-$i]: " slct_option
tput cuu1 && tput dl1
done
token="${option_id[$slct_option]}"
sleep 2
egrep "^$token" /etc/passwd >/dev/null
if [ $? -eq 0 ]; then
echo -e "${blanco}Ingrese el numero de dias${cierre}"
echo -e "$bar2"
read -p " [Días]: " Days
Today=`date +%s`
Days_Detailed=$(( $Days * 86400 ))
Expire_On=$(($Today + $Days_Detailed))
Expiration=$(date -u --date="1970-01-01 $Expire_On sec GMT" +%Y/%m/%d)
Expiration_Display=$(date -u --date="1970-01-01 $Expire_On sec GMT" '+%d %b %Y')
passwd -u $token
usermod -e $Expiration $token
egrep "^$token" /etc/passwd >/dev/null
echo -e "$PASSWDT\n$PASSWDT\n"|passwd $token &> /dev/null
clear
echo -e "$TILTE"
echo -e "$bar1"
echo -e ""
echo -e " token ID: $token"
echo -e "$bar2"
echo -e " Caducidad de cuenta modificada: $Days Dias"
echo -e "$bar2"
echo -e " La cuenta vence el: $Expiration_Display"
echo -e "$bar1"
else
clear
echo -e "$TILTE"
echo -e "$bar1"
echo -e ""
echo -e " El Token que ingresaste no existe"
echo -e ""
fi
}
#MOSTAR USURIOS
lista (){
	if [ -f /etc/debian_version ]; then
	UIDN=1000
elif [ -f /etc/redhat-release ]; then
	UIDN=500
elif [ -f /etc/ubuntu_version ]; then
	UIDN=500
else
	UIDN=500
fi
clear
echo -e "$TILTE"
echo -e "$bar1"
echo -e ""
echo -e " TOKEN ID               Expiracion"
echo -e "$bar1"
while read Checklist
do
        Spacer=""
        Account="$(echo $Checklist | cut -d: -f1)"
        ID="$(echo $Checklist | grep -v nobody | cut -d: -f3)"
        Exp="$(chage -l $Account | grep "Account expires" | awk -F": " '{print $2}')"
        if [[ $ID -ge $UIDN ]]; then
        echo -e " $Account   " "   $Exp"
        fi
done < /etc/passwd
No_Users="$(awk -F: '$3 >= '$UIDN' && $1 != "nobody" {print $1}' /etc/passwd | wc -l)"
echo -e "$bar2"
echo -e " Numero de TOKENS: "$No_Users
echo -e "$bar2"
echo -ne "\n\033[1;31mARGENTINA 🇦🇷 \033[1;33m VPS1: \033[1;32mwep!\033[0m
\n\033[1;31mENTER \033[1;33mpara VOLVER al \033[1;32mMENU!\033[0m"; read
}
#ELIMINAR EXPIRADOS
expirados () {
clear
unset token
echo -e ""
echo -e "$TITLE"
echo -e "$bar1"

datenow=$(date +%s)
for token in $(awk -F: '{print $1}' /etc/passwd); do
expdate=$(chage -l $token|awk -F: '/Account expires/{print $2}')
echo $expdate | grep -q never && continue
echo -n "Token \`$token' expira el $expdate ... "
expsec=$(date +%s --date="$expdate")
diff=$(echo $datenow - $expsec|bc -l)
echo $diff | grep -q ^\- && echo okay && continue
userdel -r -f $token  &> /dev/null
done
echo -e ""
echo -e "  Todos \e[31mLos TOKEN expirados\e[0m han sido Eliminados"
echo -e "$bar1"
}
informacion_clientes () {
  GreenBG="\033[42;31m"
     echo -e "${GreenBG}               INFORMACION DE CLIENTES                 ${cierre}"
    echo -e "$bar1"
    cat $file_client | column -t
    echo -e "$bar1"
    echo -e ""
    echo -e "$TITLE"
    echo -e "$bar2"
   echo -ne "\n\033[1;31mARGENTINA 🇦🇷 \033[1;33m VPS2: \033[1;32mwep!\033[0m
\n\033[1;31mENTER \033[1;33mpara VOLVER al \033[1;32mMENU!\033[0m"; read
}
online (){                                                               
clear
TITLE="${blanco}Onlycode ${verdeR}VPN"

if [ -e "/var/log/auth.log" ]; then
        LOG="/var/log/auth.log";
fi
if [ -e "/var/log/secure" ]; then
        LOG="/var/log/secure";
fi
                
data=( `ps aux | grep -i dropbear | awk '{print $2}'`)
GreenBG="\033[42;31m"
     echo -e "${GreenBG}        Usuarios ONLINE Dropbear                ${cierre}"
    echo -e "$bar2"
    echo ""
cat $LOG | grep -i dropbear | grep -i "Password auth succeeded" > /tmp/login-db.txt
for PID in "${data[@]}"
do
        cat /tmp/login-db.txt | grep "dropbear\[$PID\]" > /tmp/login-db-pid.txt
        NUM=`cat /tmp/login-db-pid.txt | wc -l`
        USER=`cat /tmp/login-db-pid.txt | awk '{print $10}'`
        IP=`cat /tmp/login-db-pid.txt | awk '{print $12}'`
        if [ $NUM -eq 1 ]; then
                echo -e "Token: $USER - ${verdeR}[ON]${cierre} -"
                fi
done
GreenBG="\033[42;31m"
echo ""
     echo -e "${GreenBG}         Usuarios ONLINE OpenSSH                ${cierre}"
    echo -e "$bar2"
    echo ""
cat $LOG | grep -i sshd | grep -i "Accepted password for" > /tmp/logins-db.txt
data=( `ps aux | grep "\[priv\]" | sort -k 72 | awk '{print $2}'`);

for PID in "${data[@]}"
do
        cat /tmp/logins-db.txt | grep "sshd\[$PID\]" > /tmp/login-db-pid.txt;
        NUM=`cat /tmp/login-db-pid.txt | wc -l`;
        USER=`cat /tmp/login-db-pid.txt | awk '{print $9}'`;
        IP=`cat /tmp/login-db-pid.txt | awk '{print $11}'`;
        if [ $NUM -eq 1 ]; then
                echo -e "Token: $USER - ${verdeR}[ON]${cierre} -";
        fi
done
if [ -f "/etc/openvpn/openvpn-status.log" ]; then
        line=`cat /etc/openvpn/openvpn-status.log | wc -l`
        a=$((3+((line-8)/2)))
        b=$(((line-8)/2))
        echo ""
        echo -e "${GreenBG}          Usuarios ONLINE Openvpn               ${cierre}"
    echo -e "$bar2"
    echo ""
        
        cat /etc/openvpn/openvpn-status.log | head -n $a | tail -n $b | cut -d "," -f 1,2,5 | sed -e 's/,/   /g' > /tmp/vpn-login-db.txt
        cat /tmp/vpn-login-db.txt
fi

echo " "
echo " "
echo -ne "\n\033[1;31mARGENTINA 🇦🇷 \033[1;33m VPS3: \033[1;32mwep!\033[0m
\n\033[1;31mENTER \033[1;33mpara VOLVER al \033[1;32mMENU!\033[0m"; read
}
No_token="$(cat /etc/token/BD | wc -l)"
#MENU DE USUARIOS
menu () {
  clear
echo -e "${melon}               == Token Auth == (${amarillo}onlycode${cierre}${melon})
${bar1}
${morado}TOTAL DE REGISTROS: ${rojo}>${cierre} ${azul}TOKEN: ${blanco}$No_token  ${cierre}
${bar3}
${azul}[1]${cierre} ${rojo}>${cierre} ${blanco}AGREGAR ${verdeR}TOKEN${cierre}
${azul}[2]${cierre} ${rojo}>${cierre} ${blanco}ELIMINAR ${rojo}TOKEN${cierre}
${azul}[3]${cierre} ${rojo}>${cierre} ${blanco}EDITAR FECHA ${verde}TOKEN${cierre}
${azul}[4]${cierre} ${rojo}>${cierre} ${blanco}LISTA de ${verde}TOKEN${cierre}
${azul}[5]${cierre} ${rojo}>${cierre} ${blanco}ELIMINAR ${verde}TOKEN ${blanco}Expirados${cierre}
${azul}[6]${cierre} ${rojo}>${cierre} ${blanco}Informacion de Clientes${cierre}
${azul}[7]${cierre} ${rojo}>${cierre} ${blanco}TOKEN ${verdeR}ONLINES${cierre}
${azul}[0]${cierre} ${rojo}>${cierre} ${rojo}SALIR al Menu${cierre}
${bar2}"
read -p "$(echo -e "${blanco}seleccione [0-7]:${cierre}")" selection
case "$selection" in
	1)crear ;;
	2)eliminar ;;
  3)editar ;;
  4)lista;;
  5)expirados ;;
  6)informacion_clientes;;
  7)online;;
	0)cd $HOME && exit 0;;
	*)
	echo -e "${rojo} Porfavor seleccione del [0-5]${cierre}"
	;;
esac
}
if [ -f $file_pass ]; then
	    echo
	    else
    define
fi
msg
menu