#!/bin/bash
set -euo pipefail

OUTPUT_DIR="output"
TEMP_DIR=$(mktemp -d)
CACHE_DIR="$OUTPUT_DIR/.cache"

# Очистка TEMP_DIR при любом выходе (успех/ошибка)
trap "rm -rf $TEMP_DIR" EXIT

mkdir -p "$CACHE_DIR"

# ============================================
# ФУНКЦИИ ДЛЯ ОЧИСТКИ И ВАЛИДАЦИИ
# ============================================

parse_domain_fast() {
    # Убираем префиксы (case-insensitive через GNU sed)
    sed -E 's/^(DOMAIN|DOMAIN-SUFFIX|DOMAIN-KEYWORD|FULL|HOST|KEYWORD|REGEXP|REGEX|HOST-SUFFIX|HOST-KEYWORD|HOST-REGEX|GEOSITE|GEOIP|AND|OR|NOT|URL-REGEX|URL-REGEXP|USER-AGENT|SCRIPT|PROCESS-NAME|PROCESS-PATH|PORT|DST-PORT|SRC-PORT|IN-PORT|NETWORK|IN-NAME|IN-TYPE)://I' | \
    # Убираем +. *. в начале
    sed -E 's/^(\+\.?|\*\.?|\.+)//' | \
    # Убираем протоколы
    sed -E 's|^https?://||' | \
    # Убираем @ и всё до него (email)
    sed -E 's/^[^@]*@//' | \
    # Убираем порты
    sed -E 's/:[0-9]+$//' | \
    # Убираем пути, query, fragment
    sed -E 's|/.*$||; s/\?.*$//; s/#.*$//' | \
    # Убираем запятые и всё после них (Clash format: domain,DIRECT)
    sed 's/,.*$//' | \
    # Убираем комментарии в конце
    sed 's/[[:space:]]*#.*$//' | \
    # Убираем двойные точки
    sed 's/\.\././g' | \
    # Убираем точки в конце
    sed 's/\.+$//' | \
    # Убираем пробелы в начале/конце
    sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

parse_ipcidr_fast() {
    # Убираем префиксы
    sed -E 's/^(IPCIDR|IP-CIDR|SRC-IPCIDR|SRC-IP-CIDR|DST-IPCIDR|DST-IP-CIDR|IP|IP6|IP6-CIDR|GEOIP)://I' | \
    # Убираем запятые и всё после них
    sed 's/,.*$//' | \
    # Убираем комментарии
    sed 's/[[:space:]]*#.*$//' | \
    # Убираем пробелы
    sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# ============================================
# ФУНКЦИИ ПРОВЕРКИ
# ============================================

check_http_response() {
    local url="$1"
    local response
    response=$(curl -sIL --retry 2 --retry-delay 1 "$url" -w "%{http_code}" -o /dev/null 2>/dev/null)
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

check_cache() {
    local name="$1"
    local url="$2"
    local cache_file="$CACHE_DIR/${name}.hash"
    
    local current_hash
    current_hash=$(curl -sIL --retry 2 --retry-delay 1 "$url" 2>/dev/null | grep -iE '^(etag|last-modified):' | tr -d '\r' | md5sum | cut -d' ' -f1)
    
    if [[ -z "$current_hash" ]]; then
        current_hash=$(md5sum <<< "$url" | cut -d' ' -f1)
    fi
    
    if [[ -f "$cache_file" ]]; then
        local cached_hash
        cached_hash=$(cat "$cache_file")
        if [[ "$current_hash" == "$cached_hash" ]] && [[ -f "$OUTPUT_DIR/${name}.mrs" ]]; then
            return 0
        fi
    fi
    
    echo "$current_hash" > "$cache_file"
    return 1
}

# ============================================
# МАССИВЫ
# ============================================

declare -A GEOSITE_TXT=(
    ["category-ads"]="https://github.com/Sn1pp1/mygeofiles/raw/refs/heads/main/files/category-ads.txt"
    ["ru-blocklist"]="https://github.com/Sn1pp1/mygeofiles/raw/refs/heads/main/files/ru-blocklist.txt"
)

declare -A GEOSITE_MRS=(
    ["private"]="https://github.com/MetaCubeX/meta-rules-dat/raw/refs/heads/meta/geo/geosite/private.mrs"
    ["youtube"]="https://github.com/MetaCubeX/meta-rules-dat/raw/refs/heads/meta/geo/geosite/youtube.mrs"
)

declare -A GEOSITE_YAML=(
)

declare -A GEOIP_TXT=(
    ["ru-blocklist-ip"]="https://github.com/Sn1pp1/mygeofiles/raw/refs/heads/main/files/ru-blocklist-ip.txt"
)

declare -A GEOIP_MRS=(
    ["private-ip"]="https://github.com/MetaCubeX/meta-rules-dat/raw/refs/heads/meta/geo/geoip/private.mrs"
)

declare -A GEOIP_YAML=(
)

# ============================================
# СКАЧИВАНИЕ MIHOMO
# ============================================

echo "⚙️ Скачиваем mihomo..."
LATEST_JSON=$(curl -sL --retry 3 --retry-delay 2 https://api.github.com/repos/MetaCubeX/mihomo/releases/latest)
MIHOMO_VERSION=$(echo "$LATEST_JSON" | grep '"tag_name"' | cut -d'"' -f4)
echo "📦 Версия: ${MIHOMO_VERSION}"

echo "$LATEST_JSON" | grep '"browser_download_url"' | cut -d'"' -f4 > "$TEMP_DIR/urls.txt"
MIHOMO_URL=$(grep 'mihomo-linux-amd64-compatible.*\.gz' "$TEMP_DIR/urls.txt" | head -1)
[[ -z "$MIHOMO_URL" ]] && MIHOMO_URL=$(grep 'mihomo-linux-amd64-v.*\.gz' "$TEMP_DIR/urls.txt" | head -1)
[[ -z "$MIHOMO_URL" ]] && MIHOMO_URL=$(grep 'mihomo-linux-amd64.*\.gz' "$TEMP_DIR/urls.txt" | grep -v '\.pkg\.tar' | head -1)

if [[ -z "$MIHOMO_URL" ]]; then
    echo "❌ Не удалось найти mihomo"
    exit 1
fi

curl -fL --retry 3 --retry-delay 2 "$MIHOMO_URL" -o "$TEMP_DIR/mihomo.gz"
gunzip -f "$TEMP_DIR/mihomo.gz"
chmod +x "$TEMP_DIR/mihomo"

echo "✅ Mihomo готов"
mkdir -p "$OUTPUT_DIR"

TOTAL_FILES=0
CACHED_FILES=0
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
        
        if check_cache "$NAME" "$SOURCE_URL"; then
            echo "  ✅ Без изменений (кэш)"
            CACHED_FILES=$((CACHED_FILES + 1))
            continue
        fi
        
        echo "  📥 Скачиваем..."
        curl -sL --retry 3 --retry-delay 2 "$SOURCE_URL" -o "$TEMP_DIR/${NAME}.txt"
        
        if ! check_file_size "$TEMP_DIR/${NAME}.txt" 1; then
            echo "  ❌ Файл не скачался"
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
        echo "  🔄 Обрабатываем..."
        
        if [[ -f "$OUTPUT_DIR/${NAME}.mrs" ]]; then
            cp "$OUTPUT_DIR/${NAME}.mrs" "$TEMP_DIR/${NAME}.mrs.backup"
            echo "  💾 Бэкап сохранен"
        fi
        
        {
            echo "payload:"
            
            cat "$TEMP_DIR/${NAME}.txt" | \
                grep -v '^[[:space:]]*#' | \
                grep -v '^[[:space:]]*$' | \
                parse_domain_fast | \
                grep -v '^$' | \
                # Отсеиваем IP-адреса (не должны быть в geosite)
                grep -vE '^([0-9]{1,3}\.){3}[0-9]{1,3}$' | \
                # Отсеиваем IPv6
                grep -vE '^[0-9a-fA-F:]+$' | \
                # Отсеиваем строки с пробелами (мусор)
                grep -v ' ' | \
                # Отсеиваем пустые после обработки
                grep -E '^[a-zA-Z0-9._-]+\.[a-zA-Z0-9._-]+$' | \
                while IFS= read -r domain; do
                    if [[ -n "$domain" ]]; then
                        echo "  - '+.$domain'"
                    fi
                done
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
        
        if check_cache "$NAME" "$SOURCE_URL"; then
            echo "  ✅ Без изменений (кэш)"
            CACHED_FILES=$((CACHED_FILES + 1))
            continue
        fi
        
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
        
        if check_cache "$NAME" "${GEOSITE_MRS[$NAME]}"; then
            echo "  ✅ Без изменений (кэш)"
            CACHED_FILES=$((CACHED_FILES + 1))
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
        
        if ! check_http_response "$SOURCE_URL"; then
            echo "  ❌ HTTP ошибка"
            FAILED_FILES=$((FAILED_FILES + 1))
            continue
        fi
        
        if check_cache "$NAME" "$SOURCE_URL"; then
            echo "  ✅ Без изменений (кэш)"
            CACHED_FILES=$((CACHED_FILES + 1))
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
        echo "  🔄 Обрабатываем..."
        
        if [[ -f "$OUTPUT_DIR/${NAME}.mrs" ]]; then
            cp "$OUTPUT_DIR/${NAME}.mrs" "$TEMP_DIR/${NAME}.mrs.backup"
        fi
        
        {
            echo "payload:"
            
            cat "$TEMP_DIR/${NAME}.txt" | \
                grep -v '^[[:space:]]*#' | \
                grep -v '^[[:space:]]*$' | \
                parse_ipcidr_fast | \
                grep -v '^$' | \
                # Только строки с / (CIDR формат)
                grep -E '/[0-9]+$' | \
                # Отсеиваем домены (не должны быть в geoip)
                grep -vE '[a-zA-Z]' | \
                while IFS= read -r ip; do
                    if [[ -n "$ip" ]]; then
                        echo "  - '$ip'"
                    fi
                done
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
        
        if ! check_http_response "$SOURCE_URL"; then
            echo "  ❌ HTTP ошибка"
            FAILED_FILES=$((FAILED_FILES + 1))
            continue
        fi
        
        if check_cache "$NAME" "$SOURCE_URL"; then
            echo "  ✅ Без изменений (кэш)"
            CACHED_FILES=$((CACHED_FILES + 1))
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
        
        if check_cache "$NAME" "${GEOIP_MRS[$NAME]}"; then
            echo "  ✅ Без изменений (кэш)"
            CACHED_FILES=$((CACHED_FILES + 1))
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
echo "   В кэше (без изменений): $CACHED_FILES"
echo "   Ошибок: $FAILED_FILES"
echo "   Успешно: $((TOTAL_FILES - FAILED_FILES - CACHED_FILES))"
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
