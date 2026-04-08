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
  strict-route: false
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
  exclude-package:
    - club.skillz.fitness
    - com.apegroup.mcdonaldsrussia
    - com.bankffin.portfolio
    - com.bastion
    - com.bifit.rncbbeta
    - ru.spb.parking
    - com.whsd.whsdapp
    - com.orgp.spbpodorozhnik
    - ru.ftc.tc
    - com.carshering
    - com.citymobil
    - com.taxsee.taxsee
    - ru.yandex.uber
    - ru.taxovichkof.android
    - ru.rolf.rolf
    - ru.russianhighways.mobile
    - ru.mosparking.appnew
    - centrida.neftmagistral
    - ru.pichesky.rosneft
    - ru.serebryakovas.lukoilmobileapp
    - ru.tatneft.gasstations
    - com.gpn.azs
    - com.coolclever.app
    - com.deliveryclub
    - com.discover.moscow.lite
    - com.edadeal.android
    - com.gnivts.ausn
    - com.gnivts.selfemployed
    - com.icemobile.lenta.prod
    - com.idamob.tinkoff.android
    - com.keenetic.kn
    - ru.netcraze.app
    - com.moscowsport
    - com.premiumbonus.jamm.ramen
    - pro.arora.mobile.pizza_milana
    - pro.arora.mobile.maradi
    - com.punicapp.whoosh
    - com.ru.dixy
    - com.salute.smarthome.prod
    - com.sberauto.mobile
    - com.sberbank.sberpravo
    - com.tdm.messenger
    - com.tjuraniaapp
    - com.uip.gosuslugi2
    - com.vk.clips
    - live.vkplay.app
    - ru.mail.mailapp
    - com.vk.im
    - com.vk.vkvideo
    - com.wildberries.ru
    - com.yandex.bank
    - com.yandex.bluecollars
    - com.yandex.iot
    - com.yandex.lavka
    - com.yandex.mobile.drive
    - com.yandex.mobile.realty
    - com.yandex.plus.game.city
    - com.yandex.searchapp
    - com.yandex.shedevrus2
    - com.yandex.tasks.androidapp
    - com.yandex.yamb
    - com.zvooq.openplay
    - es.hol.ing.zagsr
    - im.dlg.dialogx
    - im.dlg.enterprise
    - io.github.dovecoteescapee.byedpi
    - io.itforces.android.timetable
    - logo.com.mbanking
    - org.orange.mobile
    - pro.sber_zvuk
    - ru.akbars.mobile
    - ru.alfabank.mobile.android
    - ru.alfabank.oavdo.amc
    - ru.alfadirect.app
    - ru.aliexpress.buyer
    - ru.altarix.mos.pgu
    - ru.auto.ara
    - ru.aviasales
    - ru.beru.android
    - ru.bspb
    - ru.burgerking
    - ru.cardsmobile.mw3
    - ru.crptech.b2bmark
    - ru.crptech.mark
    - ru.datapax.mosobl
    - ru.diftechsvc
    - ru.dit.smartstaff
    - ru.dodopizza.app
    - ru.domclick.mortgage
    - ru.drclinics.app.sovcom
    - ru.dublgis.dgismobile
    - ru.dublgis.dgismobile4preview
    - otello.dgis.ru
    - ru.fanid
    - ru.filit.mvideo.b2c
    - ru.finassist
    - ru.fns.billchecker
    - ru.fns.billchecker.mobile.android
    - ru.fns.lkfl
    - ru.foodfox.client
    - ru.gazprombank.android.mobilebank.app
    - ru.getpharma.eapteka
    - ru.gnivc.lkip
    - ru.goods.marketplace
    - ru.gosuslugi.auto
    - ru.gosuslugi.culture
    - ru.gosuslugi.goskey
    - ru.gosuslugi.pos
    - ru.gosuslugi.pos.executor
    - ru.instamart
    - ru.kfc.kfc_delivery
    - ru.kinopoisk
    - ru.letobank.prometheus
    - ru.megafon.mlk
    - ru.megamarket.marketplace
    - ru.mes.sputnik
    - ru.mes.dnevnik
    - ru.more.play
    - ru.mos.app
    - ru.mos.ed
    - ru.mos.gz
    - ru.mos.myid
    - ru.mos.ourcity
    - ru.mos.polls
    - ru.mos.um
    - ru.mos.zaryadye
    - ru.mosgorpass
    - ru.mosmetro.metro
    - ru.mosoblgaz
    - ru.mosreg.easuz.portal
    - ru.mosreg.ekjp
    - ru.mosreg.mingos.mdp.app
    - ru.mosreg.mo112
    - ru.mosreg.uslugi.mobile.beta
    - ru.mts.bank
    - ru.mts.mtstv
    - ru.mts.mymts
    - ru.mvm.eldo
    - ru.sportmaster.app
    - ru.myspar
    - ru.nalog.rmr.client
    - ru.nspk.mir.loyalty
    - ru.nspk.mirpay
    - ru.okbmei.gosservice
    - ru.ostrovok.android
    - ru.ozon.app.android
    - ru.ozon.fintech.finance
    - ru.perekrestok.app
    - club.chizhik
    - ru.plus.bookmate
    - ru.pyaterochka.app.browser
    - ru.raiffeisennews
    - ru.rambler.mail
    - ru.rostel
    - ru.rutube.app
    - ru.rutube.RutubeKids
    - ru.rutube.studio
    - ru.rutube.app.tv
    - gpm.tnt_premier
    - one.premier.rustoretv
    - ru.rzd.pass
    - ru.salute.b2b.prod
    - ru.sbcs.store
    - ru.sber.csradar
    - ru.sber.telecom
    - ru.sberbank.investor
    - ru.sberbank.onlineencashment
    - ru.sberbank.sberkids
    - ru.sberbank.sbersign
    - ru.sberbank_sbbol
    - ru.sberbankmobile
    - ru.sberins.insureapp.android
    - ru.sbermegamarket.pro
    - ru.sovcombank.dms
    - ru.sovcombank.investor
    - ru.sovcomcard.halva.v1
    - pro.rocketTech.rocket.rocketapp
    - ru.oneme.app
    - ru.start.androidmobile
    - ru.bristol.bristol_app
    - www.metro.com
    - ru.tander.magnit
    - ru.technokad.digitalkey
    - ru.tii.lkcomu
    - ru.tinkoff.bnpl
    - ru.tinkoff.invest.course
    - ru.tinkoff.investing
    - ru.tinkoff.magent
    - ru.tinkoff.mvno
    - ru.tinkoff.posterminal
    - ru.tinkoff.sme
    - ru.troika.regional
    - ru.urentbike.app
    - com.vkontakte.android
    - ru.vk.store
    - ru.vk.video
    - ru.vkmusic.audio
    - ru.tbank.online
    - ru.amina.moscow
    - ru.lewis.dbo
    - ru.gibdd_pay.app
    - com.moex.finuslugi
    - su.azure.paymaster
    - ru.nspk.sbpay
    - ru.gosuslugi.school
    - ru.sigma.gisgkh
    - ru.rshb.dbo
    - ru.spb.iac.dnevnikspb_new
    - ru.ues.users_personal_account
    - com.leroymerlin.mobile
    - ru.kari.android
    - ru.sunlight.sunlight
    - level.travel
    - ru.abrr.gas
    - com.maxxt.recordradio
    - com.uchi.app
    - ru.chitaigorod.mobile
    - ru.usetech.velobike.v2
    - ru.zolotoy585.customer
    - com.onecwearable.keyboard.rustore
    - com.gloriajeans.mobile
    - ru.rabota.app2
    - ru.domopult.mosobleirc.android
    - ru.rgs.lk
    - ru.dikidi
    - ru.citilink
    - ru.spb.dnevnik
    - ru.sima_land.spb.market
    - ru.ufanet.myufanet
    - ru.bcs.bcsbank
    - com.svoi.bank
    - ru.vkusvill
    - ru.detmir.dmbonus
    - ru.lenta.lentochka
    - goldapple.ru.goldapple.customers
    - com.notissimus.allinstruments.android
    - ru.vseapteki
    - ru.leonardo.leonardoshop
    - ru.leroymerlin.mobile
    - ru.maxidom.ecomm
    - air.ru.obi.mobile
    - com.logistic.sdek
    - ru.vtb24.mobilebanking.android
    - ru.yandex.androidkeyboard
    - ru.yandex.disk
    - ru.yandex.games
    - ru.yandex.key
    - ru.yandex.mail
    - ru.yandex.market.partner
    - ru.yandex.metro
    - ru.yandex.mobile.gasstations
    - ru.yandex.music
    - ru.yandex.practicum.flutter_practicum
    - ru.yandex.subtitles
    - ru.yandex.taxi
    - ru.yandex.taximeter
    - ru.yandex.translate
    - ru.yandex.travel
    - ru.yandex.weatherplugin
    - ru.yandex.yandexmaps
    - ru.yandex.yandexnavi
    - ru.yandex_team.calendar_app
    - ru.yoo.business
    - ru.yoo.kassa
    - ru.yoo.money
    - ru.yoo.sdk.kassa.payments.example.release
    - ru.yota.android
    - ru.zhuck.webapp
    - ru.ok.android
    - team.rtds.checkcontrol
    - tv.lfstrm.smotreshka
    - com.apteka.sklad
    - com.platfomni.gorzdrav
    - com.invitro.app
    - youdrive.today
    - com.kms.free
    - ru.paribet
    - ru.rosbank.android.beta
    - ru.beeline.services
    - ru.beeline.cloud
    - ru.beeline.tve.android
    - ru.otpbank.mobile
    - biz.growapp.winline
    - com.national.lottery
    - ru.stoloto.mobile
    - ru.bkfon
    - ru.cian.main
    - ru.m2.squaremeter
    - ru.winelab
    - ru.smmd.superdelivery
    - ru.aisa.android.ekpv2
    - com.mobium12580.app
    - ru.smclinic.app.lk
    - com.teremok.keys
    - ru.tokyocity.tokyocity
    - com.tseh85
    - ru.plazius.cofix
    - com.avito.android
    - ru.x5.omni
    - ru.tele2.mytele2
    - by.advasoft.android.troika.app
    - com.octopod.russianpost.client.android
    - ru.dahl.messenger
    - ru.dns.shop.android
  exclude-process:
    # === ЛАУНЧЕРЫ ===
    - steam.exe
    - steamwebhelper.exe
    - Battle.net.exe
    - Agent.exe
    - BlizzardBrowser.exe
    - EpicGamesLauncher.exe
    - EpicWebHelper.exe
    - RiotClientServices.exe
    - RiotClientUx.exe
    - UbisoftConnect.exe
    - Uplay.exe
    - EADesktop.exe
    - Origin.exe
    - RockstarGamesLauncher.exe
    - SocialClubHelper.exe
    - GalaxyClient.exe
    - ZFGameBrowser.exe
    - KRWebView.exe
    - KRSDKExternal.exe
    - ExecPubg.exe
    - PlayGTAV.exe
    - FortniteLauncher.exe
    - ApexLauncher.exe
    - MarvelRivals_Launcher.exe

        # === ИГРЫ ===
    - cs2.exe
    - csgo.exe
    - dota2.exe
    - VALORANT-Win64-Shipping.exe
    - League of Legends.exe
    - LeagueClient.exe
    - Overwatch.exe
    - RainbowSix.exe
    - RainbowSix_BE.exe
    - Deadlock.exe
    - HuntGame.exe
    - fragpunk.exe
    - Marvel-Win64-Shipping.exe
    - FortniteClient-Win64-Shipping.exe
    - TslGame.exe
    - PUBG-Win64-Shipping.exe
    - r5apex.exe
    - r5apex_dx12.exe
    - ModernWarfare.exe
    - Warzone.exe
    - cod.exe
    - BlackOps6.exe
    - bf4.exe
    - bf1.exe
    - bfv.exe
    - battlefield2042.exe
    - Wow.exe
    - WowClassic.exe
    - PathOfExile.exe
    - PathOfExile_x64.exe
    - RustClient.exe
    - rust.exe
    - EscapeFromTarkov.exe
    - EscapeFromTarkovArena.exe
    - DayZ.exe
    - arma3.exe
    - Phasmophobia.exe
    - DeadByDaylight.exe
    - GTA5.exe
    - rdr2.exe
    - SeaOfThieves.exe
    - ForzaHorizon5.exe
    - EAFC24.exe
    - EAFC25.exe 
    - Minecraft.exe
    - javaw.exe
    - java.exe
    - PartyAnimals.exe
    - PEAK.exe
    - Among Us.exe
    - helldivers2.exe
    - osu!.exe
    - eurotrucks2.exe
    - amtrucks.exe

    # === МОДЫ / RP СЕРВЕРЫ ===
    - FiveM.exe
    - altv.exe
    - altv-webengine.exe

    # === ЭМУЛЯТОРЫ (если используете) ===
    - HD-Player.exe
    - HD-Player2.exe
    - LDPlayer.exe
    - Nox.exe
    - Memu.exe
    - AndroidEmulator.exe

    # === АНТИЧИТЫ ===
    # Основные
    - EasyAntiCheat.exe
    - EasyAntiCheat_EOS.exe
    - BattleEye.exe
    - BEService.exe
    - BattleBitEAC.exe
    - TslGame_BE.exe
    - TslGame_ZK.exe
    - EscapeFromTarkov_BE.exe
    - EscapeFromTarkovArena_BE.exe
    - vgc.exe
    - vgm.exe
    - vgk.sys
    - vanguard.exe
    - start_protected_game.exe
    - denuvo-anti-cheat-update-service.exe
    - faceitservice.exe
    - faceitclient.exe
    - SGuard64.exe
    - SGuardSvc64.exe
    - SGuardUpdate64.exe
    - ACE-Service64.exe
    - GameMon.des
    - npggm.srv
    - TP3.exe
    - TPHelper.exe
    - Win64-Shipping.exe
    - Game.exe
    - Launcher.exe
    - Client.exe
    - Shipping.exe

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
    - "*.corp.*"
    - "+.mvideo.ru"
    - "*.corp.mvideo.ru"
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
    - https://1.1.1.1/dns-query#🌍 Global
    - https://8.8.8.8/dns-query#🌍 Global
    - tls://1.1.1.1#🌍 Global
    - tls://8.8.8.8#🌍 Global

proxies:
  - name: "⚪️🔵🔴 Без VPN"
    type: direct
    udp: true
  - name: DNS-OUT
    type: dns

proxy-groups:
  - name: 🔒 VPN
    icon: https://cdn.jsdelivr.net/gh/Koolson/Qure@master/IconSet/Color/Lock.png  
    type: select
    proxies:
      - 🎲 Auto
      - ⚪️🔵🔴 Без VPN

  - name: ▶️ YouTube
    icon: https://cdn.jsdelivr.net/gh/Koolson/Qure@master/IconSet/Color/YouTube.png
    type: select
    proxies:
      - 🔒 VPN

  - name: ➤ Telegram
    icon: https://cdn.jsdelivr.net/gh/Koolson/Qure@master/IconSet/Color/Telegram.png
    type: select
    proxies:
      - 🔒 VPN
      - ⚪️🔵🔴 Без VPN

  - name: 🌍 Global
    icon: https://cdn.jsdelivr.net/gh/Koolson/Qure@master/IconSet/Color/Global.png
    type: select
    proxies:
      - ⚪️🔵🔴 Без VPN
      - 🔒 VPN

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
      - 🔒 VPN

rule-providers:
  category-ads:
    type: http
    behavior: domain
    format: mrs
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/category-ads.mrs
    path: ./rule-sets/category-ads.mrs
    proxy: 🔒 VPN
    interval: 21600
  private:
    type: http
    behavior: domain
    format: mrs
    interval: 21600
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/private.mrs
    path: ./rule-sets/private.mrs
    proxy: 🔒 VPN
  private-ip:
    type: http
    behavior: ipcidr
    format: mrs
    interval: 21600
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/private-ip.mrs
    path: ./rule-sets/private-ip.mrs
    proxy: 🔒 VPN
  telegram:
    type: http
    behavior: domain
    format: mrs
    interval: 21600
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/telegram.mrs
    path: ./rule-sets/telegram.mrs
    proxy: 🔒 VPN
  telegram-ip:
    type: http
    behavior: ipcidr
    format: mrs
    interval: 21600
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/telegram-ip.mrs
    path: ./rule-sets/telegram-ip.mrs
    proxy: 🔒 VPN
  meta:
    type: http
    behavior: domain
    format: mrs
    interval: 21600
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/meta.mrs
    path: ./rule-sets/meta.mrs
    proxy: 🔒 VPN
  meta-ip:
    type: http
    behavior: ipcidr
    format: mrs
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/meta-ip.mrs
    path: ./rule-sets/meta-ip.mrs
    interval: 21600
    proxy: 🔒 VPN
  discord:
    type: http
    behavior: domain
    format: mrs
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/discord.mrs
    path: ./rule-sets/discord.mrs
    interval: 21600
    proxy: 🔒 VPN
  discord-ip:
    type: http
    behavior: ipcidr
    format: mrs
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/discord-ip.mrs
    path: ./rule-sets/discord-ip.mrs
    interval: 21600
    proxy: 🔒 VPN
  youtube:
    type: http
    behavior: domain
    format: mrs
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/youtube.mrs
    path: ./rule-sets/youtube.mrs
    interval: 21600
    proxy: 🔒 VPN
  google-deepmind:
    type: http
    behavior: domain
    format: mrs
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/google-deepmind.mrs
    path: ./rule-sets/google-deepmind.mrs
    interval: 21600
    proxy: 🔒 VPN
  google-play:
    type: http
    behavior: domain
    format: mrs
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/google-play.mrs
    path: ./rule-sets/google-play.mrs
    interval: 21600
    proxy: 🔒 VPN
  ru-blocked:
    type: http
    behavior: domain
    format: mrs
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/ru-blocked.mrs
    path: ./rule-sets/ru-blocked.mrs
    interval: 86400
    proxy: 🔒 VPN
  ru-blocked-ip:
    type: http
    behavior: ipcidr
    format: mrs
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/ru-blocked-ip.mrs
    path: ./rule-sets/ru-blocked-ip.mrs
    interval: 21600
    proxy: 🔒 VPN
  ru-blocked-community-ip:
    type: http
    behavior: ipcidr
    format: mrs
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/ru-blocked-community-ip.mrs
    path: ./rule-sets/ru-blocked-community-ip.mrs
    interval: 21600
    proxy: 🔒 VPN
  domain-list:
    type: http
    behavior: domain
    format: mrs
    url: https://github.com/Sn1pp1/mymihomofiles/raw/refs/heads/main/output/domain-list.mrs
    path: ./rule-sets/domain-list.mrs
    interval: 21600
    proxy: 🔒 VPN
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
  - RULE-SET,meta,🔒 VPN
  - RULE-SET,meta-ip,🔒 VPN
  - RULE-SET,discord,🔒 VPN
  - RULE-SET,discord-ip,🔒 VPN
  - PROCESS-NAME,Discord.exe,🔒 VPN
  - RULE-SET,youtube,▶️ YouTube
  - RULE-SET,google-deepmind,🔒 VPN
  - RULE-SET,google-play,🔒 VPN
  - RULE-SET,ru-blocked,🔒 VPN
  - RULE-SET,ru-blocked-ip,🔒 VPN
  - RULE-SET,ru-blocked-community-ip,🔒 VPN
  - RULE-SET,domain-list,🔒 VPN
  - MATCH,🌍 Global
```
</details>
