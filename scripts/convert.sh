#!/bin/bash
set -e

OUTPUT_DIR="output"
TEMP_DIR=$(mktemp -d)
CACHE_DIR="$OUTPUT_DIR/.cache"

mkdir -p "$CACHE_DIR"

# ============================================
# ФУНКЦИИ ДЛЯ ОЧИСТКИ ПРЕФИКСОВ
# ============================================

parse_domain_fast() {
    sed -E 's/^(DOMAIN|DOMAIN-SUFFIX|DOMAIN-KEYWORD|FULL|HOST|KEYWORD|REGEXP|REGEX|HOST-SUFFIX|HOST-KEYWORD|HOST-REGEX|GEOSITE|GEOIP|AND|OR|NOT|URL-REGEX|URL-REGEXP|USER-AGENT|SCRIPT)://gi' | \
    sed -E 's/^(\+\.|\*\.)/ /' | \
    sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

parse_ipcidr_fast() {
    sed -E 's/^(IPCIDR|IP-CIDR|SRC-IPCIDR|SRC-IP-CIDR|DST-IPCIDR|DST-IP-CIDR|IP|IP6|IP6-CIDR|GEOIP)://gi' | \
    sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# ============================================
# ФУНКЦИИ ПРОВЕРКИ
# ============================================

check_http_response() {
    local url="$1"
    local response=$(curl -sIL "$url" -w "%{http_code}" -o /dev/null)
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
    
    local size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo "0")
    [[ "$size" -ge "$min_size" ]]
}

check_cache() {
    local name="$1"
    local url="$2"
    local cache_file="$CACHE_DIR/${name}.hash"
    
    local current_hash=$(curl -sIL "$url" 2>/dev/null | grep -iE '^(etag|last-modified):' | tr -d '\r' | md5sum | cut -d' ' -f1)
    
    if [[ -z "$current_hash" ]]; then
        current_hash=$(md5sum <<< "$url" | cut -d' ' -f1)
    fi
    
    if [[ -f "$cache_file" ]]; then
        local cached_hash=$(cat "$cache_file")
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
    ["ru-blocked"]="https://raw.githubusercontent.com/runetfreedom/russia-blocked-geosite/release/ru-blocked.txt"
    ["refilter"]="https://raw.githubusercontent.com/runetfreedom/russia-blocked-geosite/release/refilter.txt"
    ["domain-list"]="https://github.com/Sn1pp1/mygeofiles/raw/refs/heads/main/files/domain-list.txt"
)

declare -A GEOSITE_MRS=(
    ["category-ads"]="https://github.com/hydraponique/roscomvpn-geosite/raw/refs/heads/master/release/mihomo/category-ads.mrs"
    ["telegram"]="https://github.com/MetaCubeX/meta-rules-dat/raw/refs/heads/meta/geo/geosite/telegram.mrs"
    ["meta"]="https://github.com/MetaCubeX/meta-rules-dat/raw/refs/heads/meta/geo/geosite/meta.mrs"
    ["discord"]="https://github.com/MetaCubeX/meta-rules-dat/raw/refs/heads/meta/geo/geosite/discord.mrs"
    ["youtube"]="https://github.com/MetaCubeX/meta-rules-dat/raw/refs/heads/meta/geo/geosite/youtube.mrs"
)

declare -A GEOIP_TXT=()

declare -A GEOIP_MRS=(
    ["ru-blocked-ip"]="https://raw.githubusercontent.com/runetfreedom/russia-blocked-geoip/release/mrs/ru-blocked.mrs"
    ["ru-blocked-community-ip"]="https://raw.githubusercontent.com/runetfreedom/russia-blocked-geoip/release/mrs/ru-blocked-community.mrs"
    ["refilter-ip"]="https://raw.githubusercontent.com/runetfreedom/russia-blocked-geoip/release/mrs/re-filter.mrs"
    ["telegram-ip"]="https://github.com/MetaCubeX/meta-rules-dat/raw/refs/heads/meta/geo/geoip/telegram.mrs"
    ["meta-ip"]="https://github.com/itdoginfo/allow-domains/releases/latest/download/meta_ipcidr.mrs"
    ["discord-ip"]="https://github.com/itdoginfo/allow-domains/releases/latest/download/discord_ipcidr.mrs"
)

# ============================================
# СКАЧИВАНИЕ MIHOMO
# ============================================

echo "⚙️ Скачиваем mihomo..."
LATEST_JSON=$(curl -sL https://api.github.com/repos/MetaCubeX/mihomo/releases/latest)
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

curl -fL "$MIHOMO_URL" -o "$TEMP_DIR/mihomo.gz"
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
        
        ((TOTAL_FILES++)) || true
        
        echo "  🔍 Проверка источника..."
        if ! check_http_response "$SOURCE_URL"; then
            echo "  ❌ HTTP ошибка"
            ((FAILED_FILES++)) || true
            continue
        fi
        echo "  ✅ HTTP OK"
        
        if check_cache "$NAME" "$SOURCE_URL"; then
            echo "  ✅ Без изменений (кэш)"
            ((CACHED_FILES++)) || true
            continue
        fi
        
        echo "  📥 Скачиваем..."
        curl -sL "$SOURCE_URL" -o "$TEMP_DIR/${NAME}.txt"
        
        if ! check_file_size "$TEMP_DIR/${NAME}.txt" 50; then
            echo "  ❌ Файл слишком маленький"
            ((FAILED_FILES++)) || true
            continue
        fi
        
        echo "  🔍 Проверка на HTML..."
        if ! check_not_html "$TEMP_DIR/${NAME}.txt"; then
            echo "  ❌ Файл содержит HTML"
            ((FAILED_FILES++)) || true
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
                grep -v '^regexp:' | \
                grep -v '^regex:' | \
                grep -v '^keyword:' | \
                grep -v '^domain-keyword:' | \
                grep -v '^host-keyword:' | \
                grep -v '^url-regex:' | \
                grep -v '^user-agent:' | \
                grep -v '^script:' | \
                grep -v '^and:' | \
                grep -v '^or:' | \
                grep -v '^not:' | \
                grep -v '^process-name:' | \
                grep -v '^process-path:' | \
                grep -v '^port:' | \
                grep -v '^dst-port:' | \
                grep -v '^src-port:' | \
                grep -v '^network:' | \
                grep -v '^in-port:' | \
                grep -v '^in-name:' | \
                grep -v '^in-type:' | \
                while IFS= read -r domain; do
                    if [[ -n "$domain" && ! "$domain" =~ [[:space:]] ]]; then
                        echo "  - '+.$domain'"
                    fi
                done
        } > "$TEMP_DIR/${NAME}.yaml"
        
        DOMAIN_COUNT=$(grep -c "^  - " "$TEMP_DIR/${NAME}.yaml" 2>/dev/null || echo "0")
        
        if [[ "$DOMAIN_COUNT" -eq 0 ]]; then
            echo "  ⚠️ Нет доменов для конвертации"
            ((FAILED_FILES++)) || true
            continue
        fi
        
        echo "  🔧 Конвертируем в MRS (доменов: $DOMAIN_COUNT)..."
        
        if ! "$TEMP_DIR/mihomo" convert-ruleset domain yaml "$TEMP_DIR/${NAME}.yaml" "$OUTPUT_DIR/${NAME}.mrs" 2>&1; then
            echo "  ❌ Ошибка конвертации!"
            if [[ -f "$TEMP_DIR/${NAME}.mrs.backup" ]]; then
                echo "  💾 Восстанавливаем предыдущую версию..."
                cp "$TEMP_DIR/${NAME}.mrs.backup" "$OUTPUT_DIR/${NAME}.mrs"
            fi
            ((FAILED_FILES++)) || true
            continue
        fi
        
        # Простая валидация - только размер
        if ! check_file_size "$OUTPUT_DIR/${NAME}.mrs" 50; then
            echo "  ❌ Файл слишком маленький"
            if [[ -f "$TEMP_DIR/${NAME}.mrs.backup" ]]; then
                cp "$TEMP_DIR/${NAME}.mrs.backup" "$OUTPUT_DIR/${NAME}.mrs"
            fi
            ((FAILED_FILES++)) || true
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
        
        ((TOTAL_FILES++)) || true
        
        if ! check_http_response "${GEOSITE_MRS[$NAME]}"; then
            echo "  ❌ HTTP ошибка"
            ((FAILED_FILES++)) || true
            continue
        fi
        
        if check_cache "$NAME" "${GEOSITE_MRS[$NAME]}"; then
            echo "  ✅ Без изменений (кэш)"
            ((CACHED_FILES++)) || true
            continue
        fi
        
        if [[ -f "$OUTPUT_DIR/${NAME}.mrs" ]]; then
            cp "$OUTPUT_DIR/${NAME}.mrs" "$TEMP_DIR/${NAME}.mrs.backup"
        fi
        
        if curl -fL "${GEOSITE_MRS[$NAME]}" -o "$OUTPUT_DIR/${NAME}.mrs" 2>/dev/null; then
            if check_file_size "$OUTPUT_DIR/${NAME}.mrs" 50; then
                echo "  ✅ $(du -h "$OUTPUT_DIR/${NAME}.mrs" | cut -f1)"
            else
                echo "  ❌ Файл слишком маленький"
                if [[ -f "$TEMP_DIR/${NAME}.mrs.backup" ]]; then
                    cp "$TEMP_DIR/${NAME}.mrs.backup" "$OUTPUT_DIR/${NAME}.mrs"
                fi
                ((FAILED_FILES++)) || true
            fi
        else
            echo "  ❌ Не удалось скачать"
            if [[ -f "$TEMP_DIR/${NAME}.mrs.backup" ]]; then
                cp "$TEMP_DIR/${NAME}.mrs.backup" "$OUTPUT_DIR/${NAME}.mrs"
            fi
            ((FAILED_FILES++)) || true
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
        
        ((TOTAL_FILES++)) || true
        
        if ! check_http_response "$SOURCE_URL"; then
            echo "  ❌ HTTP ошибка"
            ((FAILED_FILES++)) || true
            continue
        fi
        
        if check_cache "$NAME" "$SOURCE_URL"; then
            echo "  ✅ Без изменений (кэш)"
            ((CACHED_FILES++)) || true
            continue
        fi
        
        echo "  📥 Скачиваем..."
        curl -sL "$SOURCE_URL" -o "$TEMP_DIR/${NAME}.txt"
        
        if ! check_file_size "$TEMP_DIR/${NAME}.txt" 50; then
            echo "  ❌ Файл слишком маленький"
            ((FAILED_FILES++)) || true
            continue
        fi
        
        if ! check_not_html "$TEMP_DIR/${NAME}.txt"; then
            echo "  ❌ Файл содержит HTML"
            ((FAILED_FILES++)) || true
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
                grep -v '^geoip:' | \
                grep -v '^process-name:' | \
                grep -v '^process-path:' | \
                grep -v '^port:' | \
                grep -v '^network:' | \
                while IFS= read -r ip; do
                    if [[ -n "$ip" && ! "$ip" =~ [[:space:]] ]]; then
                        echo "  - '$ip'"
                    fi
                done
        } > "$TEMP_DIR/${NAME}.yaml"
        
        IP_COUNT=$(grep -c "^  - " "$TEMP_DIR/${NAME}.yaml" 2>/dev/null || echo "0")
        
        if [[ "$IP_COUNT" -eq 0 ]]; then
            echo "  ⚠️ Нет IP для конвертации"
            ((FAILED_FILES++)) || true
            continue
        fi
        
        echo "  🔧 Конвертируем (IP: $IP_COUNT)..."
        
        if ! "$TEMP_DIR/mihomo" convert-ruleset ipcidr yaml "$TEMP_DIR/${NAME}.yaml" "$OUTPUT_DIR/${NAME}.mrs" 2>&1; then
            echo "  ❌ Ошибка конвертации!"
            if [[ -f "$TEMP_DIR/${NAME}.mrs.backup" ]]; then
                cp "$TEMP_DIR/${NAME}.mrs.backup" "$OUTPUT_DIR/${NAME}.mrs"
            fi
            ((FAILED_FILES++)) || true
            continue
        fi
        
        if ! check_file_size "$OUTPUT_DIR/${NAME}.mrs" 50; then
            echo "  ❌ Файл слишком маленький"
            if [[ -f "$TEMP_DIR/${NAME}.mrs.backup" ]]; then
                cp "$TEMP_DIR/${NAME}.mrs.backup" "$OUTPUT_DIR/${NAME}.mrs"
            fi
            ((FAILED_FILES++)) || true
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
        
        ((TOTAL_FILES++)) || true
        
        if ! check_http_response "${GEOIP_MRS[$NAME]}"; then
            echo "  ❌ HTTP ошибка"
            ((FAILED_FILES++)) || true
            continue
        fi
        
        if check_cache "$NAME" "${GEOIP_MRS[$NAME]}"; then
            echo "  ✅ Без изменений (кэш)"
            ((CACHED_FILES++)) || true
            continue
        fi
        
        if [[ -f "$OUTPUT_DIR/${NAME}.mrs" ]]; then
            cp "$OUTPUT_DIR/${NAME}.mrs" "$TEMP_DIR/${NAME}.mrs.backup"
        fi
        
        if curl -fL "${GEOIP_MRS[$NAME]}" -o "$OUTPUT_DIR/${NAME}.mrs" 2>/dev/null; then
            if check_file_size "$OUTPUT_DIR/${NAME}.mrs" 50; then
                echo "  ✅ $(du -h "$OUTPUT_DIR/${NAME}.mrs" | cut -f1)"
            else
                echo "  ❌ Файл слишком маленький"
                if [[ -f "$TEMP_DIR/${NAME}.mrs.backup" ]]; then
                    cp "$TEMP_DIR/${NAME}.mrs.backup" "$OUTPUT_DIR/${NAME}.mrs"
                fi
                ((FAILED_FILES++)) || true
            fi
        else
            echo "  ❌ Не удалось скачать"
            if [[ -f "$TEMP_DIR/${NAME}.mrs.backup" ]]; then
                cp "$TEMP_DIR/${NAME}.mrs.backup" "$OUTPUT_DIR/${NAME}.mrs"
            fi
            ((FAILED_FILES++)) || true
        fi
    done
fi

rm -rf "$TEMP_DIR"

# ============================================
# ФИНАЛЬНЫЙ ОТЧЕТ
# ============================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Конвертация завершена!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
[[ -n "$GITHUB_RUN_NUMBER" ]] && echo "📦 Build #${GITHUB_RUN_NUMBER}"
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
