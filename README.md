# cardebloat

Notes and tooling for cleaning up a cheap Android head unit (Camecho 7" VW unit).

## The device

| What | Value | Source |
|---|---|---|
| Listing | Camecho 2+64GB "Android 15" 7" for VW Golf 4 / T5 / Sharan | Amazon |
| SoC | AutoChips **AC8227L**, a rebranded MediaTek **MT8127** (4× Cortex-A7, 32-bit ARMv7) | About screen; mtkclient lists hw code `0x8127` as "MT8127/MT3367/AC8227L" |
| Android | **13** (not 15 as advertised), 32-bit | About screen |
| System build | `JCAC10003-OC2-V1.1.30R5-240718_1125-AC-C0` | About screen |
| MCU | `JCMM30-0-2024.06.09_23:12` | About screen |
| RAM / storage | 2 GB / 64 GB | About screen |
| Audio | TM2313 | About screen |
| Panel | LVDS 1024x600 | About screen |
| Bluetooth | 4.1 | About screen |
| CAN box | Simple Soft **RP5-VW-001**, SW V3.89.104BYPS, profile "Simple-Volkswagen-Magotan-2016~2019-All" | sticker + About screen |
| Chassis label | CY-CYC26-2501 | sticker |

The `JCAC10003-OC2` system build and `JCMM30` MCU pair is a common firmware family. XDA has threads
for these exact identifiers, including stock firmware (`AutoUpdate` folder plus an `MCU` folder on a
USB stick). That means a known-good image exists to recover with if something goes wrong.

## Can we interface with it?

**Yes.** There are three levels of access, from least to most invasive:

### 1. ADB (no root, fully reversible). Start here.

These units ship the stock Android developer options, plus a vendor "Factory settings" menu.

1. Settings → About → tap *Build number* 7× to enable Developer options. If the vendor hides it,
   open *Factory settings*. Codes reported for this firmware family, most likely first:
   - `1234` device/factory settings, `5678` Android/developer settings, `56789` service menu
     (reported for `JCAC10003` builds)
   - `000000`, or a code derived from the current date/time (AC8227L Android 13 reports), e.g.
     `7890` + current hour, `MMDD`, `YYYYMMDD`
   - generic: `8888`, `7788` (engineering), `3368`, `1617`, `126`, `1111`, `0000`, `123456`,
     `3711`, `8288`

   Only use these to open menus; don't change values you can't identify.
2. Enable **USB debugging**.
3. Connect, using one of these:
   - **Wi-Fi ADB**: put the unit and your laptop on the same network (a phone hotspot works), then
     run `adb connect <unit-ip>:5555`. Many of these ROMs listen on 5555 once debugging is enabled.
     On Android 13 the *Wireless debugging* pairing flow also works.
   - **USB**: in Factory settings, switch USB mode from *host* to *device* (OTG). Connect a
     **USB-A male-to-male** cable from the laptop to the **4-pin** USB lead on the back of the unit
     (not the 6-pin one; if one lead doesn't work, try the other). Switch it back to *host*
     afterwards, or CarPlay/USB sticks stop working.
4. Run `scripts/recon.sh`. It's read-only. It records the build properties, package list, memory
   use, and recent logs, which tell us whether the ROM is `userdebug` (where `adb root` may work
   with no exploit).

With plain ADB, debloating is already possible:
`pm disable-user --user 0 <pkg>` or `pm uninstall -k --user 0 <pkg>`. Both are undone with
`pm enable` / `cmd package install-existing <pkg>`, and nothing on the system partition changes.

### 2. Full flash access and root via MediaTek BROM (mtkclient)

The AC8227L is MediaTek silicon, so the boot ROM's download mode is available. The open-source
[mtkclient](https://github.com/bkerler/mtkclient) explicitly supports this chip
(`0x8127`, legacy DA, dedicated payload). That allows:

- a **full eMMC backup** (`mtk rl backup/`): do this before anything else,
- unlocking the bootloader (`mtk da seccfg unlock`),
- reading `boot`, patching it with Magisk (32-bit build), and writing it back, which gives **root**.

BROM is reached through the same rear 4-pin USB lead with a male-to-male cable, with the unit
powered off and then powered on while connected. A brick is recoverable via BROM + the backup
or the stock firmware.

### 3. A "new OS": not realistic

No LineageOS or AOSP port exists for AC8227L head units. Kernel sources aren't published, and the
MCU (buttons, power, illumination), the CAN box, the radio tuner and the TM2313 audio path all go
through closed vendor apps and services. The practical target is **stock firmware, debloated, with
a lean launcher**, and root if needed.

## About the actual problems

- **Not charging**: these units' USB ports usually supply 0.5–1 A, which is a hardware limit
  that software can't raise. Wired CarPlay at full screen brightness on a modern iPhone can drain
  faster than that. The fix is a separate 12 V USB-C PD charger, or wireless CarPlay plus
  a separate charger. Also check that the phone uses the lead going to the *USB* connector on the
  unit, not a camera/extension lead.
- **Crashes**: these come from the CarPlay app (ZLink, Carlink, or similar) and/or memory
  pressure (2 GB, 32-bit Android 13). ADB `logcat` captured right after a crash will tell us which.
  Debloating background vendor apps helps with memory.
- **CAN box profile**: it's set to "Magotan 2016–2019" (a Passat B8-era profile), which doesn't
  match the car. It's worth checking whether a closer VW profile exists in Factory settings →
  CAN. The wrong profile can cause odd behaviour with steering-wheel keys, ignition detection, and
  sleep/wake.

## Safety rules

- Take the full mtkclient backup before writing anything to flash.
- Never interrupt an MCU update (a known way to brick these units).
- Don't disable: the launcher (until a replacement is installed and set as default), the CarPlay
  app, the CAN/canbus service, the MCU/"car" service, SystemUI, Settings, or anything you can't
  identify. Disable things one at a time and test a drive in between.
