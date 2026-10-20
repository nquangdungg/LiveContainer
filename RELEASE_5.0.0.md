# LiveContainer Extended 5.0.0

| Component | Version |
|-----------|---------|
| **LiveContainer Extended** | `5.0.0` |
| **Embedded SideStore** | *(see build / IPA metadata)* |

Major Extended release: developer tools, atmosphere effects, safer cross-app links, and clearer multitask workflow.

> [!Warning]
> Standalone build needs **SideStore 0.6.2+** or **AltStore 2.2.1+**.  
> For `LiveContainer+SideStore.ipa`, use [Impactor](https://github.com/khcrysalis/Impactor) or [iloader](https://github.com/nab138/iloader).

## Downloads

| File | Description |
|------|-------------|
| **LiveContainer.ipa** | Standalone host |
| **LiveContainer+SideStore.ipa** | Host + embedded SideStore |

## New Features

- **Developer Mode** — enable from Settings with confirmation; app restarts; banner confirms when active
- **Custom guest app icons** (Developer Mode) — pick an image for the icon shown inside LiveContainer
- **Info.plist editor** (Developer Mode) — view/edit a guest app’s Info.plist as XML and save on disk
- **Background effect: Snow** — optional atmosphere overlay in Settings → Atmosphere
- **Cross-app URL schemes** — opening a link whose scheme belongs to another app installed in LiveContainer prompts to open that guest app
- **Temporary close / Multitask** — use multitask windows; minimize / PiP to set an app aside and return from the dock without force-quit
- **App Lock** — passcode + biometrics (Keychain)
- **Dashboard** — certificate & LocalDevVPN status, unified Install, layouts (List / Grid / Compact)

## Improvements

- Uninstall works consistently in List, Grid, and Compact layouts
- Release workflow can require both IPAs and show SideStore version in release notes
- English UI for Extended surfaces (developer tools, effects, prompts)

## Notes

- Custom icons affect **in-app** presentation; they do not replace the iOS Home Screen icon of LiveContainer itself
- Invalid Info.plist edits can break a guest app — use Developer Mode carefully
- **StikDebug / StikJIT** are not fully embedded in 5.0.0; use the linked upstream projects (iOS 17.4+) until built-in integration lands
- On-device pairing still follows SideStore / idevice rules (classic pairing via computer; RPPairing from iOS 17.4+)

## Credits

- **Lead Developer:** Nguyen Quang Dung  
- Based on [LiveContainer](https://github.com/LiveContainer/LiveContainer) and the SideStore ecosystem  
- Stik projects: [StikDebug](https://github.com/StikDebug/StikDebug) · [StikJIT](https://github.com/StikDebug/StikJIT)

---
**Full Changelog:** compare against previous tag on GitHub after push.
