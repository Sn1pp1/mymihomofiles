#!/bin/bash
set -e

# Настройки
SOURCE_URL="https://raw.githubusercontent.com/runetfreedom/russia-blocked-geosite/release/ru-blocked.txt"
OUTPUT_DIR="output"
TEMP_DIR=$(mktemp -d)

echo "📥 Скачиваем исходный список доменов..."
curl -sL "$SOURCE_URL" -o "$TEMP_DIR/ru-blocked.txt"

echo "🔄 Конвертируем в YAML-формат для mihomo..."
# Формируем YAML с префиксом +. для поддержки поддоменов
echo "payload:" > "$TEMP_DIR/ru-blocked.yaml"
while IFS= read -r domain; do
    # Пропускаем пустые строки и комментарии
    [[ -z "$domain" || "$domain" =~ ^# ]] && continue
    # Добавляем +. для матчинга домена и всех поддоменов
    echo "  - '+.$domain'" >> "$TEMP_DIR/ru-blocked.yaml"
done < "$TEMP_DIR/ru-blocked.txt"

echo "⚙️ Скачиваем mihomo для конвертации..."
MIHOMO_URL="https://github.com/MetaCubeX/mihomo/releases/latest/download/mihomo-linux-amd64-compatible.gz"
curl -sL "$MIHOMO_URL" | gunzip > "$TEMP_DIR/mihomo"
chmod +x "$TEMP_DIR/mihomo"

echo "🔧 Конвертируем YAML → MRS..."
mkdir -p "$OUTPUT_DIR"
"$TEMP_DIR/mihomo" convert-ruleset domain yaml "$TEMP_DIR/ru-blocked.yaml" "$OUTPUT_DIR/ru-blocked.mrs"

# Очистка
rm -rf "$TEMP_DIR"

echo "✅ Готово! Файл: $OUTPUT_DIR/ru-blocked.mrs"
echo "📊 Размер: $(du -h "$OUTPUT_DIR/ru-blocked.mrs" | cut -f1)"
