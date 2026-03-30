#!/bin/bash
set -e

OUTPUT_DIR="output"
TEMP_DIR=$(mktemp -d)

# GeoSite файлы (требуют конвертации из txt → mrs)
declare -A GEOSITE_FILES=(
    ["ru-blocked"]="https://raw.githubusercontent.com/runetfreedom/russia-blocked-geosite/release/ru-blocked.txt"
    ["refilter"]="https://raw.githubusercontent.com/runetfreedom/russia-blocked-geosite/release/refilter.txt"
    ["domain-list"]="https://github.com/Sn1pp1/mygeofiles/raw/refs/heads/main/files/domain-list.txt"
)

# GeoIP файлы (уже в mrs формате — просто скачиваем)
declare -A GEOIP_FILES=(
    ["ru-blocked-ip"]="https://raw.githubusercontent.com/runetfreedom/russia-blocked-geoip/release/mrs/ru-blocked.mrs"
    ["ru-blocked-community-ip"]="https://raw.githubusercontent.com/runetfreedom/russia-blocked-geoip/release/mrs/ru-blocked-community.mrs"
    ["re-filter-ip"]="https://raw.githubusercontent.com/runetfreedom/russia-blocked-geoip/release/mrs/re-filter.mrs"
)

echo "⚙️ Получаем информацию о последнем релизе mihomo..."
LATEST_JSON=$(curl -sL https://api.github.com/repos/MetaCubeX/mihomo/releases/latest)
MIHOMO_VERSION=$(echo "$LATEST_JSON" | grep '"tag_name"' | cut -d'"' -f4)
echo "📦 Версия mihomo: ${MIHOMO_VERSION}"

# Скачиваем mihomo для конвертации GeoSite
echo "$LATEST_JSON" | grep '"browser_download_url"' | cut -d'"' -f4 > "$TEMP_DIR/urls.txt"
MIHOMO_URL=$(grep 'mihomo-linux-amd64-compatible.*\.gz' "$TEMP_DIR/urls.txt" | head -1)

if [[ -z "$MIHOMO_URL" ]]; then
    MIHOMO_URL=$(grep 'mihomo-linux-amd64-v.*\.gz' "$TEMP_DIR/urls.txt" | head -1)
fi
if [[ -z "$MIHOMO_URL" ]]; then
    MIHOMO_URL=$(grep 'mihomo-linux-amd64.*\.gz' "$TEMP_DIR/urls.txt" | grep -v '\.pkg\.tar' | head -1)
fi

if [[ -z "$MIHOMO_URL" ]]; then
    echo "❌ Не удалось найти mihomo для Linux amd64"
    exit 1
fi

echo "📥 Скачиваем mihomo..."
curl -fL "$MIHOMO_URL" -o "$TEMP_DIR/mihomo.gz"
gunzip -f "$TEMP_DIR/mihomo.gz"
chmod +x "$TEMP_DIR/mihomo"

mkdir -p "$OUTPUT_DIR"

# ============================================
# GeoSite файлы — КОНВЕРТИРУЕМ из txt
# ============================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 GeoSite файлы (конвертация)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for NAME in "${!GEOSITE_FILES[@]}"; do
    SOURCE_URL="${GEOSITE_FILES[$NAME]}"
    echo ""
    echo "🔄 Обработка: $NAME"
    
    echo "  📥 Скачиваем исходный файл..."
    curl -sL "$SOURCE_URL" -o "$TEMP_DIR/${NAME}.txt"
    
    if [[ ! -s "$TEMP_DIR/${NAME}.txt" ]]; then
        echo "  ⚠️ Файл пуст или не скачался, пропускаем..."
        continue
    fi
    
    echo "  🔄 Конвертируем в YAML..."
    echo "payload:" > "$TEMP_DIR/${NAME}.yaml"
    while IFS= read -r domain; do
        [[ -z "$domain" || "$domain" =~ ^# || "$domain" =~ ^[+\*\.] ]] && continue
        echo "  - '+.$domain'" >> "$TEMP_DIR/${NAME}.yaml"
    done < "$TEMP_DIR/${NAME}.txt"
    
    echo "  🔧 Конвертируем YAML → MRS..."
    "$TEMP_DIR/mihomo" convert-ruleset domain yaml "$TEMP_DIR/${NAME}.yaml" "$OUTPUT_DIR/${NAME}.mrs"
    
    echo "  ✅ Готово: $OUTPUT_DIR/${NAME}.mrs ($(du -h "$OUTPUT_DIR/${NAME}.mrs" | cut -f1))"
done

# ============================================
# GeoIP файлы — ПРОСТО СКАЧИВАЕМ
# ============================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌍 GeoIP файлы (скачивание готовых .mrs)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for NAME in "${!GEOIP_FILES[@]}"; do
    SOURCE_URL="${GEOIP_FILES[$NAME]}"
    echo ""
    echo "📥 Скачиваем: $NAME"
    
    curl -fL "$SOURCE_URL" -o "$OUTPUT_DIR/${NAME}.mrs"
    
    echo "  ✅ Готово: $OUTPUT_DIR/${NAME}.mrs ($(du -h "$OUTPUT_DIR/${NAME}.mrs" | cut -f1))"
done

rm -rf "$TEMP_DIR"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Все файлы готовы!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📁 GeoSite (домены):"
ls -lh "$OUTPUT_DIR"/*-domains.mrs 2>/dev/null || echo "  (нет файлов)"
echo ""
echo "📁 GeoIP (IP):"
ls -lh "$OUTPUT_DIR"/*-ip.mrs 2>/dev/null || echo "  (нет файлов)"
