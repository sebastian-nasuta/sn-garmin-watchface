# SN Minimal — Garmin Watch Face

Minimalistyczna cyfrowa tarcza dla zegarka **Garmin Forerunner 970** (`fr970`, 454×454 AMOLED) na czystym czarnym tle (`#000000`) z logo **SN**.

## Funkcje
- **Logo SN** na górze tarczy (biały wariant z czerwonym akcentem)
- **Zegar cyfrowy** (`HH:MM`, tryb 12/24h z ustawień zegarka)
- **Data i pogoda** (`DZIEŃ DATA MIESIĄC · °C/°F`)
- **Kroki** + minimalistyczny pasek postępu dziennego celu
- **Bateria** (ikona + procent)
- **Always-On Display (AOD)** — przygaszony zegar z delikatnym przesunięciem pikseli co minutę (ochrona matrycy AMOLED przed wypalaniem)

## Wymagania i budowanie (Connect IQ SDK)
1. Zainstaluj [Garmin Connect IQ SDK Manager](https://developer.garmin.com/connect-iq/sdk/) oraz profil urządzenia `fr970`.
2. Wygeneruj klucz deweloperski (`developer_key.der`) — plik jest ignorowany przez `.gitignore`.
3. Skompiluj dla symulatora:
   ```bash
   monkeyc -d fr970 -f monkey.jungle -o bin/sn-watchface.prg -y /ścieżka/do/developer_key.der
   ```
4. Uruchom symulator i załaduj tarczę:
   ```bash
   connectiq &
   monkeydo bin/sn-watchface.prg fr970
   ```
