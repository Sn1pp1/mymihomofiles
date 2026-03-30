#!/bin/bash
set -e

OUTPUT_DIR="output"
TEMP_DIR=$(mktemp -d)

# ============================================
# 4 МАССИВА ДЛЯ РАЗНЫХ ТИПОВ ФАЙЛОВ
# ============================================

# 1. GeoSite TXT (домены) — конвертируем в MRS
declare -A GEOSITE_TXT=(
    ["ru-blocked"]="https://raw.githubusercontent.com/runetfreedom/russia-blocked-geosite/release/ru-blocked.txt"
    ["refilter"]="https://raw.githubusercontent.com/runetfreedom/russia-blocked-geosite/release/refilter.txt"
    ["domain-list"]="https://github.com/Sn1pp1/mygeofiles/raw/refs/heads/main/files/domain-list.txt"
)

# 2. GeoSite MRS (домены) — просто скачиваем
declare -A GEOSITE_MRS=(
    # Пример:
    ["category-ads"]="https://github.com/hydraponique/roscomvpn-geosite/raw/refs/heads/master/release/mihomo/category-ads.mrs"
)

# 3. GeoIP TXT (IP-адреса) — конвертируем в MRS
declare -A GEOIP_TXT=(
    # Пример:
    #["discord_ipcidr"]=""
)

# 4. GeoIP MRS (IP-адреса) — просто скачиваем
declare -A GEOIP_MRS=(
    ["ru-blocked-ip"]="https://raw.githubusercontent.com/runetfreedom/russia-blocked-geoip/release/mrs/ru-blocked.mrs"
    ["ru-blocked-community-ip"]="https://raw.githubusercontent.com/runetfreedom/russia-blocked-geoip/release/mrs/ru-blocked-community.mrs"
    ["refilter-ip"]="https://raw.githubusercontent.com/runetfreedom/russia-blocked-geoip/release/mrs/re-filter.mrs"
    ["discord-ip"]="https://github.com/itdoginfo/allow-domains/releases/latest/download/discord_ipcidr.mrs"
    ["meta-ip"]="https://github.com/itdoginfo/allow-domains/releases/latest/download/meta_ipcidr.mrs"
)

# ============================================
# СКАЧИВАНИЕ MIHOMO ДЛЯ КОНВЕРТАЦИИ
# ============================================

echo "⚙️ Получаем информацию о последнем релизе mihomo..."
LATEST_JSON=$(curl -sL https://api.github.com/repos/MetaCubeX/mihomo/releases/latest)
MIHOMO_VERSION=$(echo "$LATEST_JSON" | grep '"tag_name"' | cut -d'"' -f4)
echo "📦 Версия mihomo: ${MIHOMO_VERSION}"

# Проверяем, есть ли TXT файлы для конвертации
HAS_TXT_FILES=false
if [[ ${#GEOSITE_TXT[@]} -gt 0 || ${#GEOIP_TXT[@]} -gt 0 ]]; then
    HAS_TXT_FILES=true
fi

if [[ "$HAS_TXT_FILES" == "true" ]]; then
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
fi

mkdir -p "$OUTPUT_DIR"

# ============================================
# 1. GeoSite TXT — КОНВЕРТИРУЕМ (domain)
# ============================================
if [[ ${#GEOSITE_TXT[@]} -gt 0 ]]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🌐 GeoSite TXT → MRS (конвертация)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    for NAME in "${!GEOSITE_TXT[@]}"; do
        SOURCE_URL="${GEOSITE_TXT[$NAME]}"
        echo ""
        echo "🔄 Обработка: $NAME (domain)"
        
        echo "  📥 Скачиваем..."
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
        
        echo "  🔧 Конвертируем YAML → MRS (behavior: domain)..."
        "$TEMP_DIR/mihomo" convert-ruleset domain yaml "$TEMP_DIR/${NAME}.yaml" "$OUTPUT_DIR/${NAME}.mrs"
        
        echo "  ✅ Готово: $OUTPUT_DIR/${NAME}.mrs ($(du -h "$OUTPUT_DIR/${NAME}.mrs" | cut -f1))"
    done
fi

# ============================================
# 2. GeoSite MRS — СКАЧИВАЕМ (domain)
# ============================================
if [[ ${#GEOSITE_MRS[@]} -gt 0 ]]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🌐 GeoSite MRS (скачивание)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    for NAME in "${!GEOSITE_MRS[@]}"; do
        SOURCE_URL="${GEOSITE_MRS[$NAME]}"
        echo ""
        echo "📥 Скачиваем: $NAME (domain)"
        
        curl -fL "$SOURCE_URL" -o "$OUTPUT_DIR/${NAME}.mrs"
        
        echo "  ✅ Готово: $OUTPUT_DIR/${NAME}.mrs ($(du -h "$OUTPUT_DIR/${NAME}.mrs" | cut -f1))"
    done
fi

# ============================================
# 3. GeoIP TXT — КОНВЕРТИРУЕМ (ipcidr)
# ============================================
if [[ ${#GEOIP_TXT[@]} -gt 0 ]]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🌍 GeoIP TXT → MRS (конвертация)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    for NAME in "${!GEOIP_TXT[@]}"; do
        SOURCE_URL="${GEOIP_TXT[$NAME]}"
        echo ""
        echo "🔄 Обработка: $NAME (ipcidr)"
        
        echo "  📥 Скачиваем..."
        curl -sL "$SOURCE_URL" -o "$TEMP_DIR/${NAME}.txt"
        
        if [[ ! -s "$TEMP_DIR/${NAME}.txt" ]]; then
            echo "  ⚠️ Файл пуст или не скачался, пропускаем..."
            continue
        fi
        
        echo "  🔄 Конвертируем в YAML..."
        echo "payload:" > "$TEMP_DIR/${NAME}.yaml"
        while IFS= read -r ip; do
            [[ -z "$ip" || "$ip" =~ ^# ]] && continue
            echo "  - '$ip'" >> "$TEMP_DIR/${NAME}.yaml"
        done < "$TEMP_DIR/${NAME}.txt"
        
        echo "  🔧 Конвертируем YAML → MRS (behavior: ipcidr)..."
        "$TEMP_DIR/mihomo" convert-ruleset ipcidr yaml "$TEMP_DIR/${NAME}.yaml" "$OUTPUT_DIR/${NAME}.mrs"
        
        echo "  ✅ Готово: $OUTPUT_DIR/${NAME}.mrs ($(du -h "$OUTPUT_DIR/${NAME}.mrs" | cut -f1))"
    done
fi

# ============================================
# 4. GeoIP MRS — СКАЧИВАЕМ (ipcidr)
# ============================================
if [[ ${#GEOIP_MRS[@]} -gt 0 ]]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🌍 GeoIP MRS (скачивание)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    for NAME in "${!GEOIP_MRS[@]}"; do
        SOURCE_URL="${GEOIP_MRS[$NAME]}"
        echo ""
        echo "📥 Скачиваем: $NAME (ipcidr)"
        
        curl -fL "$SOURCE_URL" -o "$OUTPUT_DIR/${NAME}.mrs"
        
        echo "  ✅ Готово: $OUTPUT_DIR/${NAME}.mrs ($(du -h "$OUTPUT_DIR/${NAME}.mrs" | cut -f1))"
    done
fi

rm -rf "$TEMP_DIR"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Все файлы готовы!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📁 Сгенерированные файлы:"
ls -lh "$OUTPUT_DIR"/*.mrs 2>/dev/null || echo "  (нет файлов)"
