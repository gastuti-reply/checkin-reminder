# Check-in reminder on iPhone

There's no iPhone app, but your iPhone can remind you by itself with Apple's **Shortcuts** app, which is already on every iPhone. It takes about two minutes and there's nothing to install.

**How it works:** when you arrive at your office, iOS shows a notification asking whether to run "Check in on Desk Booking". Tap it and Desk Booking opens. Already checked in? Just ignore it.

## Privacy

- Nothing from this project runs on your iPhone: it's an automation you create yourself in Apple's Shortcuts app.
- Your iPhone itself notices that you've arrived. Nobody receives anything: not Reply, not your manager, not the author of this tool.
- You can change or delete it at any time.

## 1. Create the shortcut

1. Open the **Shortcuts** app and tap **+** to create a new shortcut.
2. Add the **Open URLs** action (search for it), and type this URL: `https://deskbooking.reply.com/home`
3. Name the shortcut **Check in on Desk Booking**. This is the text you'll see in the reminder.

## 2. Add the trigger

Your iOS version is in Settings → General → About → iOS Version.

### iOS 27

1. In the shortcut, tap **Edit**, then **Automation**.
2. Choose **Arrive**.
3. Tap **Choose** and search for your office address (all addresses are in [offices.tsv](../offices.tsv)). Drag the blue circle on the map so it covers the building.
4. Choose **Time Range** and set, for example, 7:00 to 12:00, so it doesn't ask again when you come back from lunch.

Don't turn on **Allow Running When Locked** in the shortcut's settings: the automation would run silently, without asking, and that question is your reminder.

### iOS 26 or earlier

1. In Shortcuts, open the **Automation** tab and tap **+** (then **Create Personal Automation**, if you see it).
2. Choose **Arrive**.
3. Tap **Choose** and search for your office address (all addresses are in [offices.tsv](../offices.tsv)). Drag the blue circle on the map so it covers the building.
4. Choose **Time Range** and set, for example, 7:00 to 12:00, so it doesn't ask again when you come back from lunch.
5. If you're offered a choice, keep the option that asks you before running, not "Run Immediately". Tap **Next**.
6. Pick the **Check in on Desk Booking** shortcut and tap **Done**.

## Good to know

- **More than one office?** Add an Arrive trigger for each one.
- **Location access:** if iOS asks to let Shortcuts use your location, allow it. That's how it knows you've arrived.
- **Prefer not to use location?** Use the **Wi-Fi** trigger instead of Arrive, and choose your office network (your iPhone must have joined it at least once). It asks every time the iPhone connects to that network, so it may ask more than once a day.
- **It can take a few minutes** after you arrive.
- **Compared with the Mac version** there are no "Already done" or "Later" buttons: if you've already checked in, ignore the notification.
- **To remove it**, open the shortcut and remove the trigger, or delete the shortcut. On iOS 26 or earlier, swipe left on the automation in the Automation tab and tap Delete.

Using a Mac? The full version for Mac is on the [main page](../README.md).
