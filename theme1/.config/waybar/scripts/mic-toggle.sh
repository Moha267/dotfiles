#!/bin/bash

case $1 in
    toggle)
        pactl set-source-mute @DEFAULT_SOURCE@ toggle
        ;;
    status)
        MUTED=$(pactl get-source-mute @DEFAULT_SOURCE@ | awk '{print $2}')
        if [ "$MUTED" = "yes" ]; then
            echo '{"text": "󰍭", "tooltip": "Mic muted", "class": "muted"}'
        else
            echo '{"text": "󰍬", "tooltip": "Mic active", "class": "active"}'
        fi
        ;;
esac
