# wattRadar Releases

Dieses Repository enthält öffentliche Release-Pakete für wattRadar.

## Schnellstart

Stable installieren oder aktualisieren:

```bash
curl -fsSL https://raw.githubusercontent.com/ehive-dev/wattRadar-releases/main/install.sh | sudo bash
```

Pre-Release installieren:

```bash
curl -fsSL https://raw.githubusercontent.com/ehive-dev/wattRadar-releases/main/install.sh | sudo bash -s -- --pre
```

Bestimmte Version installieren:

```bash
curl -fsSL https://raw.githubusercontent.com/ehive-dev/wattRadar-releases/main/install.sh | sudo bash -s -- --tag v0.4.4
```

## Service

```bash
systemctl status wattRadar --no-pager
journalctl -u wattRadar -f
```

Health-Check lokal:

```bash
curl http://127.0.0.1:3011/healthz
```

## Version 0.4.4

PV-, Batterie- und Batterie-SoC-Gesamtwerte werden nicht mehr mit den
Einzelgeräten aus evcc gemittelt. Das korrigiert auch die daraus berechneten
kWh-Kennzahlen und Energieflüsse. Bei fehlenden oder unvollständigen
Gesamtwerten zeigt wattRadar einen Hinweis, statt unzuverlässige
Aggregatwerte auszugeben.

## Lizenz

Die Nutzung ist für private und nicht-kommerzielle Zwecke erlaubt. Kommerzielle Nutzung benötigt eine vorherige schriftliche Zustimmung von ehive. Siehe `LICENSE.txt` und `THIRD_PARTY_NOTICES.txt`.
