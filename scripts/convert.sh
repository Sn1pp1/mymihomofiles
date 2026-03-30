#!/bin/bash
set -e

OUTPUT_DIR="output"
TEMP_DIR=$(mktemp -d)

# Функция для очистки доменов от префиксов
parse_domain_fast() {
    sed -E 's/^(domain|domain-suffix|domain-keyword|full|keyword|regexp|host)://' | \
    sed -E 's/^(\+\.|\*\.)/ /' | \
    sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
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

mkdir -p "$OUTPUT_DIR"

# ============================================
# GeoSite TXT — БЫСТРАЯ КОНВЕРТАЦИЯ
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
        
        echo "  📥 Скачиваем..."
        curl -sL "$SOURCE_URL" -o "$TEMP_DIR/${NAME}.txt"
        
        if [[ ! -s "$TEMP_DIR/${NAME}.txt" ]]; then
            echo "  ⚠️ Пустой файл, пропускаем"
            continue
        fi
        
        LINE_COUNT=$(wc -l < "$TEMP_DIR/${NAME}.txt")
        echo "  📊 Строк в исходнике: $LINE_COUNT"
        echo "  🔄 Обрабатываем..."
        
        # Создаем YAML с правильной структурой
        {
            echo "payload:"
            
            # Обрабатываем файл и добавляем только непустые домены
            cat "$TEMP_DIR/${NAME}.txt" | \
                grep -v '^[[:space:]]*#' | \
                grep -v '^[[:space:]]*$' | \
                parse_domain_fast | \
                grep -v '^$' | \
                grep -v '^regexp:' | \
                grep -v '^keyword:' | \
                grep -v '^domain-keyword' | \
                while IFS= read -r domain; do
                    # Проверяем что домен не пустой и не содержит пробелов
                    if [[ -n "$domain" && ! "$domain" =~ [[:space:]] ]]; then
                        echo "  - '+.$domain'"
                    fi
                done
        } > "$TEMP_DIR/${NAME}.yaml"
        
        # Считаем количество правил
        DOMAIN_COUNT=$(grep -c "^  - " "$TEMP_DIR/${NAME}.yaml" 2>/dev/null || echo "0")
        
        if [[ "$DOMAIN_COUNT" -eq 0 ]]; then
            echo "  ⚠️ Нет доменов для конвертации, пропускаем"
            continue
        fi
        
        echo "  🔧 Конвертируем в MRS (доменов: $DOMAIN_COUNT)..."
        
        # Конвертируем
        if ! "$TEMP_DIR/mihomo" convert-ruleset domain yaml "$TEMP_DIR/${NAME}.yaml" "$OUTPUT_DIR/${NAME}.mrs" 2>&1; then
            echo "  ❌ Ошибка конвертации!"
            echo "  Первые 5 строк YAML:"
            head -5 "$TEMP_DIR/${NAME}.yaml"
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
        echo "📥 $NAME..."
        if curl -fL "${GEOSITE_MRS[$NAME]}" -o "$OUTPUT_DIR/${NAME}.mrs" 2>/dev/null; then
            echo "  ✅ $(du -h "$OUTPUT_DIR/${NAME}.mrs" | cut -f1)"
        else
            echo "  ❌ Не удалось скачать"
        fi
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
        echo "📥 $NAME..."
        if curl -fL "${GEOIP_MRS[$NAME]}" -o "$OUTPUT_DIR/${NAME}.mrs" 2>/dev/null; then
            echo "  ✅ $(du -h "$OUTPUT_DIR/${NAME}.mrs" | cut -f1)"
        else
            echo "  ❌ Не удалось скачать"
        fi
    done
fi

rm -rf "$TEMP_DIR"

# ============================================
# ФИНАЛЬНЫЙ ВЫВОД
# ============================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Готово!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
[[ -n "$GITHUB_RUN_NUMBER" ]] && echo "📦 Build #${GITHUB_RUN_NUMBER}"
echo "🕐 $(date '+%Y-%m-%d %H:%M:%S %Z')"
FILE_COUNT=$(ls -1 "$OUTPUT_DIR"/*.mrs 2>/dev/null | wc -l)
echo "📁 Файлов: $FILE_COUNT"
if [[ "$FILE_COUNT" -gt 0 ]]; then
    echo ""
    ls -lh "$OUTPUT_DIR"/*.mrs 2>/dev/null | awk '{print "   • " $9 " (" $5 ")"}'
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
