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
allow-lan: false
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
    - 10.0.0.0/8
    - 172.16.0.0/12
    - 192.168.0.0/16
    - 0.0.0.0/8
    - 127.0.0.0/8
    - 100.64.0.0/10
    - 169.254.0.0/16
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
    QUIC:
      ports:
        - 443

tun:
  enable: true
  stack: gVisor
  auto-route: true
  auto-detect-interface: true
  dns-hijack:
    - any:53
    - tcp://any:53
  strict-route: true
  mtu: 1400
  route-exclude-address:
    - 10.0.0.0/8
    - 172.16.0.0/12
    - 192.168.0.0/16
    - 0.0.0.0/8
    - 127.0.0.0/8
    - 100.64.0.0/10
    - 169.254.0.0/16
    - 224.0.0.0/3
    - ::/127
    - fc00::/7
    - fe80::/10
    - ff00::/8

dns:
  enable: true
  prefer-h3: true
  use-hosts: true
  use-system-hosts: true
  listen: 127.0.0.1:6868
  ipv6: false
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  fake-ip-filter:
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
    - https://1.1.1.1/dns-query
    - https://8.8.8.8/dns-query
    - tls://1.1.1.1
    - tls://8.8.8.8

proxies:
proxy-groups:
  - name: 🛡️ VPN
    icon: https://cdn.jsdelivr.net/gh/Koolson/Qure@master/IconSet/Color/Hijacking.png  
    type: select
    proxies:
      - 🎲 Auto

  - name: ▶️ YouTube
    icon: https://cdn.jsdelivr.net/gh/Koolson/Qure@master/IconSet/Color/YouTube.png
    type: select
    proxies:
      - 🛡️ VPN

  - name: ➤ Telegram
    icon: https://cdn.jsdelivr.net/gh/Koolson/Qure@master/IconSet/Color/Telegram.png
    type: select
    proxies:
      - 🛡️ VPN
      - 🚀 Без VPN

  - name: 🌍  Global
    icon: https://cdn.jsdelivr.net/gh/Koolson/Qure@master/IconSet/Color/Global.png
    type: select
    proxies:
      - 🚀 Без VPN
      - 🛡️ VPN

  - name: 🎲 Auto
    type: url-test
    hidden: true
    tolerance: 150
    url: https://cp.cloudflare.com/generate_204
    interval: 300
    proxies:

  - name: PROXY
    type: select
    hidden: true
    proxies:
      - 🛡️ VPN

  - name: 🚀 Без VPN
    type: select
    hidden: true
    proxies:
      - DIRECT

rule-providers:
  category-ads:
    type: http
    behavior: domain
    format: mrs
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/category-ads.mrs
    path: ./rule-sets/category-ads.mrs
    proxy: 🛡️ VPN
    interval: 21600
  telegram:
    type: http
    behavior: domain
    format: mrs
    interval: 21600
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/telegram.mrs
    path: ./rule-sets/telegram.mrs
    proxy: 🛡️ VPN
  telegram-ip:
    type: http
    behavior: ipcidr
    format: mrs
    interval: 21600
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/telegram-ip.mrs
    path: ./rule-sets/telegram-ip.mrs
    proxy: 🛡️ VPN
  meta:
    type: http
    behavior: domain
    format: mrs
    interval: 21600
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/meta.mrs
    path: ./rule-sets/meta.mrs
    proxy: 🛡️ VPN
  meta-ip:
    type: http
    behavior: ipcidr
    format: mrs
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/meta-ip.mrs
    path: ./rule-sets/meta-ip.mrs
    interval: 21600
    proxy: 🛡️ VPN
  discord:
    type: http
    behavior: domain
    format: mrs
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/discord.mrs
    path: ./rule-sets/discord.mrs
    interval: 21600
    proxy: 🛡️ VPN
  discord-ip:
    type: http
    behavior: ipcidr
    format: mrs
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/discord-ip.mrs
    path: ./rule-sets/discord-ip.mrs
    interval: 21600
    proxy: 🛡️ VPN
  youtube:
    type: http
    behavior: domain
    format: mrs
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/youtube.mrs
    path: ./rule-sets/youtube.mrs
    interval: 21600
    proxy: 🛡️ VPN
  ru-blocked:
    type: http
    behavior: domain
    format: mrs
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/ru-blocked.mrs
    path: ./rule-sets/ru-blocked.mrs
    interval: 86400
    proxy: 🛡️ VPN
  ru-blocked-ip:
    type: http
    behavior: ipcidr
    format: mrs
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/ru-blocked-ip.mrs
    path: ./rule-sets/ru-blocked-ip.mrs
    interval: 21600
    proxy: 🛡️ VPN
  ru-blocked-community-ip:
    type: http
    behavior: ipcidr
    format: mrs
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/ru-blocked-community-ip.mrs
    path: ./rule-sets/ru-blocked-community-ip.mrs
    interval: 21600
    proxy: 🛡️ VPN
  domain-list:
    type: http
    behavior: domain
    format: mrs
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/domain-list.mrs
    path: ./rule-sets/domain-list.mrs
    interval: 21600
    proxy: 🛡️ VPN

rules:
  - RULE-SET,category-ads,REJECT
  - RULE-SET,telegram,➤ Telegram
  - RULE-SET,telegram-ip,➤ Telegram
  - PROCESS-NAME,Telegram.exe,➤ Telegram
  - RULE-SET,meta,PROXY
  - RULE-SET,meta-ip,PROXY
  - RULE-SET,discord,PROXY
  - RULE-SET,discord-ip,PROXY
  - PROCESS-NAME,Discord.exe,PROXY
  - RULE-SET,youtube,▶️ YouTube
  - RULE-SET,ru-blocked,PROXY
  - RULE-SET,ru-blocked-ip,PROXY
  - RULE-SET,ru-blocked-community-ip,PROXY
  - RULE-SET,domain-list,PROXY
  - MATCH,🌍  Global
```
</details>
