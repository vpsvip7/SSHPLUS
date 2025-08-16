#!/bin/bash

while true; do
  echo "MENÚ LIMiTADOr de Velocidad"
  echo "Seleccione una opción:"
  echo "1. INSTALAR LIMITADOR"
  echo "2. LIMITAR A 8MB APROX "
  echo "3. LIMITAR A 10MB APROX "
echo "4. LIMITAR A 14MB APROX "
  echo "5. Medir la Velocidad de tu maquina "
  echo "6. Salir"

  read -p "Opción: " opcion

  case $opcion in
    1)
      wget https://raw.githubusercontent.com/vpsvip7/json24/refs/heads/main/limit_bandwidth.sh && chmod 777 limit_bandwidth.sh && ./limit_bandwidth.sh
      echo "INSTALANDO LIMITADOR"
      ;;
    2)
      ./limit_bandwidth.sh eth0 9mbit 9mbit
      echo "Limitar a 5mb aprox"
      ;;
    3)
      ./limit_bandwidth.sh eth0 15mbit 15mbit
      echo "Limitar a 8mb aprox"
      ;;
4)
      ./limit_bandwidth.sh eth0 20mbit 20mbit
      echo "Limitar a 10mb aprox"
      ;;
5)
      speedtest
      echo "Testear la Velocidad de tu Maquina"
      ;;
    6)
      echo "Saliendo del script..."
      break
      ;;
    *)
      echo "Opción inválida"
      ;;
  esac

  echo
done
