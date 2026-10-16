#!/bin/bash

# ── Config ────────────────────────────────────────────────────
CONFIG_FILE="$HOME/.config/waybar/scripts/prayer.conf"
ICON="🕌"
PRAYER_KEYS=("Fajr" "Dhuhr" "Asr" "Maghrib" "Isha")

# Load config or fall back to defaults (Mansoura, Egypt, Method 5)
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    LATITUDE=31.0364
    LONGITUDE=31.3807
    METHOD=5
fi

# ── Fetch & Cache ─────────────────────────────────────────────
CACHE_FILE="/tmp/waybar_prayer_${LATITUDE}_${LONGITUDE}_${METHOD}_$(date +%Y%m%d).json"

if [[ ! -f "$CACHE_FILE" ]]; then
    rm -f /tmp/waybar_prayer_*.json 2>/dev/null

    RESPONSE=$(curl -sf --max-time 5 \
        "https://api.aladhan.com/v1/timings/$(date +%d-%m-%Y)?latitude=${LATITUDE}&longitude=${LONGITUDE}&method=${METHOD}")

    if [[ $? -ne 0 || -z "$RESPONSE" ]]; then
        echo '{"text": "🕌 --:--", "tooltip": "Prayer times unavailable", "class": "prayer-error"}'
        exit 0
    fi

    echo "$RESPONSE" > "$CACHE_FILE"
fi

# ── Parse Timings ─────────────────────────────────────────────
NOW_SEC=$(date +%s)
NOW_DATE=$(date +%Y-%m-%d)

NEXT_PRAYER=""
MIN_DIFF=99999999
declare -A PRAYER_TIMES

for KEY in "${PRAYER_KEYS[@]}"; do
    TIME_STR=$(grep -o "\"${KEY}\":\"[^\"]*\"" "$CACHE_FILE" | cut -d'"' -f4 | cut -d' ' -f1)
    [[ -z "$TIME_STR" ]] && continue

    PRAYER_TIMES[$KEY]=$TIME_STR
    PRAYER_SEC=$(date -d "${NOW_DATE} ${TIME_STR}" +%s 2>/dev/null)
    [[ $? -ne 0 ]] && continue

    DIFF=$(( PRAYER_SEC - NOW_SEC ))

    if (( DIFF > 0 && DIFF < MIN_DIFF )); then
        MIN_DIFF=$DIFF
        NEXT_PRAYER=$KEY
    fi
done

# If no future prayer today, next is Fajr tomorrow
if [[ -z "$NEXT_PRAYER" ]]; then
    FAJR_TOMORROW=$(date -d "tomorrow ${PRAYER_TIMES[Fajr]}" +%s 2>/dev/null)
    NEXT_PRAYER="Fajr"
    MIN_DIFF=$(( FAJR_TOMORROW - NOW_SEC ))
fi

# ── Format Countdown ──────────────────────────────────────────
HOURS=$(( MIN_DIFF / 3600 ))
MINS=$(( (MIN_DIFF % 3600) / 60 ))

(( HOURS > 0 )) && COUNTDOWN="${HOURS}h ${MINS}m" || COUNTDOWN="${MINS}m"

# ── Build Tooltip ─────────────────────────────────────────────
TOOLTIP="📍 ${LATITUDE}, ${LONGITUDE} | Method ${METHOD}\n"
for KEY in "${PRAYER_KEYS[@]}"; do
    [[ "$KEY" == "$NEXT_PRAYER" ]] \
        && TOOLTIP+="▶ ${KEY}: ${PRAYER_TIMES[$KEY]}\n" \
        || TOOLTIP+="  ${KEY}: ${PRAYER_TIMES[$KEY]}\n"
done
TOOLTIP+="(click to change settings)"

# ── Output JSON for Waybar ────────────────────────────────────
if (( MIN_DIFF <= 900 )); then
    CLASS="prayer-soon"
elif (( MIN_DIFF <= 1800 )); then
    CLASS="prayer-warning"
else
    CLASS="prayer"
fi
ALERT_FLAG="/tmp/waybar_prayer_alert_${NEXT_PRAYER}"
if (( MIN_DIFF <= 900 && MIN_DIFF > 0 )); then
    if [[ ! -f "$ALERT_FLAG" ]]; then
        touch "$ALERT_FLAG"
        paplay ~/.config/waybar/scripts/prayer-alert.ogg &
    fi
else
    rm -f "$ALERT_FLAG" 2>/dev/null
fi

printf '{"text": "%s %s — %s", "tooltip": "%s", "class": "%s"}' \
    "$ICON" "$NEXT_PRAYER" "$COUNTDOWN" "$TOOLTIP" "$CLASS"
