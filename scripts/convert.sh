#!/bin/bash
set -e

OUTPUT_DIR="output"
TEMP_DIR=$(mktemp -d)

# Массив файлов для конвертации
declare -A FILES_MAP=(
    ["ru-blocked"]="https://raw.githubusercontent.com/runetfreedom/russia-blocked-geosite/release/ru-blocked.txt"
    ["refilter"]="https://raw.githubusercontent.com/runetfreedom/russia-blocked-geosite/release/refilter.txt"
)

echo "⚙️ Получаем информацию о последнем релизе mihomo..."
LATEST_JSON=$(curl -sL https://api.github.com/repos/MetaCubeX/mihomo/releases/latest)
MIHOMO_VERSION=$(echo "$LATEST_JSON" | grep '"tag_name"' | cut -d'"' -f4)

echo "📦 Версия mihomo: ${MIHOMO_VERSION}"

# Скачиваем mihomo
echo "$LATEST_JSON" | grep '"browser_download_url"' | cut -d'"' -f4 > "$TEMP_DIR/urls.txt"
MIHOMO_URL=$(grep 'mihomo-linux-amd64-compatible.*\.gz' "$TEMP_DIR/urls.txt" | head -1)

if [[ -z "$MIHOMO_URL" ]]; then
    MIHOMO_URL=$(grep 'mihomo-linux-amd64-v.*\.gz' "$TEMP_DIR/urls.txt" | head -1)
fi

if [[ -z "$MIHOMO_URL" ]]; then
    MIHOMO_URL=$(grep 'mihomo-linux-amd64.*\.gz' "$TEMP_DIR/urls.txt" | grep -v '\.pkg\.tar' | head -1)
fi

if [[ -z "$MIHOMO_URL" ]]; then
    echo "❌ Не удалось найти mihomo"
    exit 1
fi

echo "📥 Скачиваем mihomo..."
curl -fL "$MIHOMO_URL" -o "$TEMP_DIR/mihomo.gz"
gunzip -f "$TEMP_DIR/mihomo.gz"
chmod +x "$TEMP_DIR/mihomo"

mkdir -p "$OUTPUT_DIR"

# Конвертируем каждый файл
for NAME in "${!FILES_MAP[@]}"; do
    SOURCE_URL="${FILES_MAP[$NAME]}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔄 Обработка: $NAME"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    echo "📥 Скачиваем $NAME.txt..."
    curl -sL "$SOURCE_URL" -o "$TEMP_DIR/${NAME}.txt"
    
    echo "🔄 Конвертируем в YAML..."
    echo "payload:" > "$TEMP_DIR/${NAME}.yaml"
    while IFS= read -r domain; do
        [[ -z "$domain" || "$domain" =~ ^# ]] && continue
        echo "  - '+.$domain'" >> "$TEMP_DIR/${NAME}.yaml"
    done < "$TEMP_DIR/${NAME}.txt"
    
    echo "🔧 Конвертируем YAML → MRS..."
    "$TEMP_DIR/mihomo" convert-ruleset domain yaml "$TEMP_DIR/${NAME}.yaml" "$OUTPUT_DIR/${NAME}.mrs"
    
    echo "✅ Готово: $OUTPUT_DIR/${NAME}.mrs ($(du -h "$OUTPUT_DIR/${NAME}.mrs" | cut -f1))"
done

rm -rf "$TEMP_DIR"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Все файлы сконвертированы!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ls -lh "$OUTPUT_DIR"/*.mrs
