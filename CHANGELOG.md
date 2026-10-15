# Changelog

## 1.4.0
- 🌍 **English everywhere**: notifications, buttons, commands, messages, installer and documentation, so the whole company can use it. City names in the office list are in English (Turin, Milan, Rome…). `checkin-reminder notifications` replaces `notifiche`, which still works.
- 🔒 **New `checkin-reminder privacy` command**: shows the current permissions, what's kept on the Mac, and the only address the tool connects to.
- 🔒 **No more address lookups for Reply offices**: every office in the list now comes with its coordinates, so Apple's geocoder is only used for client sites you add without coordinates.
- 🔒 **Shorter log**: the log keeps only the last 30 days (`LOG_DAYS`), instead of growing forever.
- Notification texts no longer suggest the tool reads Desk Booking. It doesn't: it only knows what you tell it.
- `status` and `privacy` read permissions live from macOS. If you allow notifications again in System Settings after denying them, reminders go back to notifications instead of staying on the dialog window.
- Installer: `--help` also works with `curl … | bash -s -- --help`.
- New form to report an office that isn't recognized. It asks only for what's needed, and prints a diagnostic without network names.
- Automated tests, run on every build and before every release.
- `scripts/pubblica.sh` is now `scripts/publish.sh`.

## 1.3.2
- Icon: the app has a new identifier (`com.reply.checkin.notifier`), so macOS registers it from scratch and shows the right icon instead of the generic one. On first launch you need to grant the notification and location permissions again, and the "Alerts" style.
- Shorter texts and clearer buttons.

## 1.3.1
- The Inspector icon is now visible in the notification: the icon is generated with Apple's tools (`iconutil`), and the macOS icon cache is refreshed on every installation.
- Persistent notification: the installer opens the settings to choose the "Alerts" style (macOS doesn't let code set it). New command to open the notification settings; `status` warns about the Banner style.
- The publish script commits pending changes on its own.

## 1.3.0
- 📍 **Location**: besides the network, it recognizes Reply offices from the Mac's location (55 offices from reply.com, 250 m radius). The notification subtitle says which office you're at. The location stays on the Mac.
- 🧐 **The Check-in Inspector**: new icon and image in the notification.
- ✍️ **New rotating texts**, with a different tone if you had snoozed, and new button labels.
- New command `checkin-reminder where` (which office am I at?).
- Complete automatic updates: besides the script, the app and the office list update too.
- Test build on GitHub Actions on every push to `main`.

## 1.2.0
- The reminder is now a **notification at the top right** with actions to open the check-in page, mark it as done, or snooze for 15 minutes (app `CheckinNotifier.app` in `~/Applications`). Clicking the notification opens Desk Booking.
- The window in the center is still available (`REMIND_STYLE='dialog'` or `install.sh --dialog`), and it's the automatic fallback when notifications are denied.
- New command `checkin-reminder snooze [min]`.
- Automatic releases with GitHub Actions (universal arm64 + Intel app).
- ⚠️ Needs `checkin-reminder update` (it also updates the app): the automatic update replaces only the script.

## 1.1.0
- Office detection through the DNS domain of the Reply network (`replynet.prv`), on by default: it works even when macOS hides the Wi-Fi name, and over cable or dock.
- The Reply network reached over VPN from home doesn't trigger the reminder (`VPN_COUNTS_AS_OFFICE=1` to change this).
- Updates: `checkin-reminder update` command and daily automatic update (`AUTO_UPDATE=0` to turn it off).
- The configuration now holds only your customizations; the defaults arrive with updates.

## 1.0.0
- First version: Desk Booking check-in reminder when you're on the `reply-*` Wi-Fi.
