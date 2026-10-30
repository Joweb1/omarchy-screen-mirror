# Screen Mirror for Omarchy

Plug in a monitor and it shows exactly what your laptop shows. No second workspace, no
screen that follows you around while the laptop stays behind. Switch workspaces on the
laptop and the external monitor switches with it.

Prefer a separate desktop on the second monitor? The bar popup has an **Extend** button.
Your choice is remembered.

It runs as your normal user and never needs sudo.

## Install

```sh
omarchy plugin add https://github.com/Joweb1/omarchy-screen-mirror.git --enable
```

If the shell says it is not responding, it is reloading. Wait a few seconds and run the
same command again. Move the icon with
`omarchy bar move jovibe.screen-mirror --section left|center|right`.

Check a checkout before publishing:

```sh
omarchy plugin validate .
```

## Use

- Plug in a monitor. It mirrors the laptop screen within a second, and a notification
  confirms it.
- The bar icon appears while an external monitor is connected. Click it for the list of
  screens and the **Mirror** / **Extend** buttons.
- Unplug the monitor and everything goes back to normal.

The mirrored monitor runs at its own best resolution and shows your laptop picture scaled
to fit, so on a monitor with a different shape you may see bars at the sides.

## Settings

| Key | Default | Meaning |
|---|---|---|
| `alwaysShow` | `false` | Show the icon even when no external monitor is connected |
| `notify` | `true` | Send a notification when a monitor is connected |

## Requirements

| Needed | Why |
|---|---|
| Hyprland with the Lua config (the Omarchy default) | monitors are set with `hyprctl eval` |
| `python3` | the `screen-mirror` helper |
| `libnotify` (`notify-send`) | connect notifications |

Omarchy ships all of these.

## How it works

The widget starts `screen-mirror watch`, which listens on Hyprland's event socket. When a
monitor is added, or the Hyprland config reloads (a reload would otherwise forget the
setting), it waits for the burst of events to finish and then applies the saved mode with
`hl.monitor({ ..., mirror = "<laptop panel>" })`. Settings are runtime only: nothing in
`~/.config/hypr` is edited. The saved mode is one word in
`~/.local/state/omarchy/screen-mirror/mode`. No background service is installed.

The helper also works on its own:

```sh
~/.config/omarchy/plugins/jovibe.screen-mirror/screen-mirror status
~/.config/omarchy/plugins/jovibe.screen-mirror/screen-mirror set extend
```

The laptop panel is the first monitor named `eDP*`, `LVDS*` or `DSI*`, otherwise the first
monitor Hyprland lists.

## Remove

```sh
omarchy plugin remove jovibe.screen-mirror
rm -rf ~/.local/state/omarchy/screen-mirror   # optional: forget the saved mode
```

Monitors that are mirrored keep mirroring until you unplug them or run `hyprctl reload`.

## Troubleshooting

| Problem | Fix |
|---|---|
| Monitor is not mirrored | Open the popup and click **Mirror**. Check `screen-mirror status`. |
| Wrong picture shape | Mirroring scales the laptop picture to the monitor and keeps its shape. |
| A fixed layout from `monitors.lua` is ignored | Plugin settings override it until the next reload. Choose **Extend** to stop mirroring. |

## License

MIT
