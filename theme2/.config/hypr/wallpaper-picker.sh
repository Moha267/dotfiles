#!/bin/bash
WALLPAPER_DIR="$HOME/Pictures/wallpaper"

# Pick wallpaper using rofi
selected=$(ls "$WALLPAPER_DIR" | rofi -dmenu -p "Wallpaper" -theme ~/.config/rofi/launchers/type-2/style-1.rasi)

# Apply if something was selected
[ -n "$selected" ] && awww img "$WALLPAPER_DIR/$selected" --transition-type wipe
