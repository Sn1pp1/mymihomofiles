# My Mihomo Files (MRS)

Автоматически обновляемые правила в формате `.mrs` для ядра **mihomo** (Clash Meta).

## ℹ️ О репозитории

Этот репозиторий автоматически скачивает и конвертирует списки заблокированных ресурсов в формат, совместимый с mihomo.

### 🔁 Как работает обновление

- **Частота**: каждые 6 часов через GitHub Actions
- **Источники**: 
  - [runetfreedom/russia-blocked-geosite](https://github.com/runetfreedom/russia-blocked-geosite) — доменные правила
  - [runetfreedom/russia-blocked-geoip](https://github.com/runetfreedom/russia-blocked-geoip) — IP-правила
  - [itdoginfo/allow-domains](https://github.com/itdoginfo/allow-domains) - доменные списки / IP-диапазоны
  - [roscomvpn-geoip](https://github.com/hydraponique/roscomvpn-geoip) — IP-диапазоны
  - [roscomvpn-geosite](https://github.com/hydraponique/roscomvpn-geosite) — доменные списки
  - [MetaCubeX/meta-rules-dat](https://github.com/MetaCubeX/meta-rules-dat) - доменные списки / IP-диапазоны
  - Кастомные списки

## 📡 КОНФИГУРАЦИЯ ДЛЯ MIHOMO

<details>
<summary>

### 🔽 Показать полный конфиг для копирования 🔽

</summary>


```yaml
mixed-port: 7890
allow-lan: true
bind-address: "*"
lan-allowed-ips:
    - 127.0.0.0/8
    - ::1/128
    - 10.0.0.0/8
    - 172.16.0.0/12
    - 192.168.0.0/16
    - fc00::/7
    - fe80::/10
    - ff00::/8
    - 100.64.0.0/10
    - 169.254.0.0/16
    - 224.0.0.0/3

tcp-concurrent: true
enable-process: true
find-process-mode: always
mode: rule
log-level: info
ipv6: false
keep-alive-interval: 30
unified-delay: true
profile:
  store-selected: true
  store-fake-ip: true

sniffer:
  enable: true
  force-dns-mapping: true
  parse-pure-ip: true
  override-destination: true
  skip-dst-address:
    - 0.0.0.0/8
    - 10.0.0.0/8
    - 100.64.0.0/10
    - 127.0.0.0/8
    - 169.254.0.0/16
    - 172.16.0.0/12
    - 192.0.0.0/24
    - 192.0.2.0/24
    - 192.88.99.0/24
    - 192.168.0.0/16
    - 198.51.100.0/24
    - 203.0.113.0/24
    - 224.0.0.0/3
    - ::/127
    - fc00::/7
    - fe80::/10
    - ff00::/8

  sniff:
    HTTP:
      ports:
        - 80
        - 8080-8880
    TLS:
      ports:
        - 443
        - 8443

tun:
  enable: true
  stack: gvisor
  auto-route: true
  auto-detect-interface: true
  dns-hijack:
    - any:53
    - tcp://any:53
  strict-route: true
  mtu: 1400
  route-exclude-address:
    - 0.0.0.0/8
    - 10.0.0.0/8
    - 100.64.0.0/10
    - 127.0.0.0/8
    - 169.254.0.0/16
    - 172.16.0.0/12
    - 192.0.0.0/24
    - 192.0.2.0/24
    - 192.88.99.0/24
    - 192.168.0.0/16
    - 198.51.100.0/24
    - 203.0.113.0/24
    - 224.0.0.0/3
    - ::/127
    - fc00::/7
    - fe80::/10
    - ff00::/8

dns:
  enable: true
  prefer-h3: false
  use-hosts: true
  use-system-hosts: true
  ipv6: false
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  fake-ip-filter:
    - rule-set:private
    - "*.lan"
    - "*.local"
    - "*.localdomain"
    - "*.workgroup"
    - "*.home"
    - "*.internal"
    - "*.corp"
    - "*.private"
    - "localhost"
    - "localhost.*"
    - "*.msftncsi.com"
    - "*.msftconnecttest.com"
    - "*.gstatic.com"
    - "clients3.google.com"
    - "*.apple.com"
    - "*.icloud.com"

  default-nameserver:
    - https://1.1.1.1/dns-query
    - https://8.8.8.8/dns-query
    - tls://1.1.1.1
    - tls://8.8.8.8
  
  proxy-server-nameserver:
    - https://1.1.1.1/dns-query
    - https://8.8.8.8/dns-query
    - tls://1.1.1.1
    - tls://8.8.8.8
  
  direct-nameserver:
    - https://1.1.1.1/dns-query
    - https://77.88.8.8/dns-query
    - https://8.8.8.8/dns-query
    - tls://77.88.8.8
    - 77.88.8.8
  
  nameserver:
    - https://1.1.1.1/dns-query#🌍  Global
    - https://8.8.8.8/dns-query#🌍  Global
    - tls://1.1.1.1#🌍  Global
    - tls://8.8.8.8#🌍  Global

proxies:
  - name: "🚀 Без VPN"
    type: direct
    udp: true
  - name: DNS-OUT
    type: dns

proxy-groups:
  - name: 🚫 VPN
    icon: https://cdn.jsdelivr.net/gh/remnawave/templates@main/icons/Blocked.png  
    type: select
    proxies:
      - 🎲 Auto
      - 🚀 Без VPN

  - name: ▶️ YouTube
    icon: https://cdn.jsdelivr.net/gh/Koolson/Qure@master/IconSet/Color/YouTube.png
    type: select
    proxies:
      - 🚫 VPN

  - name: ➤ Telegram
    icon: https://cdn.jsdelivr.net/gh/Koolson/Qure@master/IconSet/Color/Telegram.png
    type: select
    proxies:
      - 🚫 VPN
      - 🚀 Без VPN

  - name: 🌍  Global
    icon: https://cdn.jsdelivr.net/gh/Koolson/Qure@master/IconSet/Color/Global.png
    type: select
    proxies:
      - 🚀 Без VPN
      - 🚫 VPN

  - name: 🎲 Auto
    type: url-test
    remnawave:
      include-proxies: true
      shuffle-proxies-order: true
    hidden: true
    url: https://cp.cloudflare.com/generate_204
    interval: 300
    tolerance: 150
    lazy: true

  - name: PROXY
    type: select
    remnawave:
      include-proxies: true
    hidden: true
    proxies:
      - 🚫 VPN

rule-providers:
  category-ads:
    type: http
    behavior: domain
    format: mrs
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/category-ads.mrs
    path: ./rule-sets/category-ads.mrs
    proxy: 🚫 VPN
    interval: 21600
  private:
    type: http
    behavior: domain
    format: mrs
    interval: 21600
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/private.mrs
    path: ./rule-sets/private.mrs
    proxy: 🚫 VPN
  private-ip:
    type: http
    behavior: ipcidr
    format: mrs
    interval: 21600
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/private-ip.mrs
    path: ./rule-sets/private-ip.mrs
    proxy: 🚫 VPN
  telegram:
    type: http
    behavior: domain
    format: mrs
    interval: 21600
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/telegram.mrs
    path: ./rule-sets/telegram.mrs
    proxy: 🚫 VPN
  telegram-ip:
    type: http
    behavior: ipcidr
    format: mrs
    interval: 21600
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/telegram-ip.mrs
    path: ./rule-sets/telegram-ip.mrs
    proxy: 🚫 VPN
  meta:
    type: http
    behavior: domain
    format: mrs
    interval: 21600
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/meta.mrs
    path: ./rule-sets/meta.mrs
    proxy: 🚫 VPN
  meta-ip:
    type: http
    behavior: ipcidr
    format: mrs
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/meta-ip.mrs
    path: ./rule-sets/meta-ip.mrs
    interval: 21600
    proxy: 🚫 VPN
  discord:
    type: http
    behavior: domain
    format: mrs
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/discord.mrs
    path: ./rule-sets/discord.mrs
    interval: 21600
    proxy: 🚫 VPN
  discord-ip:
    type: http
    behavior: ipcidr
    format: mrs
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/discord-ip.mrs
    path: ./rule-sets/discord-ip.mrs
    interval: 21600
    proxy: 🚫 VPN
  youtube:
    type: http
    behavior: domain
    format: mrs
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/youtube.mrs
    path: ./rule-sets/youtube.mrs
    interval: 21600
    proxy: 🚫 VPN
  ru-blocked:
    type: http
    behavior: domain
    format: mrs
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/ru-blocked.mrs
    path: ./rule-sets/ru-blocked.mrs
    interval: 86400
    proxy: 🚫 VPN
  ru-blocked-ip:
    type: http
    behavior: ipcidr
    format: mrs
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/ru-blocked-ip.mrs
    path: ./rule-sets/ru-blocked-ip.mrs
    interval: 21600
    proxy: 🚫 VPN
  ru-blocked-community-ip:
    type: http
    behavior: ipcidr
    format: mrs
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/ru-blocked-community-ip.mrs
    path: ./rule-sets/ru-blocked-community-ip.mrs
    interval: 21600
    proxy: 🚫 VPN
  domain-list:
    type: http
    behavior: domain
    format: mrs
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/domain-list.mrs
    path: ./rule-sets/domain-list.mrs
    interval: 21600
    proxy: 🚫 VPN
  quic:
    type: inline
    behavior: classical
    payload:
      - AND,((NETWORK,udp),(DST-PORT,443))

rules:
  - DST-PORT,53,DNS-OUT
  - RULE-SET,private,DIRECT
  - RULE-SET,private-ip,DIRECT,no-resolve
  - RULE-SET,quic,REJECT
  - RULE-SET,category-ads,REJECT
  - RULE-SET,telegram,➤ Telegram
  - RULE-SET,telegram-ip,➤ Telegram
  - PROCESS-NAME,Telegram.exe,➤ Telegram
  - RULE-SET,meta,🚫 VPN
  - RULE-SET,meta-ip,🚫 VPN
  - RULE-SET,discord,🚫 VPN
  - RULE-SET,discord-ip,🚫 VPN
  - PROCESS-NAME,Discord.exe,🚫 VPN
  - RULE-SET,youtube,▶️ YouTube
  - RULE-SET,ru-blocked,🚫 VPN
  - RULE-SET,ru-blocked-ip,🚫 VPN
  - RULE-SET,ru-blocked-community-ip,🚫 VPN
  - RULE-SET,domain-list,🚫 VPN
  - MATCH,🌍  Global
```
</details>
