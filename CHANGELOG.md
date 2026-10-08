# Changelog

## 1.2.0
- Il promemoria ora è una **notifica in alto a destra** con le azioni "Apri check-in", "Fatto" e "Tra 15 min" (app `CheckinNotifier.app` in `~/Applications`). Clic sulla notifica = apri Desk Booking.
- La finestra al centro resta disponibile (`REMIND_STYLE='dialog'` o `install.sh --dialog`) ed è il ripiego automatico se le notifiche sono negate.
- Nuovo comando `checkin-reminder snooze [min]`.
- Release automatiche con GitHub Actions (app universale arm64 + Intel).
- ⚠️ Richiede `checkin-reminder update` (aggiorna anche l'app): l'aggiornamento automatico sostituisce solo lo script.

## 1.1.0
- Rilevamento dell'ufficio tramite dominio DNS della rete Reply (`replynet.prv`), attivo di default: funziona anche quando macOS nasconde il nome della Wi-Fi e via cavo/dock.
- La rete Reply raggiunta via VPN da casa non fa scattare il promemoria (`VPN_COUNTS_AS_OFFICE=1` per cambiarlo).
- Aggiornamenti: comando `checkin-reminder update` e aggiornamento automatico giornaliero (`AUTO_UPDATE=0` per disattivarlo).
- La configurazione ora contiene solo le personalizzazioni; i default arrivano con gli aggiornamenti.

## 1.0.0
- Prima versione: promemoria check-in su Desk Booking quando si è sulla Wi-Fi `reply-*`.
