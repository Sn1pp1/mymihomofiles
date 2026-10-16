#!/bin/bash
set -euo pipefail

OUTPUT_DIR="output"
TEMP_DIR=$(mktemp -d)

# Очистка TEMP_DIR при любом выходе (успех/ошибка)
trap 'rm -rf "$TEMP_DIR"' EXIT

# ============================================
# ФУНКЦИИ ПРОВЕРКИ
# ============================================

check_http_response() {
    local url="$1"
    # Используем GET вместо HEAD (-I), так как GitHub raw-ссылки иногда некорректно отвечают на HEAD
    local response
    response=$(curl -sL --max-time 5 -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
    [[ "$response" == "200" ]]
}

check_not_html() {
    local file="$1"
    ! head -c 500 "$file" | grep -qi '<!DOCTYPE\|<html\|<head\|<body'
}

check_file_size() {
    local file="$1"
    local min_size="${2:-50}"
    
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    
    local size
    size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo "0")
    [[ "$size" -ge "$min_size" ]]
}

# ============================================
# МАССИВЫ
# ============================================

declare -A GEOSITE_TXT=(
    ["direct"]="https://github.com/Sn1pp1/mygeofiles/raw/refs/heads/main/files/direct.txt"
    ["category-ads"]="https://github.com/Sn1pp1/mygeofiles/raw/refs/heads/main/files/category-ads.txt"
    ["ru-blocklist"]="https://github.com/Sn1pp1/mygeofiles/raw/refs/heads/main/files/ru-blocklist.txt"
    ["ru-list"]="https://github.com/Sn1pp1/mygeofiles/raw/refs/heads/main/files/ru-list.txt"
)

declare -A GEOSITE_MRS=(
    ["private"]="https://github.com/MetaCubeX/meta-rules-dat/raw/refs/heads/meta/geo/geosite/private.mrs"
    ["youtube"]="https://github.com/MetaCubeX/meta-rules-dat/raw/refs/heads/meta/geo/geosite/youtube.mrs"
)

declare -A GEOSITE_YAML=()

declare -A GEOIP_TXT=(
    ["direct-ip"]="https://github.com/Sn1pp1/mygeofiles/raw/refs/heads/main/files/direct-ip.txt"
    ["ru-blocklist-ip"]="https://github.com/Sn1pp1/mygeofiles/raw/refs/heads/main/files/ru-blocklist-ip.txt"
    ["ru-list-ip"]="https://github.com/Sn1pp1/mygeofiles/raw/refs/heads/main/files/ru-list-ip.txt"
)

declare -A GEOIP_MRS=(
    ["private-ip"]="https://github.com/MetaCubeX/meta-rules-dat/raw/refs/heads/meta/geo/geoip/private.mrs"
)

declare -A GEOIP_YAML=()

# ============================================
# СКАЧИВАНИЕ MIHOMO
# ============================================

echo "⚙️ Скачиваем mihomo..."
if ! command -v jq &> /dev/null; then
    echo "⚠️ jq не найден, устанавливаем..."
    sudo apt-get update && sudo apt-get install -y jq >/dev/null 2>&1 || true
fi

LATEST_JSON=$(curl -sL --retry 3 --retry-delay 2 https://api.github.com/repos/MetaCubeX/mihomo/releases/latest)
MIHOMO_VERSION=$(echo "$LATEST_JSON" | jq -r '.tag_name')
echo "📦 Версия: ${MIHOMO_VERSION}"

MIHOMO_URL=$(echo "$LATEST_JSON" | jq -r '.assets[].browser_download_url' | grep -E 'mihomo-linux-amd64-compatible.*\.gz$' | head -1)
[[ -z "$MIHOMO_URL" ]] && MIHOMO_URL=$(echo "$LATEST_JSON" | jq -r '.assets[].browser_download_url' | grep -E 'mihomo-linux-amd64-v.*\.gz$' | head -1)
[[ -z "$MIHOMO_URL" ]] && MIHOMO_URL=$(echo "$LATEST_JSON" | jq -r '.assets[].browser_download_url' | grep -E 'mihomo-linux-amd64.*\.gz$' | grep -v '\.pkg\.tar' | head -1)

if [[ -z "$MIHOMO_URL" ]]; then
    echo "❌ Не удалось найти URL для скачивания mihomo"
    exit 1
fi

curl -fL --retry 3 --retry-delay 2 "$MIHOMO_URL" -o "$TEMP_DIR/mihomo.gz"
gunzip -f "$TEMP_DIR/mihomo.gz"
chmod +x "$TEMP_DIR/mihomo"

echo "✅ Mihomo готов"
mkdir -p "$OUTPUT_DIR"

TOTAL_FILES=0
FAILED_FILES=0

# ============================================
# GeoSite TXT — КОНВЕРТАЦИЯ
# ============================================
if [[ ${#GEOSITE_TXT[@]} -gt 0 ]]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🌐 GeoSite TXT → MRS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    for NAME in "${!GEOSITE_TXT[@]}"; do
        SOURCE_URL="${GEOSITE_TXT[$NAME]}"
        echo ""
        echo "🔄 $NAME"
        
        TOTAL_FILES=$((TOTAL_FILES + 1))
        
        echo "  🔍 Проверка источника..."
        if ! check_http_response "$SOURCE_URL"; then
            echo "  ❌ HTTP ошибка"
            FAILED_FILES=$((FAILED_FILES + 1))
            continue
        fi
        echo "  ✅ HTTP OK"
        
        echo "  📥 Скачиваем..."
        curl -sL --retry 3 --retry-delay 2 "$SOURCE_URL" -o "$TEMP_DIR/${NAME}.txt"
        
        if ! check_file_size "$TEMP_DIR/${NAME}.txt" 1; then
            echo "  ❌ Файл не скачался или пуст"
            FAILED_FILES=$((FAILED_FILES + 1))
            continue
        fi
        
        echo "  🔍 Проверка на HTML..."
        if ! check_not_html "$TEMP_DIR/${NAME}.txt"; then
            echo "  ❌ Файл содержит HTML"
            FAILED_FILES=$((FAILED_FILES + 1))
            continue
        fi
        echo "  ✅ Целостность OK"
        
        LINE_COUNT=$(wc -l < "$TEMP_DIR/${NAME}.txt")
        echo "  📊 Строк в исходнике: $LINE_COUNT"
        echo "  🔄 Обрабатываем и формируем YAML..."
        
        if [[ -f "$OUTPUT_DIR/${NAME}.mrs" ]]; then
            cp "$OUTPUT_DIR/${NAME}.mrs" "$TEMP_DIR/${NAME}.mrs.backup"
            echo "  💾 Бэкап сохранен"
        fi
        
        {
            echo "payload:"
            awk '
            /^[[:space:]]*#/ { next }
            /^[[:space:]]*$/ { next }
            {
                # 1. Удаляем префиксы правил
                sub(/^(DOMAIN|DOMAIN-SUFFIX|DOMAIN-KEYWORD|FULL|HOST|KEYWORD|REGEXP|REGEX|HOST-SUFFIX|HOST-KEYWORD|HOST-REGEX|GEOSITE|GEOIP|AND|OR|NOT|URL-REGEX|URL-REGEXP|USER-AGENT|SCRIPT|PROCESS-NAME|PROCESS-PATH|PORT|DST-PORT|SRC-PORT|IN-PORT|NETWORK|IN-NAME|IN-TYPE):/, "", $0)
                
                # 2. Удаляем +. *. в начале
                sub(/^[+*]+\.+/, "", $0)
                
                # 3. Чистим URL и мусор
                sub(/^https?:\/\//, "", $0)
                sub(/^[^@]*@/, "", $0)
                sub(/:[0-9]+$/, "", $0)
                sub(/\/.*$/, "", $0)
                sub(/\?.*$/, "", $0)
                sub(/#.*$/, "", $0)
                sub(/,.*$/, "", $0)
                sub(/[[:space:]]*#.*$/, "", $0)
                gsub(/\.\./, ".")
                
                # КРИТИЧЕСКОЕ ИСПРАВЛЕНИЕ: явное удаление конечной точки
                sub(/\.$/, "", $0)
                
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)

                # 4. Базовая валидация
                if ($0 == "") next
                if ($0 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) next
                if ($0 ~ /:/) next
                if ($0 ~ / /) next
                if ($0 ~ /[^a-zA-Z0-9._-]/) next # Строгая проверка на недопустимые символы

                # 5. ГАРАНТИЯ СОХРАНЕНИЯ TLD (Whitelist)
                if ($0 !~ /\./) {
                    if ($0 != "ru" && $0 != "su" && $0 != "by" && $0 != "moscow" && $0 != "local" && $0 != "lan" && $0 != "localhost" && $0 != "internal" && $0 != "localdomain" && $0 != "example" && $0 != "invalid" && $0 != "test" && $0 !~ /^xn--/) {
                        next
                    }
                }

                # 6. Форматируем для Mihomo YAML
                printf "  - \x27+.%s\x27\n", $0
            }' "$TEMP_DIR/${NAME}.txt" | LC_ALL=C sort -u
        } > "$TEMP_DIR/${NAME}.yaml"
        
        DOMAIN_COUNT=$(grep -c "^  - " "$TEMP_DIR/${NAME}.yaml" 2>/dev/null || echo "0")
        
        if [[ "$DOMAIN_COUNT" -eq 0 ]]; then
            echo "  ⚠️ Нет доменов для конвертации"
            FAILED_FILES=$((FAILED_FILES + 1))
            continue
        fi
        
        echo "  🔧 Конвертируем в MRS (доменов: $DOMAIN_COUNT)..."
        
        if ! "$TEMP_DIR/mihomo" convert-ruleset domain yaml "$TEMP_DIR/${NAME}.yaml" "$OUTPUT_DIR/${NAME}.mrs" 2>&1; then
            echo "  ❌ Ошибка конвертации!"
            if [[ -f "$TEMP_DIR/${NAME}.mrs.backup" ]]; then
                echo "  💾 Восстанавливаем предыдущую версию..."
                cp "$TEMP_DIR/${NAME}.mrs.backup" "$OUTPUT_DIR/${NAME}.mrs"
            fi
            FAILED_FILES=$((FAILED_FILES + 1))
            continue
        fi
        
        if ! check_file_size "$OUTPUT_DIR/${NAME}.mrs" 1; then
            echo "  ❌ Файл пустой"
            if [[ -f "$TEMP_DIR/${NAME}.mrs.backup" ]]; then
                cp "$TEMP_DIR/${NAME}.mrs.backup" "$OUTPUT_DIR/${NAME}.mrs"
            fi
            FAILED_FILES=$((FAILED_FILES + 1))
            continue
        fi
        
        echo "  ✅ $OUTPUT_DIR/${NAME}.mrs ($(du -h "$OUTPUT_DIR/${NAME}.mrs" | cut -f1))"
    done
fi

# ============================================
# GeoSite YAML — КОНВЕРТАЦИЯ
# ============================================
if [[ ${#GEOSITE_YAML[@]} -gt 0 ]]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🌐 GeoSite YAML → MRS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    for NAME in "${!GEOSITE_YAML[@]}"; do
        SOURCE_URL="${GEOSITE_YAML[$NAME]}"
        echo ""
        echo "🔄 $NAME"
        
        TOTAL_FILES=$((TOTAL_FILES + 1))
        
        echo "  🔍 Проверка источника..."
        if ! check_http_response "$SOURCE_URL"; then
            echo "  ❌ HTTP ошибка"
            FAILED_FILES=$((FAILED_FILES + 1))
            continue
        fi
        echo "  ✅ HTTP OK"
        
        echo "  📥 Скачиваем..."
        curl -sL --retry 3 --retry-delay 2 "$SOURCE_URL" -o "$TEMP_DIR/${NAME}.yaml"
        
        if ! check_file_size "$TEMP_DIR/${NAME}.yaml" 10; then
            echo "  ❌ Файл не скачался или слишком мал"
            FAILED_FILES=$((FAILED_FILES + 1))
            continue
        fi
        
        echo "  🔍 Проверка на HTML..."
        if ! check_not_html "$TEMP_DIR/${NAME}.yaml"; then
            echo "  ❌ Файл содержит HTML"
            FAILED_FILES=$((FAILED_FILES + 1))
            continue
        fi
        
        if ! grep -q "^payload:" "$TEMP_DIR/${NAME}.yaml"; then
            echo "  ❌ Отсутствует секция 'payload:' в YAML"
            FAILED_FILES=$((FAILED_FILES + 1))
            continue
        fi
        echo "  ✅ Структура YAML валидна"
        
        if [[ -f "$OUTPUT_DIR/${NAME}.mrs" ]]; then
            cp "$OUTPUT_DIR/${NAME}.mrs" "$TEMP_DIR/${NAME}.mrs.backup"
            echo "  💾 Бэкап сохранен"
        fi
        
        DOMAIN_COUNT=$(grep -c "^  - " "$TEMP_DIR/${NAME}.yaml" 2>/dev/null || echo "0")
        echo "  📊 Элементов в payload: ~$DOMAIN_COUNT"
        echo "  🔧 Конвертируем в MRS..."
        
        if ! "$TEMP_DIR/mihomo" convert-ruleset domain yaml "$TEMP_DIR/${NAME}.yaml" "$OUTPUT_DIR/${NAME}.mrs" 2>&1; then
            echo "  ❌ Ошибка конвертации!"
            if [[ -f "$TEMP_DIR/${NAME}.mrs.backup" ]]; then
                echo "  💾 Восстанавливаем предыдущую версию..."
                cp "$TEMP_DIR/${NAME}.mrs.backup" "$OUTPUT_DIR/${NAME}.mrs"
            fi
            FAILED_FILES=$((FAILED_FILES + 1))
            continue
        fi
        
        if ! check_file_size "$OUTPUT_DIR/${NAME}.mrs" 1; then
            echo "  ❌ Файл пустой"
            if [[ -f "$TEMP_DIR/${NAME}.mrs.backup" ]]; then
                cp "$TEMP_DIR/${NAME}.mrs.backup" "$OUTPUT_DIR/${NAME}.mrs"
            fi
            FAILED_FILES=$((FAILED_FILES + 1))
            continue
        fi
        
        echo "  ✅ $OUTPUT_DIR/${NAME}.mrs ($(du -h "$OUTPUT_DIR/${NAME}.mrs" | cut -f1))"
    done
fi

# ============================================
# GeoSite MRS — СКАЧИВАНИЕ
# ============================================
if [[ ${#GEOSITE_MRS[@]} -gt 0 ]]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🌐 GeoSite MRS (скачивание)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    for NAME in "${!GEOSITE_MRS[@]}"; do
        echo ""
        echo "📥 $NAME..."
        
        TOTAL_FILES=$((TOTAL_FILES + 1))
        
        if ! check_http_response "${GEOSITE_MRS[$NAME]}"; then
            echo "  ❌ HTTP ошибка"
            FAILED_FILES=$((FAILED_FILES + 1))
            continue
        fi
        
        if [[ -f "$OUTPUT_DIR/${NAME}.mrs" ]]; then
            cp "$OUTPUT_DIR/${NAME}.mrs" "$TEMP_DIR/${NAME}.mrs.backup"
        fi
        
        if curl -fL --retry 3 --retry-delay 2 "${GEOSITE_MRS[$NAME]}" -o "$OUTPUT_DIR/${NAME}.mrs" 2>/dev/null; then
            if check_file_size "$OUTPUT_DIR/${NAME}.mrs" 1; then
                echo "  ✅ $(du -h "$OUTPUT_DIR/${NAME}.mrs" | cut -f1)"
            else
                echo "  ❌ Файл пустой"
                if [[ -f "$TEMP_DIR/${NAME}.mrs.backup" ]]; then
                    cp "$TEMP_DIR/${NAME}.mrs.backup" "$OUTPUT_DIR/${NAME}.mrs"
                fi
                FAILED_FILES=$((FAILED_FILES + 1))
            fi
        else
            echo "  ❌ Не удалось скачать"
            if [[ -f "$TEMP_DIR/${NAME}.mrs.backup" ]]; then
                cp "$TEMP_DIR/${NAME}.mrs.backup" "$OUTPUT_DIR/${NAME}.mrs"
            fi
            FAILED_FILES=$((FAILED_FILES + 1))
        fi
    done
fi

# ============================================
# GeoIP TXT — КОНВЕРТАЦИЯ
# ============================================
if [[ ${#GEOIP_TXT[@]} -gt 0 ]]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🌍 GeoIP TXT → MRS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    for NAME in "${!GEOIP_TXT[@]}"; do
        SOURCE_URL="${GEOIP_TXT[$NAME]}"
        echo ""
        echo "🔄 $NAME"
        
        TOTAL_FILES=$((TOTAL_FILES + 1))
        
        echo "  🔍 Проверка источника..."
        if ! check_http_response "$SOURCE_URL"; then
            echo "  ❌ HTTP ошибка"
            FAILED_FILES=$((FAILED_FILES + 1))
            continue
        fi
        
        echo "  📥 Скачиваем..."
        curl -sL --retry 3 --retry-delay 2 "$SOURCE_URL" -o "$TEMP_DIR/${NAME}.txt"
        
        if ! check_file_size "$TEMP_DIR/${NAME}.txt" 1; then
            echo "  ❌ Файл не скачался"
            FAILED_FILES=$((FAILED_FILES + 1))
            continue
        fi
        
        if ! check_not_html "$TEMP_DIR/${NAME}.txt"; then
            echo "  ❌ Файл содержит HTML"
            FAILED_FILES=$((FAILED_FILES + 1))
            continue
        fi
        echo "  ✅ Целостность OK"
        
        LINE_COUNT=$(wc -l < "$TEMP_DIR/${NAME}.txt")
        echo "  📊 Строк: $LINE_COUNT"
        echo "  🔄 Обрабатываем и формируем YAML..."
        
        if [[ -f "$OUTPUT_DIR/${NAME}.mrs" ]]; then
            cp "$OUTPUT_DIR/${NAME}.mrs" "$TEMP_DIR/${NAME}.mrs.backup"
        fi
        
        {
            echo "payload:"
            awk '
            /^[[:space:]]*#/ { next }
            /^[[:space:]]*$/ { next }
            {
                # 1. Удаляем префиксы
                sub(/^(IPCIDR|IP-CIDR|SRC-IPCIDR|SRC-IP-CIDR|DST-IPCIDR|DST-IP-CIDR|IP|IP6|IP6-CIDR|GEOIP):/, "", $0)
                
                # 2. Чистим мусор и комментарии (КРИТИЧНО для custom.lst)
                sub(/[[:space:]]*#.*$/, "", $0)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)

                if ($0 == "") next

                # 3. Валидация IPv4 CIDR
                if ($0 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\/[0-9]+$/) {
                    split($0, parts, "[./]")
                    if (parts[5] >= 0 && parts[5] <= 32) {
                        printf "  - \x27%s\x27\n", $0
                        next
                    }
                }
                
                # 4. Валидация IPv6 CIDR
                if ($0 ~ /^([0-9a-fA-F:]+)\/[0-9]+$/) {
                    split($0, parts, "/")
                    if (parts[2] >= 0 && parts[2] <= 128) {
                        printf "  - \x27%s\x27\n", tolower($0)
                        next
                    }
                }
                
                # 5. Одиночный IPv4 -> добавляем /32
                if ($0 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) {
                    printf "  - \x27%s/32\x27\n", $0
                }
            }' "$TEMP_DIR/${NAME}.txt" | LC_ALL=C sort -u
        } > "$TEMP_DIR/${NAME}.yaml"
        
        IP_COUNT=$(grep -c "^  - " "$TEMP_DIR/${NAME}.yaml" 2>/dev/null || echo "0")
        
        if [[ "$IP_COUNT" -eq 0 ]]; then
            echo "  ⚠️ Нет IP для конвертации"
            FAILED_FILES=$((FAILED_FILES + 1))
            continue
        fi
        
        echo "  🔧 Конвертируем (IP: $IP_COUNT)..."
        
        if ! "$TEMP_DIR/mihomo" convert-ruleset ipcidr yaml "$TEMP_DIR/${NAME}.yaml" "$OUTPUT_DIR/${NAME}.mrs" 2>&1; then
            echo "  ❌ Ошибка конвертации!"
            if [[ -f "$TEMP_DIR/${NAME}.mrs.backup" ]]; then
                echo "  💾 Восстанавливаем предыдущую версию..."
                cp "$TEMP_DIR/${NAME}.mrs.backup" "$OUTPUT_DIR/${NAME}.mrs"
            fi
            FAILED_FILES=$((FAILED_FILES + 1))
            continue
        fi
        
        if ! check_file_size "$OUTPUT_DIR/${NAME}.mrs" 1; then
            echo "  ❌ Файл пустой"
            if [[ -f "$TEMP_DIR/${NAME}.mrs.backup" ]]; then
                cp "$TEMP_DIR/${NAME}.mrs.backup" "$OUTPUT_DIR/${NAME}.mrs"
            fi
            FAILED_FILES=$((FAILED_FILES + 1))
            continue
        fi
        
        echo "  ✅ $OUTPUT_DIR/${NAME}.mrs ($(du -h "$OUTPUT_DIR/${NAME}.mrs" | cut -f1))"
    done
fi

# ============================================
# GeoIP YAML — КОНВЕРТАЦИЯ
# ============================================
if [[ ${#GEOIP_YAML[@]} -gt 0 ]]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🌍 GeoIP YAML → MRS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    for NAME in "${!GEOIP_YAML[@]}"; do
        SOURCE_URL="${GEOIP_YAML[$NAME]}"
        echo ""
        echo "🔄 $NAME"
        
        TOTAL_FILES=$((TOTAL_FILES + 1))
        
        echo "  🔍 Проверка источника..."
        if ! check_http_response "$SOURCE_URL"; then
            echo "  ❌ HTTP ошибка"
            FAILED_FILES=$((FAILED_FILES + 1))
            continue
        fi
        
        echo "  📥 Скачиваем..."
        curl -sL --retry 3 --retry-delay 2 "$SOURCE_URL" -o "$TEMP_DIR/${NAME}.yaml"
        
        if ! check_file_size "$TEMP_DIR/${NAME}.yaml" 10; then
            echo "  ❌ Файл не скачался или слишком мал"
            FAILED_FILES=$((FAILED_FILES + 1))
            continue
        fi
        
        if ! check_not_html "$TEMP_DIR/${NAME}.yaml"; then
            echo "  ❌ Файл содержит HTML"
            FAILED_FILES=$((FAILED_FILES + 1))
            continue
        fi
        
        if ! grep -q "^payload:" "$TEMP_DIR/${NAME}.yaml"; then
            echo "  ❌ Отсутствует секция 'payload:' в YAML"
            FAILED_FILES=$((FAILED_FILES + 1))
            continue
        fi
        echo "  ✅ Структура YAML валидна"
        
        if [[ -f "$OUTPUT_DIR/${NAME}.mrs" ]]; then
            cp "$OUTPUT_DIR/${NAME}.mrs" "$TEMP_DIR/${NAME}.mrs.backup"
        fi
        
        IP_COUNT=$(grep -c "^  - " "$TEMP_DIR/${NAME}.yaml" 2>/dev/null || echo "0")
        echo "  📊 Элементов в payload: ~$IP_COUNT"
        echo "  🔧 Конвертируем в MRS..."
        
        if ! "$TEMP_DIR/mihomo" convert-ruleset ipcidr yaml "$TEMP_DIR/${NAME}.yaml" "$OUTPUT_DIR/${NAME}.mrs" 2>&1; then
            echo "  ❌ Ошибка конвертации!"
            if [[ -f "$TEMP_DIR/${NAME}.mrs.backup" ]]; then
                echo "  💾 Восстанавливаем предыдущую версию..."
                cp "$TEMP_DIR/${NAME}.mrs.backup" "$OUTPUT_DIR/${NAME}.mrs"
            fi
            FAILED_FILES=$((FAILED_FILES + 1))
            continue
        fi
        
        if ! check_file_size "$OUTPUT_DIR/${NAME}.mrs" 1; then
            echo "  ❌ Файл пустой"
            if [[ -f "$TEMP_DIR/${NAME}.mrs.backup" ]]; then
                cp "$TEMP_DIR/${NAME}.mrs.backup" "$OUTPUT_DIR/${NAME}.mrs"
            fi
            FAILED_FILES=$((FAILED_FILES + 1))
            continue
        fi
        
        echo "  ✅ $OUTPUT_DIR/${NAME}.mrs ($(du -h "$OUTPUT_DIR/${NAME}.mrs" | cut -f1))"
    done
fi

# ============================================
# GeoIP MRS — СКАЧИВАНИЕ
# ============================================
if [[ ${#GEOIP_MRS[@]} -gt 0 ]]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🌍 GeoIP MRS (скачивание)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    for NAME in "${!GEOIP_MRS[@]}"; do
        echo ""
        echo "📥 $NAME..."
        
        TOTAL_FILES=$((TOTAL_FILES + 1))
        
        if ! check_http_response "${GEOIP_MRS[$NAME]}"; then
            echo "  ❌ HTTP ошибка"
            FAILED_FILES=$((FAILED_FILES + 1))
            continue
        fi
        
        if [[ -f "$OUTPUT_DIR/${NAME}.mrs" ]]; then
            cp "$OUTPUT_DIR/${NAME}.mrs" "$TEMP_DIR/${NAME}.mrs.backup"
        fi
        
        if curl -fL --retry 3 --retry-delay 2 "${GEOIP_MRS[$NAME]}" -o "$OUTPUT_DIR/${NAME}.mrs" 2>/dev/null; then
            if check_file_size "$OUTPUT_DIR/${NAME}.mrs" 1; then
                echo "  ✅ $(du -h "$OUTPUT_DIR/${NAME}.mrs" | cut -f1)"
            else
                echo "  ❌ Файл пустой"
                if [[ -f "$TEMP_DIR/${NAME}.mrs.backup" ]]; then
                    cp "$TEMP_DIR/${NAME}.mrs.backup" "$OUTPUT_DIR/${NAME}.mrs"
                fi
                FAILED_FILES=$((FAILED_FILES + 1))
            fi
        else
            echo "  ❌ Не удалось скачать"
            if [[ -f "$TEMP_DIR/${NAME}.mrs.backup" ]]; then
                cp "$TEMP_DIR/${NAME}.mrs.backup" "$OUTPUT_DIR/${NAME}.mrs"
            fi
            FAILED_FILES=$((FAILED_FILES + 1))
        fi
    done
fi

# ============================================
# ФИНАЛЬНЫЙ ОТЧЕТ
# ============================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Конвертация завершена!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
[[ -n "${GITHUB_RUN_NUMBER:-}" ]] && echo "📦 Build #${GITHUB_RUN_NUMBER}"
echo "🕐 $(TZ=Europe/Moscow date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""
echo "📊 Статистика:"
echo "   Всего файлов: $TOTAL_FILES"
echo "   Ошибок: $FAILED_FILES"
echo "   Успешно: $((TOTAL_FILES - FAILED_FILES))"
echo ""
echo "📁 Файлы:"
ls -lh "$OUTPUT_DIR"/*.mrs 2>/dev/null | awk '{print "   • " $9 " (" $5 ")"}' || echo "  (нет файлов)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "$FAILED_FILES" -gt 0 ]]; then
    echo ""
    echo "⚠️ Внимание: $FAILED_FILES файл(ов) не обработано!"
    exit 1
fi

exit 0
