#!/bin/bash
set -e

# ============================================
# НАСТРОЙКИ
# ============================================
OUTPUT_DIR="output"
OUTPUT_NAME="category-ru-all"

# Исходные данные
REPO_OWNER="MetaCubeX"
REPO_NAME="meta-rules-dat"
BRANCH="meta"
BASE_URL="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${BRANCH}/geo/geosite"

# Список категорий для объединения
declare -a CATEGORY_FILES=(
    "category-ru"
    "category-gov-ru"
    "category-bank-ru"
    "category-media-ru"
    "category-retail-ru"
    "category-travel-ru"
    "category-betting-ru"
    "category-medicine-ru"
    "category-ecommerce-ru"
    "category-entertainment-ru"
)

# Временная папка
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

mkdir -p "$OUTPUT_DIR"

echo "🚀 Запуск скрипта объединения правил..."

# ============================================
# 1. УСТАНОВКА ЗАВИСИМОСТЕЙ (YQ + MIHOMO)
# ============================================

# Устанавливаем yq (инструмент для парсинга YAML)
echo "⚙️ Устанавливаем yq..."
YQ_URL=$(curl -s https://api.github.com/repos/mikefarah/yq/releases/latest | grep "browser_download_url.*linux_amd64" | cut -d '"' -f 4)
curl -L "$YQ_URL" -o /tmp/yq
chmod +x /tmp/yq

# Скачиваем mihomo (конвертер)
echo "⚙️ Скачиваем mihomo..."
MIHOMO_URL=$(curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases/latest | grep "browser_download_url.*mihomo-linux-amd64-compatible.*\.gz" | cut -d '"' -f 4)
if [ -z "$MIHOMO_URL" ]; then
    # Fallback, если точное имя изменилось
    MIHOMO_URL=$(curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases/latest | grep "browser_download_url.*linux-amd64-compatible.*\.gz" | head -n 1 | cut -d '"' -f 4)
fi

curl -L "$MIHOMO_URL" -o "$TEMP_DIR/mihomo.gz"
gunzip -f "$TEMP_DIR/mihomo.gz"
chmod +x "$TEMP_DIR/mihomo"

echo "✅ Инструменты готовы."

# ============================================
# 2. СБОР И ОЧИСТКА ДАННЫХ
# ============================================

TEMP_RAW="$TEMP_DIR/raw_list.txt"
TEMP_CLEAN="$TEMP_DIR/clean_list.txt"
> "$TEMP_RAW"

echo ""
echo "📥 Скачиваем и парсим категории..."

for category in "${CATEGORY_FILES[@]}"; do
    echo -n "   $category.yaml ... "
    
    # Скачиваем
    URL="${BASE_URL}/${category}.yaml"
    if curl -sL "$URL" -o "$TEMP_DIR/current.yaml"; then
        # Парсим через yq (достает все элементы списка payload)
        # sed удаляет кавычки (" или ')
        /tmp/yq '.payload[]' "$TEMP_DIR/current.yaml" | sed "s/[\"']//g" >> "$TEMP_RAW"
        echo "✅"
    else
        echo "❌ Ошибка скачивания"
    fi
done

# Сортируем и удаляем дубликаты
echo "🧹 Сортировка и удаление дубликатов..."
sort -u "$TEMP_RAW" | grep -v '^\s*$' > "$TEMP_CLEAN"

COUNT=$(wc -l < "$TEMP_CLEAN")
echo "✅ Обработано: $COUNT уникальных доменов."

# ============================================
# 3. ГЕНЕРАЦИЯ ФАЙЛОВ
# ============================================

# А. Создаем красивый YAML для вывода (для чтения людьми)
echo "📝 Генерация YAML..."
YAML_PATH="${OUTPUT_DIR}/${OUTPUT_NAME}.yaml"
echo "payload:" > "$YAML_PATH"
while IFS= read -r domain; do
    echo "  - '${domain}'" >> "$YAML_PATH"
done < "$TEMP_CLEAN"

# Б. Конвертируем в MRS (бинарный формат для mihomo)
echo "️ Конвертация в MRS..."
MRS_PATH="${OUTPUT_DIR}/${OUTPUT_NAME}.mrs"

# Конвертируем из YAML в MRS
"$TEMP_DIR/mihomo" convert-ruleset domain yaml "$YAML_PATH" "$MRS_PATH" 2>/dev/null

if [ -f "$MRS_PATH" ]; then
    echo "✅ MRS файл создан: $(du -h "$MRS_PATH" | cut -f1)"
else
    echo "❌ Ошибка создания MRS"
    exit 1
fi

# ============================================
# 4. ГЕНЕРАЦИЯ README
# ============================================
README_PATH="${OUTPUT_DIR}/${OUTPUT_NAME}_README.md"
BUILD_NUM="${GITHUB_RUN_NUMBER:-Local}"
DATE=$(date '+%Y-%m-%d %H:%M')

cat > "$README_PATH" << EOF
# ${OUTPUT_NAME}

**Build:** #${BUILD_NUM}
**Updated:** ${DATE}
**Total Rules:** ${COUNT}

## Sources
Объединенные категории из [${REPO_OWNER}/${REPO_NAME}](https://github.com/${REPO_OWNER}/${REPO_NAME}):
$(for c in "${CATEGORY_FILES[@]}"; do echo "- $c"; done)

## Usage (Mihomo)
\`\`\`yaml
rule-providers:
  category-ru-all:
    type: http
    behavior: domain
    format: mrs
    url: https://raw.githubusercontent.com/Sn1pp1/mymihomofiles/main/${OUTPUT_DIR}/${OUTPUT_NAME}.mrs
    path: ./rules/${OUTPUT_NAME}.mrs
    interval: 21600
\`\`\`
EOF

echo "📄 README обновлен."

# ============================================
# 5. ФИНАЛ
# ============================================
echo ""
echo "🏁 Готово! Файлы лежат в папке $OUTPUT_DIR:"
ls -lh "${OUTPUT_DIR}/${OUTPUT_NAME}."*

exit 0
