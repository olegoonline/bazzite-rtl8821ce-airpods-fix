# AirPods Pro 3 on Bazzite with a Realtek RTL8821CE Bluetooth adapter

Fix for Realtek **RTL8821CE** Bluetooth (USB ID **`13d3:3558`**, IMC Networks / AzureWave) on
Bazzite and other Fedora Atomic systems, where AirPods (tested: **AirPods Pro 3**) pair but never
get working audio.

> 🇷🇺 Russian version: [README.ru.md](README.ru.md)

## Symptoms

- AirPods show up as `"<Name>'s AirPods Pro – Find My"`; *Connect* does nothing.
- `bluetoothctl pair` succeeds, but `connect` fails with `br-connection-busy`,
  `br-connection-canceled`, `br-connection-refused`, `br-connection-page-timeout` or `Connection timeout`.
- `pactl list cards short` never shows a `bluez_card.…` for the AirPods; no output device in the sound menu.
- `journalctl -u bluetooth` shows `avdtp_connect_cb() … Permission denied (13)` / `Host is down (112)`.
- `btmon` shows `Encryption Change … Status: LMP Response Timeout (0x22)` followed by
  `Disconnect … Reason: Authentication Failure (0x05)`, plus `unexpected start frame` garbage.
- Other Bluetooth devices (keyboard, speaker) work fine.

Check whether you have this adapter:

```
lsusb | grep -i 13d3:3558
journalctl -k -b | grep -i "RTL:"
```

## Cause

Two separate problems:

1. **The kernel does not recognise `13d3:3558` as Realtek**, so `btusb` never uploads the
   controller firmware (no `RTL: loading rtl_bt/rtl8821c_fw.bin` lines in the log).
   An upstream patch exists — *"Bluetooth: btusb: Add Realtek RTL8821CE device 13d3:3558"*,
   bluetooth-next commit `809a66378e9e` — but has not reached the Bazzite kernel yet (7.2.7 at the time of writing).
2. **The RTL8821C firmware in linux-firmware (`0x75b8f098`, December 2022) fails link encryption with AirPods Pro 3.**
   Realtek's current Windows driver (16.4033.2312.2503, which explicitly lists `USB\VID_13D3&PID_3558`)
   ships a newer firmware (`0xd7c83bcf`) in the same format. With it the adapter reports
   Bluetooth 5.0 instead of 4.2 and AirPods connect with audio.

## What this fix does

- Downloads the Realtek Windows driver **from Microsoft's own Update Catalog**, extracts the RTL8821C
  firmware and verifies its SHA-256. Nothing proprietary is redistributed in this repository.
- Adds the kernel argument `firmware_class.path=/var/lib/airpods-bt/fw`, so the kernel prefers that
  firmware. Only `rtl8821c_fw.bin` is overridden; everything else still comes from `/usr/lib/firmware`.
- If the running kernel does not know `13d3:3558`, builds `btusb` with the ID added inside a Podman
  container (sources from kernel.org for your exact kernel version, headers from the preinstalled
  `kernel-devel`) and loads it at boot.
- **After every kernel update** the module is rebuilt automatically on the next boot.
  Once your kernel includes the upstream patch, the module step switches itself off and only the firmware is used.
- Nothing in `/usr` is modified. Secure Boot must be **disabled** (the module is unsigned).

## Install

```
git clone https://github.com/olegoonline/bazzite-rtl8821ce-airpods-fix
cd bazzite-rtl8821ce-airpods-fix
sudo ./install.sh
```

The first run downloads a Fedora build container and the driver (a few minutes).
Then **shut the computer down completely** (not reboot), wait 10 seconds and power it on.
The controller keeps the old firmware in RAM across warm reboots.

Verify:

```
journalctl -k -b | grep -i "RTL:" | tail -3     # → fw version 0xd7c83bcf
systemctl status airpods-bt-fix.service
```

Then pair the AirPods from scratch. Type the commands **one at a time** and keep the case lid open,
with the setup button held until the light flashes white. Turn Bluetooth off on your iPhone first:

```
bluetoothctl remove <AIRPODS_MAC>
bluetoothctl
[bluetoothctl]> scan on          # wait for "AirPods Pro"
[bluetoothctl]> scan off
[bluetoothctl]> pair <AIRPODS_MAC>     # wait for "Pairing successful"
[bluetoothctl]> trust <AIRPODS_MAC>
[bluetoothctl]> connect <AIRPODS_MAC>
```

```
pactl list cards short                                     # bluez_card.XX_XX_… should appear
pactl set-card-profile bluez_card.XX_XX_XX_XX_XX_XX a2dp-sink
```

## Uninstall

```
sudo ./uninstall.sh
```

Then shut down and power on.

## Tips

- Don't use the KDE "Add device" wizard and `bluetoothctl` at the same time, and don't leave `scan on`
  running while connecting. Both cause `br-connection-busy`.
- `ControllerMode = bredr` in `/etc/bluetooth/main.conf` hides the BLE "Find My" duplicates, but it is not required.
- Logs: `journalctl -u airpods-bt-fix -b`.

## Tested on

Bazzite 44 (kernel 7.2.7-ogc1.1.fc44), BlueZ 5.87, PipeWire, KDE Plasma, AirPods Pro 3,
adapter `13d3:3558` (RTL8821CE, `lmp_subver 0x8821`, `hci_rev 0x000c`).
Reports for other RTL8821CE IDs (`0bda:c821`, `13d3:3529`, …) are welcome.
The firmware part may help them too, but the module part only applies to `13d3:3558`.

## Disclaimer

Provided as is. The firmware is loaded into the controller's RAM only; nothing is flashed, and
`uninstall.sh` plus a cold boot restores the stock state.
