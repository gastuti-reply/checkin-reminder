<p align="center">
  <img src="notifier/art/icon-1024.png" width="140" alt="The Check-in Inspector">
</p>

<h1 align="center">Check-in Reminder</h1>

<p align="center">
  <b>Your Mac notices when you arrive at a Reply office<br>and reminds you to check in on Desk Booking.</b><br>
  One notification, one click, done. Then it leaves you alone until tomorrow.
</p>

<p align="center">
  <a href="#install">Install</a> ·
  <a href="#privacy">Privacy</a> ·
  <a href="#faq">FAQ</a> ·
  <a href="CHANGELOG.md">What's new</a> ·
  <a href="../../releases/latest">Latest release</a>
</p>

---

> [!NOTE]
> **Mac only for now** (macOS 11 or later, Apple Silicon and Intel). There is no Windows version yet: if you'd like to build one, pull requests are welcome. On iPhone you can get a similar reminder with the Shortcuts app: see the [iPhone guide](docs/iphone-shortcuts.md).

## Why it exists

Checking in on [Desk Booking](https://deskbooking.reply.com/home) ("Where are you today?") is how the group measures how much we actually use our offices, and those numbers drive decisions about space and desks. **If recorded occupancy stays below a certain threshold, we can't ask for more space**, even when the office is crowded.

That's why the check-in matters **every time you're in the office**. A day at the office without a check-in doesn't exist in the company's data. It takes ten seconds, but between a coffee and a call it's easy to forget.

Check-in Reminder remembers for you. It runs quietly in the background and speaks up only when **you're at the office and haven't confirmed today's check-in**.

## Privacy

**It runs entirely on your Mac and reports to no one.** There is no server, no account and no analytics. Nobody receives anything from it: not Reply, not your manager, not the author.

| | |
|---|---|
| **Permissions** | Only two, both shown by macOS: **Notifications**, and **Location** (optional). It does not ask for files, contacts, calendar, camera, microphone, screen recording, Accessibility, Full Disk Access or an admin password. |
| **Location** | Used for one question only: "am I within 250 m of a Reply office?" It is read on workdays between 7:00 and 20:00, at most every 10 minutes, and **not at all once you've checked in for the day** (or when you run `where`, `status` or `test` yourself). Your coordinates are never saved, logged or sent anywhere. Only the answer is kept. |
| **Desk Booking** | It never logs in, never reads your bookings and never checks in for you. It doesn't even know whether you checked in: you tell it, with **Already done**. |
| **What stays on your Mac** | Today's state (checked in or snoozed), the last location answer (at an office or not, and the nearest office), your settings, and a troubleshooting log that keeps only the last 30 days. Nothing else. |
| **Network** | A daily check for updates on GitHub, with no account and no identifiers ([details](#updates)). It makes no other connections, with one optional exception: a client site you add without coordinates is looked up once with Apple's geocoder ([Customize](#customize)). |
| **Code** | Open source and small: a bash script and a Swift helper app. Everything it does is in this repository. |

Your position comes from **macOS Location Services**, the same system Maps uses. The app gets it from macOS, compares it with the office list, and discards it. If you prefer not to share it, deny the permission: the reminder keeps working through the office network.

### Check it yourself

1. **In Terminal**, run `checkin-reminder privacy`. It shows the current permissions, what's kept on your Mac, and the only address it connects to.
2. **In System Settings**:
   - **Notifications → Check-in**: whether notifications are allowed, and their style (Alerts or Banners).
   - **Privacy & Security → Location Services → Check-in**: if the switch is on, location is allowed. An arrow appears next to it when it was used recently.
   - **General → Login Items & Extensions → Allow in the Background** ("Login Items" on older macOS): the background service that checks every 5 minutes whether you're at the office. It can be listed as "checkin-reminder" or as "bash", because the service is a script.
3. **In the code**: [`bin/checkin-reminder`](bin/checkin-reminder) holds all the logic, and [`notifier/main.swift`](notifier/main.swift) is the helper app that shows the notification and reads the location.

## Install

Open **Terminal** (press ⌘ Space and type "Terminal"), then paste:

```bash
curl -fsSL https://raw.githubusercontent.com/gastuti-reply/checkin-reminder/main/install.sh | bash
```

It takes about a minute and needs no admin password: everything is installed in your user folder. Along the way:

1. macOS asks to allow **notifications** from "Check-in": choose **Allow**.
2. macOS asks for your **location**: choose **Allow**. It's optional, but it recognizes the office even when you aren't on the Reply network (phone hotspot, guest Wi-Fi, an office whose network it doesn't know).
3. The notification settings open: set the style to **Alerts**, so the reminder stays on screen until you answer. With "Banners" it disappears after a few seconds.

Then try it:

```bash
checkin-reminder test
```

That's all. Updates are automatic.

<details>
<summary>Prefer to read the installer before running it?</summary>

```bash
curl -fsSL https://raw.githubusercontent.com/gastuti-reply/checkin-reminder/main/install.sh -o install.sh
less install.sh
bash install.sh
```

It creates only these files:

| Path | What it is |
|---|---|
| `~/.local/bin/checkin-reminder` | the script |
| `~/Applications/CheckinNotifier.app` | the helper app, shown as "Check-in" |
| `~/Library/LaunchAgents/com.reply.checkin-reminder.plist` | the background service |
| `~/.config/checkin-reminder/config` | your settings |
| `~/.local/share/checkin-reminder/offices.tsv` | the office list |
| `~/Library/Application Support/checkin-reminder/` | today's state, the last location answer |
| `~/Library/Logs/checkin-reminder.log` | the log (last 30 days) |

If `~/.local/bin` isn't on your PATH yet, it also adds one line to `~/.zshrc`.
</details>

<details>
<summary>Other ways to install</summary>

- **From a download**: get `checkin-reminder-x.y.z.zip` from the [latest release](../../releases/latest), unzip it and run `./install.sh` from the folder.
- **From a clone**: `git clone` the repo, then run `./install.sh`. With Apple's developer tools installed (`xcode-select --install`), the helper app is built on your Mac from the source.
- **Installer options**: `--dialog` (a window in the center instead of the notification), `--no-auto-update`, `--url '<url>'`, `--ssid '<regex>'`, `--dns '<regex>'`, `--uninstall`.
</details>

## What you see

When you arrive at the office, a notification appears at the top right:

> **Time to check in**<br>
> Reply Turin · Via Nizza<br>
> It takes ten seconds on Desk Booking.
>
> `Open Desk Booking` · `Already done` · `Later`

| Action | What happens |
|---|---|
| **Open Desk Booking** (or click the notification) | Opens Desk Booking. You're done for today. |
| **Already done** | No more reminders until tomorrow. |
| **Later** | Reminds you again in 15 minutes. |
| Ignore it | It comes back after 15 minutes. |

The wording changes each time, so it doesn't fade into background noise. Outside working hours (Mon–Fri, 7:00–20:00), at home or on VPN you get nothing.

## How it knows you're at the office

It uses two clues, and either one is enough:

1. **The Reply network.** The Mac is on the corporate network, over `reply-*` Wi-Fi or a cable or dock (DNS domain `replynet.prv`). The same network reached **over VPN from home doesn't count**.
2. **Location.** The Mac is within 250 m of one of the [55 Reply offices](https://www.reply.com/en/offices) worldwide. This helps when the network isn't enough: a phone hotspot, guest Wi-Fi, or an office whose network it doesn't recognize.

The notification also tells you which office it found.

## Updates

You don't need to do anything. Once a day the tool downloads the `VERSION` file from this repository on GitHub. When there's a new version, it downloads the script and the office list from the repository, and the helper app from its releases. These are plain HTTPS downloads: no account, no cookies, and nothing about you or your Mac beyond what any download involves (GitHub sees your IP address). The maintainer sees only what GitHub shows for every public project: how many times each release was downloaded, as a single number, with no names or addresses.

To update right away, run `checkin-reminder update`. To decide yourself when to update, set `AUTO_UPDATE=0` ([Customize](#customize)) and run `checkin-reminder update` when you want. Every change is public in the commit history and the [changelog](CHANGELOG.md).

## Commands

| Command | What it does |
|---|---|
| `checkin-reminder test` | Shows the notification now, to try it |
| `checkin-reminder where` | Which office am I at? |
| `checkin-reminder privacy` | Permissions, what's kept on this Mac, network connections |
| `checkin-reminder status` | Full diagnostics: network, location, permissions, today's state |
| `checkin-reminder done` | Marks today's check-in as done |
| `checkin-reminder snooze 30` | Postpones the reminder by 30 minutes |
| `checkin-reminder notifications` | Opens the notification settings (to choose "Alerts") |
| `checkin-reminder config` | Customize hours, days, radius, texts |
| `checkin-reminder update` | Updates to the latest version now |
| `checkin-reminder uninstall` | Removes everything (`--purge` also removes your settings) |

## Customize

`checkin-reminder config` opens your settings file. Every commented line uses the default value: remove the `#` only from what you want to change.

```bash
WORKDAYS='1 2 3 4 5'      # days (1 = Monday … 7 = Sunday)
START_HOUR=7              # reminders from 7:00…
END_HOUR=20               # …until 20:00
SNOOZE_MINUTES=15         # how long "Later" waits
OFFICE_RADIUS=250         # meters from the office
LOCATION_CHECK=1          # 0 = never use the location
VPN_COUNTS_AS_OFFICE=0    # 1 = remind me on VPN from home too
REMIND_STYLE='banner'     # 'dialog' = a window in the center of the screen
TITLE='…' MESSAGE='…'     # fixed texts instead of the rotating ones
AUTO_UPDATE=1             # 0 = update only by hand
LOG_DAYS=30               # how many days the log keeps
```

**Often at a client site?** Add it to `~/.config/checkin-reminder/offices.tsv`, one line per site, with tabs between the fields: `name`, `address`, `latitude`, `longitude`. If you leave out the coordinates, the app asks Apple's geocoder for them once, sending the site's address (never your position), and caches the result.

## FAQ

**Can my manager, HR or Reply see where I am through this tool?**
No. Nothing leaves your Mac, and there is no server that could collect anything. The only record of your presence is the Desk Booking check-in you make yourself.

**Is there an iPhone version?**
Not as an app, but your iPhone can remind you when you arrive at the office with Apple's Shortcuts app, with nothing to install: follow the [iPhone guide](docs/iphone-shortcuts.md).

**Do I have to allow location?**
No. Without location you still get the reminder whenever the Mac is on the Reply network, over Wi-Fi or a cable. Location only helps when you use a different network at the office, such as a phone hotspot or guest Wi-Fi.

**The notification disappears after a few seconds.**
Its style is "Banners". Run `checkin-reminder notifications` and choose **Alerts**. macOS doesn't let apps choose this for you.

**I'm at the office but nothing happens.**
Run `checkin-reminder status` and look at the *At the office now* line. If it says "no", check the *Location* and *DNS domains* lines. If location shows as denied, allow it in System Settings → Privacy & Security → Location Services → Check-in. If your office is missing from the list, add it as described in [Customize](#customize). Then [report it](../../issues/new?template=office-not-recognized.yml) so we can add it for everyone; the form asks only for what's needed.

**I already checked in on my phone.**
Press **Already done**, or run `checkin-reminder done`. The tool doesn't read Desk Booking, so it can't know on its own.

**Will it remind me on VPN from home?**
No. The Reply network reached over VPN is recognized and ignored.

**Why does it show up as "bash" in Login Items?**
The background service is a shell script, and macOS sometimes lists it under the name of the program that runs it. It's the same service: `checkin-reminder privacy` shows its name and when it runs.

**Is the helper app signed?**
It's built from [`notifier/main.swift`](notifier/main.swift) by GitHub Actions, with public build logs, and signed ad hoc: it isn't notarized by Apple. That's why the installer removes the download quarantine flag, so macOS lets it run. If you'd rather build it yourself, install from a clone with Apple's developer tools installed.

**Does it drain the battery?**
No. Each check takes a fraction of a second, and location is read only during working hours, at most every 10 minutes.

**How do I remove it?**
Run `checkin-reminder uninstall`. It removes the service, the app, the script, the office list, the state and the log. Add `--purge` to also delete your settings. If the installer added `~/.local/bin` to your PATH in `~/.zshrc`, that line stays, since other tools may use it.

---

## For maintainers

<details>
<summary>How it works</summary>

- **`bin/checkin-reminder`** is a bash script and does all the thinking. A user LaunchAgent runs it on every network change, at login and every 5 minutes. It exits right away when you're outside working hours, already checked in, snoozed, or not at an office.
- **`notifier/` → `CheckinNotifier.app`** (Swift, in `~/Applications`) shows the notification with its actions, reads the location (CoreLocation) and reports the current permissions. Coordinates stay in memory: the app writes only the answer.
- **`offices.tsv`** is the office list, from reply.com, with coordinates. Offices without coordinates (for example a user's client sites) are geocoded once from their address with Apple's geocoder and cached.
- **`notifier/art/draw_icon.py`** generates the icon and the Inspector image. The build makes the `.icns` with `iconutil`.
- State and log: `~/Library/Application Support/checkin-reminder/` and `~/Library/Logs/checkin-reminder.log`.

```
bin/checkin-reminder       main script (CLI + periodic check)
notifier/                  notification and location app (Swift), icon, image
offices.tsv                Reply offices
install.sh                 installer / full update
scripts/publish.sh         push + build + release + local update, in one command
scripts/release.sh         version, tag and push only
scripts/build-notifier.sh  builds the app
scripts/stats.sh           aggregate download counts (how many Macs use it)
tests/run.sh               tests for the script and the office list
.github/workflows/         tests + test build on main, Release on tags
.github/ISSUE_TEMPLATE/    "my office isn't recognized" form
```

**Tests**: `bash tests/run.sh` runs in under a second, with no dependencies and without touching your installation. Every test gets an empty temporary HOME, and fakes replace the clock and the network. They also check `offices.tsv`, so a pull request that adds an office with a typo fails the build. GitHub Actions and `scripts/release.sh` run them too.

**Adoption**: `scripts/stats.sh` shows how many times each release of the app was downloaded. Every installed Mac downloads each new release once, so a few days after a release the number is close to the number of Macs using the tool. These are GitHub's aggregate counters: nothing identifies anyone.
</details>

<details>
<summary>Publishing a new version</summary>

1. Add a `## x.y.z` section to `CHANGELOG.md`.
2. Run `scripts/publish.sh x.y.z`. The script:
   - commits pending changes;
   - pushes and waits for the test build on GitHub Actions;
   - creates the tag and waits for the Release, built by Actions as a universal arm64 + Intel app;
   - updates your own installation.

   It needs the `gh` CLI, authenticated with the `workflow` scope.
3. Users get the new version within 24 hours.

Mention `checkin-reminder update` in the CHANGELOG only if the release changes `install.sh` or the LaunchAgent. If you move the repo, update `DEFAULT_REPO_RAW` in `install.sh`.

Automatic updates install whatever is on `main` once `VERSION` changes, on every Mac that runs the tool. Keep `main` protected (pull requests with review) when more people get write access.
</details>
