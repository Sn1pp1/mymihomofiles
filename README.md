# My Mihomo Files (MRS)

Автоматически обновляемые правила в формате `.mrs` для ядра **mihomo** (Clash Meta).

## ℹ️ О репозитории

Этот репозиторий автоматически скачивает и конвертирует списки заблокированных ресурсов в формат, совместимый с mihomo.

### 🔁 Как работает обновление

- **Частота**: каждые 6 часов через GitHub Actions
- **Источники**: 
  - [runetfreedom/russia-blocked-geosite](https://github.com/runetfreedom/russia-blocked-geosite) — доменные правила
  - [runetfreedom/russia-blocked-geoip](https://github.com/runetfreedom/russia-blocked-geoip) — IP-правила
  - [legiz-ru/mihomo-rule-sets](https://github.com/legiz-ru/mihomo-rule-sets) - доменные списки / IP-диапазоны
  - [Davoyan/mihomo-rule-sets](https://github.com/Davoyan/mihomo-rule-sets) - доменные списки / IP-диапазоны
  - [itdoginfo/allow-domains](https://github.com/itdoginfo/allow-domains) - доменные списки / IP-диапазоны
  - [roscomvpn-geoip](https://github.com/hydraponique/roscomvpn-geoip) — IP-диапазоны
  - [roscomvpn-geosite](https://github.com/hydraponique/roscomvpn-geosite) — доменные списки
  - [MetaCubeX/meta-rules-dat](https://github.com/MetaCubeX/meta-rules-dat) - доменные списки / IP-диапазоны
  - Кастомные списки
