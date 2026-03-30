#!/bin/bash
set -e

OUTPUT_DIR="output"
TEMP_DIR=$(mktemp -d)
CACHE_DIR="$OUTPUT_DIR/.cache"

# Создаем директорию для кэша
mkdir -p "$CACHE_DIR"

# ============================================
# ФУНКЦИИ ДЛЯ ОЧИСТКИ ВСЕХ ВОЗМОЖНЫХ ПРЕФИКСОВ
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
# ФУНКЦИИ ПРОВЕРКИ И ВАЛИДАЦИИ
# ============================================

# Проверка HTTP ответа
check_http_response() {
    local url="$1"
    local response=$(curl -sIL "$url" -w "%{http_code}" -o /dev/null)
    [[ "$response" == "200" ]]
}

# Проверка что файл не HTML (частая ошибка GitHub)
check_not_html() {
    local file="$1"
    ! head -c 500 "$file" | grep -qi '<!DOCTYPE\|<html\|<head\|<body'
}

# Проверка размера файла
check_file_size() {
    local file="$1"
    local min_size="${2:-100}"
    
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    
    local size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo "0")
    [[ "$size" -ge "$min_size" ]]
}

# Проверка целостности TXT (домены)
check_txt_integrity_domain() {
    local file="$1"
    local min_lines="${2:-10}"
    
    # Проверка количества строк
    local line_count=$(wc -l < "$file")
    if [[ "$line_count" -lt "$min_lines" ]]; then
        echo "    ⚠️ Слишком мало строк: $line_count (минимум: $min_lines)"
        return 1
    fi
    
    # Проверка что это не HTML
    if ! check_not_html "$file"; then
        echo "    ⚠️ Файл содержит HTML (возможно ошибка ссылки)"
        return 1
    fi
    
    # Проверка что есть доменные имена (хотя бы 50% строк содержат точки)
    local valid_lines=$(grep -c '\.' "$file" 2>/dev/null || echo "0")
    local valid_percent=$((valid_lines * 100 / line_count))
    
    if [[ "$valid_percent" -lt 50 ]]; then
        echo "    ⚠️ Мало доменов: $valid_percent% (минимум: 50%)"
        return 1
    fi
    
    # Проверка на явные ошибки
    if head -20 "$file" | grep -qi '404\|not found\|access denied'; then
        echo "    ⚠️ Файл содержит ошибки доступа"
        return 1
    fi
    
    return 0
}

# Проверка целостности TXT (IP)
check_txt_integrity_ip() {
    local file="$1"
    local min_lines="${2:-5}"
    
    local line_count=$(wc -l < "$file")
    if [[ "$line_count" -lt "$min_lines" ]]; then
        echo "    ⚠️ Слишком мало строк: $line_count"
        return 1
    fi
    
    if ! check_not_html "$file"; then
        echo "    ⚠️ Файл содержит HTML"
        return 1
    fi
    
    # Проверка что есть IP-адреса (хотя бы 30% строк содержат цифры и точки/слэши)
    local valid_lines=$(grep -cE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$file" 2>/dev/null || echo "0")
    local valid_percent=$((valid_lines * 100 / line_count))
    
    if [[ "$valid_percent" -lt 30 ]]; then
        echo "    ⚠️ Мало IP-адресов: $valid_percent% (минимум: 30%)"
        return 1
    fi
    
    return 0
}

# Проверка целостности MRS
check_mrs_integrity() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        echo "    ⚠️ Файл не существует"
        return 1
    fi
    
    local size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo "0")
    if [[ "$size" -lt 100 ]]; then
        echo "    ⚠️ Файл слишком маленький: $size байт"
        return 1
    fi
    
    # Проверка что это бинарный файл (MRS имеет специфичную структуру)
    # MRS файлы начинаются с бинарных данных, не с текста
    if head -c 10 "$file" | grep -q '^[[:print:]]*$'; then
        echo "    ⚠️ Файл текстовый, а не бинарный MRS"
        return 1
    fi
    
    return 0
}

# Проверка хэша (кэширование)
check_cache() {
    local name="$1"
    local url="$2"
    local cache_file="$CACHE_DIR/${name}.hash"
    
    # Получаем хэш текущего URL (ETag или последний модифицированный)
    local current_hash=$(curl -sIL "$url" 2>/dev/null | grep -iE '^(etag|last-modified):' | tr -d '\r' | md5sum | cut -d' ' -f1)
    
    if [[ -z "$current_hash" ]]; then
        current_hash=$(md5sum <<< "$url" | cut -d' ' -f1)
    fi
    
    if [[ -f "$cache_file" ]]; then
        local cached_hash=$(cat "$cache_file")
        if [[ "$current_hash" == "$cached_hash" ]] && [[ -f "$OUTPUT_DIR/${name}.mrs" ]]; then
            return 0  # Есть в кэше
        fi
    fi
    
    # Сохраняем новый хэш
    echo "$current_hash" > "$cache_file"
    return 1  # Нет в кэше
}

# Валидация MRS файла через mihomo
validate_mrs() {
    local mihomo="$1"
    local mrs_file="$2"
    
    if [[ ! -f "$mrs_file" ]] || [[ ! -s "$mrs_file" ]]; then
        return 1
    fi
    
    if ! check_mrs_integrity "$mrs_file"; then
        return 1
    fi
    
    return 0
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
)

declare -A GEOIP_TXT=()

declare -A GEOIP_MRS=(
    ["ru-blocked-ip"]="https://raw.githubusercontent.com/runetfreedom/russia-blocked-geoip/release/mrs/ru-blocked.mrs"
    ["ru-blocked-community-ip"]="https://raw.githubusercontent.com/runetfreedom/russia-blocked-geoip/release/mrs/ru-blocked-community.mrs"
    ["refilter-ip"]="https://raw.githubusercontent.com/runetfreedom/russia-blocked-geoip/release/mrs/re-filter.mrs"
    ["discord-ip"]="https://github.com/itdoginfo/allow-domains/releases/latest/download/discord_ipcidr.mrs"
    ["meta-ip"]="https://github.com/itdoginfo/allow-domains/releases/latest/download/meta_ipcidr.mrs"
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

# Счетчики
TOTAL_FILES=0
CACHED_FILES=0
FAILED_FILES=0
SKIPPED_FILES=0

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
        
        # Проверка HTTP ответа
        echo "  🔍 Проверка источника..."
        if ! check_http_response "$SOURCE_URL"; then
            echo "  ❌ HTTP ошибка (не 200 OK)"
            ((FAILED_FILES++)) || true
            continue
        fi
        echo "  ✅ HTTP OK"
        
        # Проверка кэша
        if check_cache "$NAME" "$SOURCE_URL"; then
            echo "  ✅ Без изменений (кэш)"
            ((CACHED_FILES++)) || true
            continue
        fi
        
        echo "  📥 Скачиваем..."
        curl -sL "$SOURCE_URL" -o "$TEMP_DIR/${NAME}.txt"
        
        # Проверка размера
        if ! check_file_size "$TEMP_DIR/${NAME}.txt" 100; then
            echo "  ❌ Файл слишком маленький или не скачался"
            ((FAILED_FILES++)) || true
            continue
        fi
        
        # Проверка целостности TXT
        echo "  🔍 Проверка целостности..."
        if ! check_txt_integrity_domain "$TEMP_DIR/${NAME}.txt" 10; then
            echo "  ❌ Файл не прошел проверку целостности"
            ((FAILED_FILES++)) || true
            continue
        fi
        echo "  ✅ Целостность OK"
        
        LINE_COUNT=$(wc -l < "$TEMP_DIR/${NAME}.txt")
        echo "  📊 Строк в исходнике: $LINE_COUNT"
        echo "  🔄 Обрабатываем..."
        
        # Сохраняем предыдущую версию
        if [[ -f "$OUTPUT_DIR/${NAME}.mrs" ]]; then
            cp "$OUTPUT_DIR/${NAME}.mrs" "$TEMP_DIR/${NAME}.mrs.backup"
            echo "  💾 Бэкап сохранен"
        fi
        
        # Создаем YAML
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
        
        # Конвертация
        if ! "$TEMP_DIR/mihomo" convert-ruleset domain yaml "$TEMP_DIR/${NAME}.yaml" "$OUTPUT_DIR/${NAME}.mrs" 2>&1; then
            echo "  ❌ Ошибка конвертации!"
            if [[ -f "$TEMP_DIR/${NAME}.mrs.backup" ]]; then
                echo "  💾 Восстанавливаем предыдущую версию..."
                cp "$TEMP_DIR/${NAME}.mrs.backup" "$OUTPUT_DIR/${NAME}.mrs"
            fi
            ((FAILED_FILES++)) || true
            continue
        fi
        
        # Валидация
        if ! validate_mrs "$TEMP_DIR/mihomo" "$OUTPUT_DIR/${NAME}.mrs"; then
            echo "  ❌ Файл не прошел валидацию!"
            if [[ -f "$TEMP_DIR/${NAME}.mrs.backup" ]]; then
                echo "  💾 Восстанавливаем предыдущую версию..."
                cp "$TEMP_DIR/${NAME}.mrs.backup" "$OUTPUT_DIR/${NAME}.mrs"
            else
                rm -f "$OUTPUT_DIR/${NAME}.mrs"
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
        
        # Проверка HTTP ответа
        if ! check_http_response "${GEOSITE_MRS[$NAME]}"; then
            echo "  ❌ HTTP ошибка"
            ((FAILED_FILES++)) || true
            continue
        fi
        
        # Проверка кэша
        if check_cache "$NAME" "${GEOSITE_MRS[$NAME]}"; then
            echo "  ✅ Без изменений (кэш)"
            ((CACHED_FILES++)) || true
            continue
        fi
        
        # Сохраняем предыдущую версию
        if [[ -f "$OUTPUT_DIR/${NAME}.mrs" ]]; then
            cp "$OUTPUT_DIR/${NAME}.mrs" "$TEMP_DIR/${NAME}.mrs.backup"
        fi
        
        if curl -fL "${GEOSITE_MRS[$NAME]}" -o "$OUTPUT_DIR/${NAME}.mrs" 2>/dev/null; then
            if check_file_size "$OUTPUT_DIR/${NAME}.mrs" 100; then
                if validate_mrs "$TEMP_DIR/mihomo" "$OUTPUT_DIR/${NAME}.mrs"; then
                    echo "  ✅ $(du -h "$OUTPUT_DIR/${NAME}.mrs" | cut -f1)"
                else
                    echo "  ❌ Не прошел валидацию"
                    if [[ -f "$TEMP_DIR/${NAME}.mrs.backup" ]]; then
                        cp "$TEMP_DIR/${NAME}.mrs.backup" "$OUTPUT_DIR/${NAME}.mrs"
                    fi
                    ((FAILED_FILES++)) || true
                fi
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
        
        if ! check_file_size "$TEMP_DIR/${NAME}.txt" 100; then
            echo "  ❌ Файл слишком маленький"
            ((FAILED_FILES++)) || true
            continue
        fi
        
        echo "  🔍 Проверка целостности..."
        if ! check_txt_integrity_ip "$TEMP_DIR/${NAME}.txt" 5; then
            echo "  ❌ Файл не прошел проверку целостности"
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
        
        if ! validate_mrs "$TEMP_DIR/mihomo" "$OUTPUT_DIR/${NAME}.mrs"; then
            echo "  ❌ Не прошел валидацию!"
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
            if check_file_size "$OUTPUT_DIR/${NAME}.mrs" 100; then
                if validate_mrs "$TEMP_DIR/mihomo" "$OUTPUT_DIR/${NAME}.mrs"; then
                    echo "  ✅ $(du -h "$OUTPUT_DIR/${NAME}.mrs" | cut -f1)"
                else
                    echo "  ❌ Не прошел валидацию"
                    if [[ -f "$TEMP_DIR/${NAME}.mrs.backup" ]]; then
                        cp "$TEMP_DIR/${NAME}.mrs.backup" "$OUTPUT_DIR/${NAME}.mrs"
                    fi
                    ((FAILED_FILES++)) || true
                fi
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
echo "🕐 $(date '+%Y-%m-%d %H:%M:%S %Z')"
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
