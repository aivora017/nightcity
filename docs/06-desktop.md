# 06 — The desktop

Hyprland, a terminal, a launcher, a bar and a browser.

---

## 1. Install

```bash
sudo pacman -S hyprland kitty wofi waybar firefox
```

| Package | Role |
|---|---|
| `hyprland` | Wayland compositor with animations, blur, rounded corners, glow borders |
| `kitty` | GPU-accelerated terminal |
| `wofi` | Application launcher, Wayland-native and lighter than rofi |
| `waybar` | Status bar |
| `firefox` | Browser — also the thing that makes pasting an SSH key trivial |

When asked which package should provide `ttf-font`, choose **`2) noto-fonts`**. Noto has
the broadest Unicode coverage including Devanagari.

Then the supporting pieces:

```bash
sudo pacman -S xdg-desktop-portal-hyprland polkit-kde-agent qt5-wayland qt6-wayland \
  ttf-jetbrains-mono-nerd noto-fonts-emoji
```

| Package | Role |
|---|---|
| `xdg-desktop-portal-hyprland` | Lets applications do screen sharing and native file dialogs |
| `polkit-kde-agent` | The authentication popup for privileged actions |
| `qt5-wayland` / `qt6-wayland` | Qt apps run natively on Wayland instead of through X compatibility |
| `ttf-jetbrains-mono-nerd` | The font — includes the icon glyphs Waybar needs |
| `noto-fonts-emoji` | Emoji coverage |

This is a large install: ~184 packages, ~987 MB installed. If a mirror stalls, see
[TROUBLESHOOTING](TROUBLESHOOTING.md#a-mirror-stalls-mid-download).

---

## 2. Launch

```bash
Hyprland
```

**Capital H.** On first run you get a welcome dialog. Click *"Thanks, but I don't need
help"* — the tutorial teaches defaults we are about to replace.

If the mouse is not working yet, press **Super + C** to close the focused window, or
**Super + M** to exit Hyprland entirely and return to the text console.

### Default keybinds (before customisation)

| Key | Action |
|---|---|
| `Super + Q` | Open terminal (kitty) |
| `Super + R` | Open launcher (wofi) |
| `Super + C` | Close active window |
| `Super + M` | **Exit Hyprland** |
| `Super + J` / `Super + K` | Cycle focus between windows |
| `Super + 1…9` | Switch workspace |
| `Super + drag` | Move window |

---

## 3. Where the config lives

> **Recent Hyprland versions generate a Lua config, not the older `.conf` format.**
>
> The file is `~/.config/hypr/hyprland.lua`. The warning bar across the top of a fresh
> Hyprland session tells you the exact path — read it rather than assuming.
>
> The two formats are **not** interchangeable. Pasting `.conf` syntax into a `.lua` file
> breaks it, and vice versa.

`.conf` format:

```
input {
    kb_layout = us
    touchpad {
        natural_scroll = true
    }
}
```

Lua format — note the `=` after each block name and the **trailing commas**:

```lua
hl.config({
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        sensitivity = 0,

        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
            disable_while_typing = true,
            clickfinger_behavior = true,
        },
    },
})
```

Lua identifiers cannot contain hyphens, so it is `tap_to_click`, **not** `tap-to-click`.

`clickfinger_behavior = true` means one finger is left click, two fingers right click,
three fingers middle click — better than corner-based clicking on a small pad.

---

## 4. Editing configs safely

> **Back up before every edit.**
>
> ```bash
> cp ~/.config/hypr/hyprland.lua ~/.config/hypr/hyprland.lua.bak
> ```
>
> Restore instantly if something breaks:
>
> ```bash
> cp ~/.config/hypr/hyprland.lua.bak ~/.config/hypr/hyprland.lua
> ```

> **Never replace the whole file with just the section you are changing.** The default
> config is ~367 lines containing monitor setup, keybinds, `exec-once` entries, decoration
> and animation settings. Deleting all of that to keep only an `input` block leaves a
> desktop with **no way to open a terminal**.
>
> Use `Ctrl+W` in nano to jump straight to the section you want, edit those lines, and
> leave everything else alone.

If you do wipe it, the recovery is simple — delete the file and let Hyprland regenerate a
fresh default:

```bash
rm ~/.config/hypr/hyprland.lua
Hyprland
```

### Hyprland validates on save

Hyprland reloads automatically when you save, and prints errors in a red bar at the top:

```
Your config has errors:
/home/sourav/.config/hypr/hyprland.lua:226: unknown config key 'input.touchpad.tap_to_clcik'
```

**It names the exact bad key and the exact line number.** Read that before doing anything
else — it usually contains the entire answer.

---

## 5. Clipboard

Wayland needs a clipboard tool, and terminal copy shortcuts differ from what you expect:

```bash
sudo pacman -S wl-clipboard
```

| Action | Shortcut |
|---|---|
| Copy in kitty | `Ctrl + Shift + C` |
| Paste in kitty | `Ctrl + Shift + V` |
| Paste in GUI apps | `Ctrl + V` |

> **`Ctrl+C` in a terminal sends an interrupt signal — it does not copy.** If you launched
> Firefox from that terminal, `Ctrl+C` kills Firefox.

Launch GUI apps detached so terminal signals cannot reach them:

```bash
firefox &
disown
```

`&` backgrounds it; `disown` detaches it from the terminal entirely.

To get a file straight into the clipboard without selecting anything:

```bash
wl-copy < ~/.ssh/id_ed25519.pub
```

---

## 6. GitHub over SSH

GitHub stopped accepting account passwords for git operations in 2021. If you signed up
with Google you have no password to use anyway. SSH keys are the cleanest route and do not
expire.

```bash
sudo pacman -S openssh
ssh-keygen -t ed25519 -C "your@email.com"
```

`ed25519` is a modern, fast, secure key type. Press Enter for the default path
(`~/.ssh/id_ed25519`), then Enter twice for no passphrase — reasonable on a personal
laptop.

```bash
wl-copy < ~/.ssh/id_ed25519.pub
```

> **`id_ed25519.pub` is the public key — safe to share.** `id_ed25519` without `.pub` is
> the private key. Never paste that anywhere. If you do, delete the pair and regenerate.

On github.com: avatar → **Settings** → **SSH and GPG keys** → **New SSH key** → title it
`nightcity` → click the key field → `Ctrl+V` → **Add SSH key**.

The key is one long line beginning `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI...` and ending
with your email comment. **Keep the email** — it is a normal part of the format.

> **Do not transcribe the key by hand.** It is ~100 characters of base64 where `l`/`1`/`I`
> and `0`/`O` are visually ambiguous. Several attempts at manual transcription failed
> during this build. Install Firefox first and copy-paste it.

Connect the repo:

```bash
cd ~/nightcity
git remote add origin git@github.com:USERNAME/nightcity.git
ssh -T git@github.com     # type 'yes' at the fingerprint prompt
git push -u origin main
```

If you already added an `https://` remote, change it rather than adding again:

```bash
git remote set-url origin git@github.com:USERNAME/nightcity.git
git remote -v             # verify both fetch and push show git@
```

---

## 7. Dotfiles with GNU Stow

Configs live in the repo and are symlinked into `~/.config`. Editing a config edits the
repo file, `git diff` shows exactly what changed, and a bad change is one `git checkout`
away from being undone.

```bash
sudo pacman -S stow
```

Structure — each top-level directory mirrors the path relative to `$HOME`:

```
nightcity/
├── hypr/.config/hypr/hyprland.lua
├── waybar/.config/waybar/config
├── waybar/.config/waybar/style.css
├── kitty/.config/kitty/kitty.conf
└── scripts/.local/bin/
```

Move an existing config in and link it back:

```bash
cd ~/nightcity
mkdir -p hypr/.config/hypr
mv ~/.config/hypr/hyprland.lua hypr/.config/hypr/
stow hypr
```

`stow hypr` creates `~/.config/hypr/hyprland.lua` as a symlink to the repo copy. Verify:

```bash
ls -la ~/.config/hypr/
```

You should see an arrow pointing into `~/nightcity`.

To undo: `stow -D hypr`.

---

## 8. Watch your memory

On 4 GB this is the number that matters:

```bash
free -h
```

| State | Approximate RAM used |
|---|---|
| Text console only | ~740 MB |
| Hyprland + kitty | ~1.0–1.2 GB |
| \+ Firefox, a few tabs | 2.5 GB and climbing |

zram absorbs a lot, but the browser is where this machine will feel its age. If you ever
spend money on this project, **RAM is the single best upgrade** — most i5-7200U laptops
take DDR4 and have a free slot.

---

## Next

- [ ] Waybar config and CSS
- [ ] Cyberpunk colour palette (neon cyan / magenta / yellow on deep black)
- [ ] Kitty theming
- [ ] `swww` for animated wallpapers
- [ ] Hyprlock + Hypridle
- [ ] SwayNC notifications
- [ ] Eww widgets
- [ ] Zsh + Starship prompt
