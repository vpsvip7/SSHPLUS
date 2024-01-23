#!/bin/bash
[[ $(screen -list| grep -c 'bot_teste') == '0' ]] && {
    echo  -e "Imforme o token"
    read token
    cd $HOME/BOT
    screen -dmS bot_teste ./botssh $token > /dev/null 2>&1
} || {
    screen -r -S "bot_teste" -X quit
    clear && echo "BOT DESATIVADO"
}