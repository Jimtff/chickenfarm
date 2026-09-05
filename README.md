# Chicken Farm

Eine einheitliche Roblox-Benutzeroberfläche zur Automatisierung wiederkehrender Abläufe in Chicken Farm.

## Funktionen

- Hühner automatisch in Mengen von 1, 5, 25 oder 100 kaufen
- Eier abhängig vom aktuellen Multiplikator automatisch verkaufen
- Prozess- und Kaufstufen automatisch verbessern
- Gruppenbelohnung automatisch abholen
- Cash automatisch einsammeln
- Optionaler Anti-AFK-Modus
- Statistikansicht mit aktuellen Spielwerten und Eier/s
- Speicherbare Einstellungen, Fensterposition und frei wählbarer UI-Hotkey
- Responsive, scrollbare und für Maus sowie Touch geeignete Oberfläche

## Bedienung

1. Script starten.
2. Im Tab **Farm** die gewünschten Automatisierungen aktivieren.
3. Die Kaufmenge über eine der vier Mengenschaltflächen auswählen.
4. Den Verkaufsmultiplikator mit dem Slider zwischen **0,50x und 1,50x** einstellen.
5. Im Tab **Statistiken** die aktuellen Spielwerte ansehen.

Der Standard-Hotkey zum Ein- und Ausblenden der UI ist **Rechte Strg**. Er kann unter **Oberfläche** geändert werden. Während der Hotkey-Auswahl bricht ESC den Vorgang ab.

## UI-Schaltflächen

- Minus: Fenster minimieren
- Plus: Fenster wieder öffnen
- X: Script und alle Verbindungen sauber beenden
- **Position**: Fensterposition zurücksetzen
- **Alles**: Einstellungen auf Standardwerte zurücksetzen; anschließend das Script neu starten

## Einstellungen

Wenn die verwendete Umgebung readfile, writefile und isfile unterstützt, werden die Einstellungen in ChickenFarm_PlaceId.json gespeichert. Ohne Dateiunterstützung funktioniert das Script weiterhin, die Einstellungen gelten dann jedoch nur für die aktuelle Sitzung.

## Leistungsoptimierungen

- Remote-Aufrufe laufen getrennt voneinander und blockieren nicht mehr alle Automatisierungen.
- Gleichartige Remote-Aufrufe können nicht gleichzeitig doppelt ausgeführt werden.
- Eier werden nur verkauft, wenn tatsächlich Eier vorhanden sind.
- Die aufwendige Suche nach dem Rebirth-Fortschritt läuft nur im Statistik-Tab und höchstens alle zehn Sekunden.
- Fehlerwarnungen werden gedrosselt, damit die Konsole nicht überflutet wird.

## Fehler und Spielupdates

Die Statusleiste am unteren Rand zeigt erfolgreiche Aktionen, Wartezustände und Fehler. Wenn benötigte Spielobjekte beim Start fehlen, beendet sich das Script mit einer verständlichen Warnung.

Roblox-Spiele können Namen, UI-Pfade und Remote-Aufrufe jederzeit ändern. Nach einem Spielupdate müssen diese Pfade möglicherweise in main.lua angepasst werden.

## Version

Aktuell: **2.0.0**

### Änderungen in 2.0.0

- Oberfläche vollständig überarbeitet und vereinheitlicht
- Responsive Skalierung, Scrolling und Touch-Unterstützung
- Multiplikator-Slider und deaktivierte abhängige Einstellung
- Sichtbare Status- und Fehlermeldungen
- Übersichtliche Statistikansicht
- Zuverlässigerer Group-Reward-Timer
- Optimierter Rebirth-Scan
- Blockierungsfreie Remote-Worker
- Validierung und Versionierung der Einstellungen
- Minimieren, Schließen und Zurücksetzen ergänzt
