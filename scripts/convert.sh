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

echo "📦 Версия: ${MIHOMO_VERSION}"

# Извлекаем все URL для Linux amd64
echo "🔍 Ищем подходящий файл для Linux amd64..."
MIHOMO_URL=$(echo "$LATEST_JSON" | grep '"browser_download_url"' | \
    grep 'mihomo-linux-amd64-compatible.*\.gz$' | \
    cut -d'"' -f4 | head -1)

if [[ -z "$MIHOMO_URL" ]]; then
    echo "⚠️ Не найдено mihomo-linux-amd64-compatible, пробуем просто mihomo-linux-amd64..."
    MIHOMO_URL=$(echo "$LATEST_JSON" | grep '"browser_download_url"' | \
        grep 'mihomo-linux-amd64[^-].*\.gz$' | \
        cut -d'"' -f4 | head -1)
fi

if [[ -z "$MIHOMO_URL" ]]; then
    echo "❌ Не удалось найти подходящий файл для Linux amd64"
    echo "Доступные файлы:"
    echo "$LATEST_JSON" | grep '"browser_download_url"' | grep 'linux-amd64' | cut -d'"' -f4
    exit 1
fi

echo "📥 Скачиваем: $MIHOMO_URL"
curl -fL "$MIHOMO_URL" -o "$TEMP_DIR/mihomo.gz"

echo "📦 Распаковываем..."
gunzip -f "$TEMP_DIR/mihomo.gz"
chmod +x "$TEMP_DIR/mihomo"

echo "🔧 Проверяем версию..."
"$TEMP_DIR/mihomo" -v || true

echo "🔧 Конвертируем YAML → MRS..."
mkdir -p "$OUTPUT_DIR"
"$TEMP_DIR/mihomo" convert-ruleset domain yaml "$TEMP_DIR/ru-blocked.yaml" "$OUTPUT_DIR/ru-blocked.mrs"

rm -rf "$TEMP_DIR"

echo "✅ Готово!"
echo "📁 Файл: $OUTPUT_DIR/ru-blocked.mrs"
echo "📊 Размер: $(du -h "$OUTPUT_DIR/ru-blocked.mrs" | cut -f1)"
