# AirPods Pro 3 на Bazzite с Bluetooth-адаптером Realtek RTL8821CE

Исправление для Bluetooth **Realtek RTL8821CE** (USB ID **`13d3:3558`**, IMC Networks / AzureWave)
на Bazzite и других Fedora Atomic. Без него AirPods (проверено на **AirPods Pro 3**) сопрягаются, но звук так и не появляется.

## Симптомы

- AirPods видны как `«<Имя>'s AirPods Pro – Find My»`, кнопка *Connect* ничего не делает.
- `pair` проходит, а `connect` падает с `br-connection-busy`, `canceled`, `refused`, `page-timeout` или `Connection timeout`.
- В `pactl list cards short` нет `bluez_card.…`, в меню звука нет устройства вывода.
- В логах `Permission denied (13)` / `Host is down (112)`. Без загруженной прошивки `btmon` показывает
  `Encryption Change … LMP Response Timeout (0x22)` → `Authentication Failure (0x05)`, а с прошивкой из linux-firmware
  соединение рвётся по `Connection Timeout (0x08)`, и аудио не поднимается.
- Клавиатура, колонка и другие Bluetooth-устройства при этом работают.

Проверить, тот ли у тебя адаптер: `lsusb | grep -i 13d3:3558`.

## Причина

1. **Ядро не знает, что `13d3:3558` — это Realtek**, и не загружает в него прошивку.
   Патч уже принят в bluetooth-next (`809a66378e9e`), но до ядра Bazzite пока не дошёл.
2. **С прошивкой RTL8821C из linux-firmware (`0x75b8f098`, декабрь 2022) AirPods Pro 3 всё равно не работают:**
   сопряжение проходит, но соединение рвётся по таймауту, и аудио не поднимается.
   В актуальном Windows-драйвере Realtek (16.4033.2312.2503, в нём прямо указан `VID_13D3&PID_3558`) лежит
   более новая прошивка `0xd7c83bcf` в том же формате. С ней адаптер работает как Bluetooth 5.0 вместо 4.2, и AirPods подключаются со звуком.

## Что делает исправление

- Скачивает Windows-драйвер Realtek **из каталога Microsoft Update**, извлекает прошивку и проверяет SHA-256.
  Сама прошивка в репозитории не хранится.
- Добавляет параметр ядра `firmware_class.path=/var/lib/airpods-bt/fw`. Подменяется только `rtl8821c_fw.bin`.
- Если ядро не знает `13d3:3558`, собирает исправленный `btusb` в контейнере Podman и загружает его при старте.
- **После обновления ядра модуль пересобирается сам** при следующей загрузке. Когда патч попадёт в ядро,
  сборка отключится сама, и останется только прошивка.
- `/usr` не трогается. Secure Boot должен быть **выключен**.

## Установка

```
git clone https://github.com/olegoonline/bazzite-rtl8821ce-airpods-fix
cd bazzite-rtl8821ce-airpods-fix
sudo ./install.sh
```

Затем **полностью выключи компьютер** (не перезагрузка), подожди 10 секунд и включи.
Проверка: `journalctl -k -b | grep -i "RTL:" | tail -3` должна показать `fw version 0xd7c83bcf`.

Потом сопряги AirPods заново, вводя команды **по одной**: `remove`, белое мигание на кейсе,
`scan on`, `scan off`, `pair`, `trust`, `connect`. Bluetooth на iPhone должен быть выключен,
а мастер добавления устройств KDE закрыт.

## Советы

- После первого сопряжения подключай наушники через значок Bluetooth на панели, а можно просто достать их из кейса:
  доверенные AirPods подключатся сами. Мастер «+» для уже сопряжённых наушников не используй, он пытается сопрячь их заново.
- Если *Connect* на панели не срабатывает, наушники, скорее всего, спали в кейсе. Достань их и попробуй ещё раз.
- Держи Bluetooth на iPhone поблизости выключенным, иначе AirPods уйдут к нему.
- Подключение занимает около 10–15 секунд. Для AirPods на Linux это нормально: наушники просыпаются, и поднимаются
  два профиля, музыка (A2DP) и гарнитура (HFP). Чтобы ускорить на несколько секунд, включи быстрый режим:
  ```
  sudo sed -i 's/^#\?\s*FastConnectable\s*=.*/FastConnectable = true/' /etc/bluetooth/main.conf
  grep -q '^FastConnectable' /etc/bluetooth/main.conf || sudo sed -i '/^\[General\]/a FastConnectable = true' /etc/bluetooth/main.conf
  sudo systemctl restart bluetooth
  ```
  Если подключение длится 30 секунд и дольше, а в `journalctl -u bluetooth` видно `Hands-Free … timed out`,
  можно отключить гарнитурный профиль, но тогда перестанет работать микрофон AirPods:
  ```
  mkdir -p ~/.config/wireplumber/wireplumber.conf.d
  printf 'monitor.bluez.properties = {\n  bluez5.roles = [ a2dp_sink a2dp_source ]\n}\n' > ~/.config/wireplumber/wireplumber.conf.d/51-a2dp-only.conf
  systemctl --user restart wireplumber
  ```

## Удаление

`sudo ./uninstall.sh`, затем выключить и включить компьютер.
