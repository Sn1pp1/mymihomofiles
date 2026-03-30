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

# Сохраняем все URL во временный файл
echo "$LATEST_JSON" | grep '"browser_download_url"' | cut -d'"' -f4 > "$TEMP_DIR/urls.txt"

echo "🔍 Ищем mihomo-linux-amd64-compatible..."
# Ищем файл с compatible
MIHOMO_URL=$(grep 'mihomo-linux-amd64-compatible.*\.gz' "$TEMP_DIR/urls.txt" | head -1)

if [[ -z "$MIHOMO_URL" ]]; then
    echo "⚠️ Не найдено compatible, ищем mihomo-linux-amd64-v..."
    MIHOMO_URL=$(grep 'mihomo-linux-amd64-v.*\.gz' "$TEMP_DIR/urls.txt" | head -1)
fi

if [[ -z "$MIHOMO_URL" ]]; then
    echo "⚠️ Ищем любой mihomo-linux-amd64 .gz"
    MIHOMO_URL=$(grep 'mihomo-linux-amd64.*\.gz' "$TEMP_DIR/urls.txt" | grep -v '\.pkg\.tar' | head -1)
fi

if [[ -z "$MIHOMO_URL" ]]; then
    echo "❌ Не удалось найти подходящий файл"
    echo "Доступные Linux amd64 файлы:"
    grep 'linux-amd64' "$TEMP_DIR/urls.txt"
    exit 1
fi

echo "✅ Найдено: $MIHOMO_URL"
echo "📥 Скачиваем..."
curl -fL "$MIHOMO_URL" -o "$TEMP_DIR/mihomo.gz"

echo "📦 Распаковываем..."
gunzip -f "$TEMP_DIR/mihomo.gz"
chmod +x "$TEMP_DIR/mihomo"

echo "🔧 Версия mihomo:"
"$TEMP_DIR/mihomo" -v || true

echo "🔧 Конвертируем YAML → MRS..."
mkdir -p "$OUTPUT_DIR"
"$TEMP_DIR/mihomo" convert-ruleset domain yaml "$TEMP_DIR/ru-blocked.yaml" "$OUTPUT_DIR/ru-blocked.mrs"

rm -rf "$TEMP_DIR"

echo "✅ Готово!"
echo "📁 Файл: $OUTPUT_DIR/ru-blocked.mrs"
echo "📊 Размер: $(du -h "$OUTPUT_DIR/ru-blocked.mrs" | cut -f1)"
