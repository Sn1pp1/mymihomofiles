#!/bin/bash
set -e

SOURCE_URL="https://raw.githubusercontent.com/runetfreedom/russia-blocked-geosite/release/ru-blocked.txt"
OUTPUT_DIR="output"
TEMP_DIR=$(mktemp -d)

echo "📥 Скачиваем исходный список доменов..."
curl -sL "$SOURCE_URL" -o "$TEMP_DIR/ru-blocked.txt"

echo "🔄 Конвертируем в YAML..."
echo "payload:" > "$TEMP_DIR/ru-blocked.yaml"
while IFS= read -r domain; do
    [[ -z "$domain" || "$domain" =~ ^# ]] && continue
    echo "  - '+.$domain'" >> "$TEMP_DIR/ru-blocked.yaml"
done < "$TEMP_DIR/ru-blocked.txt"

echo "⚙️ Получаем информацию о последнем релизе mihomo..."
LATEST_JSON=$(curl -sL https://api.github.com/repos/MetaCubeX/mihomo/releases/latest)
MIHOMO_VERSION=$(echo "$LATEST_JSON" | grep '"tag_name"' | cut -d'"' -f4)

echo "📦 Найденная версия: ${MIHOMO_VERSION:-'не найдена'}"

# Пробуем разные варианты имен файлов
MIHOMO_FILES=(
    "mihomo-linux-amd64-compatible"
    "mihomo-linux-amd64"
    "mihomo"
)

for MIHOMO_BASE in "${MIHOMO_FILES[@]}"; do
    MIHOMO_URL="https://github.com/MetaCubeX/mihomo/releases/download/${MIHOMO_VERSION}/${MIHOMO_BASE}.gz"
    echo "🔄 Пробуем: ${MIHOMO_BASE}"
    
    if curl -fL "$MIHOMO_URL" -o "$TEMP_DIR/mihomo.gz" 2>/dev/null; then
        echo "✅ Успешно скачан: ${MIHOMO_BASE}"
        break
    fi
done

if [[ ! -f "$TEMP_DIR/mihomo.gz" ]]; then
    echo "❌ Не удалось скачать mihomo ни в одном из форматов"
    echo "Доступные файлы в релизе ${MIHOMO_VERSION}:"
    echo "$LATEST_JSON" | grep '"browser_download_url"' | cut -d'"' -f4
    exit 1
fi

gunzip -f "$TEMP_DIR/mihomo.gz"
chmod +x "$TEMP_DIR/mihomo"

echo "🔧 Конвертируем в MRS..."
mkdir -p "$OUTPUT_DIR"
"$TEMP_DIR/mihomo" convert-ruleset domain yaml "$TEMP_DIR/ru-blocked.yaml" "$OUTPUT_DIR/ru-blocked.mrs"

rm -rf "$TEMP_DIR"

echo "✅ Готово: $OUTPUT_DIR/ru-blocked.mrs ($(du -h "$OUTPUT_DIR/ru-blocked.mrs" | cut -f1))"
