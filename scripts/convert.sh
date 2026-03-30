#!/bin/bash
set -e

SOURCE_URL="https://raw.githubusercontent.com/runetfreedom/russia-blocked-geosite/release/ru-blocked.txt"
OUTPUT_DIR="output"
TEMP_DIR=$(mktemp -d)

echo "📥 Скачиваем исходный список доменов..."
curl -sL "$SOURCE_URL" -o "$TEMP_DIR/ru-blocked.txt"

echo "🔄 Конвертируем в YAML-формат для mihomo..."
echo "payload:" > "$TEMP_DIR/ru-blocked.yaml"
while IFS= read -r domain; do
    [[ -z "$domain" || "$domain" =~ ^# ]] && continue
    echo "  - '+.$domain'" >> "$TEMP_DIR/ru-blocked.yaml"
done < "$TEMP_DIR/ru-blocked.txt"

echo "⚙️ Получаем последнюю версию mihomo..."
# Получаем последнюю версию через GitHub API
LATEST_RELEASE=$(curl -sL https://api.github.com/repos/MetaCubeX/mihomo/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
echo "📦 Версия: $LATEST_RELEASE"

MIHOMO_URL="https://github.com/MetaCubeX/mihomo/releases/download/${LATEST_RELEASE}/mihomo-linux-amd64-compatible.gz"

echo "⬇️ Скачиваем mihomo..."
curl -fL "$MIHOMO_URL" -o "$TEMP_DIR/mihomo.gz" || {
    echo "❌ Не удалось скачать mihomo"
    echo "Проверяем что получили:"
    file "$TEMP_DIR/mihomo.gz"
    head -20 "$TEMP_DIR/mihomo.gz"
    exit 1
}

echo "📦 Распаковываем..."
gunzip -f "$TEMP_DIR/mihomo.gz"
chmod +x "$TEMP_DIR/mihomo"

echo "🔧 Конвертируем YAML → MRS..."
mkdir -p "$OUTPUT_DIR"
"$TEMP_DIR/mihomo" convert-ruleset domain yaml "$TEMP_DIR/ru-blocked.yaml" "$OUTPUT_DIR/ru-blocked.mrs"

rm -rf "$TEMP_DIR"

echo "✅ Готово! Файл: $OUTPUT_DIR/ru-blocked.mrs"
echo "📊 Размер: $(du -h "$OUTPUT_DIR/ru-blocked.mrs" | cut -f1)"
