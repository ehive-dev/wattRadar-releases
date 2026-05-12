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
curl -fsSL https://raw.githubusercontent.com/ehive-dev/wattRadar-releases/main/install.sh | sudo bash -s -- --tag v0.4.1
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

## Lizenz

Die Nutzung ist für private und nicht-kommerzielle Zwecke erlaubt. Kommerzielle Nutzung benötigt eine vorherige schriftliche Zustimmung von ehive. Siehe `LICENSE.txt` und `THIRD_PARTY_NOTICES.txt`.
