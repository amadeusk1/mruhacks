# Pengloo Party — branding and loading screen

The full game name is **Pengloo Party**. The earlier Pengloo-only logo is an archived draft.

## Assets

![[pengloo-party-logo.png]]

![[pengloo-party-icon.png]]

![[loading-screen-preview.png]]

The loading preview shows a simulated 42% download for design review. The shipped loader uses actual engine download progress; the percentage is not a timer.

## Implemented

- New transparent Pengloo Party wordmark, preserving the blue penguin, coral beanie, icy lettering and adding coral PARTY lettering.
- Separate simple penguin-head icon for browser tabs and app branding. Includes 32px favicon and 180px Apple touch icon.
- Custom web loading screen: snowy teal background, snowbank, readable progress bar, download percentage, preparation state, browser capability errors and retry button.
- Loader remains visible until the actual game title screen signals readiness. No fabricated initialization percentage.
- Game title, application icon, boot splash and title-menu wordmark use the new branding.
- Export script copies branding files outside the package, so the logo can appear before the large game download.
- Built-in image generation produced both artwork masters; favicon/touch icon are size derivatives. Original generated files remain preserved.

## Source files

Worktree: `/Users/nick/Documents/Codex/2026-10-23/make-a-new-obsidian-vault-on/pengloo-deployment`.

- `ui/branding/pengloo-party-logo.png`: transparent logo master.
- `ui/branding/pengloo-party-icon.png`: transparent icon master.
- `ui/branding/favicon-32.png`, `apple-touch-icon.png`: browser derivatives.
- `deploy/web/shell.html`: responsive loading screen and engine startup.
- `deploy/export_presets.cfg`: custom HTML shell selection.
- `deploy/build.sh`: builds and copies assets to `builds/web/branding`.
- `project.godot`: name, project icon and custom splash.
- `ui/screens/main_menu_screen.gd`: title logo and browser ready signal.

Use the deployment guide for builds and server updates. Keep HTML, JavaScript, package and branding together. Do not hand-edit the exported HTML as the permanent source.

## Remaining developer work

- Add a matching in-game loading overlay for room transitions and network reconnection. This initial loader handles engine startup, not every later scene load.
- Replace any older branding in independent branches, launchers, social banners and future platform packaging when those are integrated. This change is on `deploy/debian` / PR #3.
- Verify Safari, Firefox, mobile devices and real slow/interrupted connections. A mobile-sized layout check does not prove mobile gameplay support.
- Consider smaller download bundles and asset streaming; branding does not reduce the game package size.
- Add social-share artwork and platform-specific signed app icons when distributing native apps. This task does not create a PWA installer or native installer.
- Preserve required Godot and third-party license notices in credits/distribution. Replacing visual engine branding does not remove licensing obligations.

## Generation briefs

Logo edit: preserve the original turquoise snowy PENGLOO wordmark and beanie penguin; integrate a second coral line reading PARTY at about half the width, navy outlines, transparent background, no scenery.

Icon: one simplified front-facing blue penguin head with cream face, navy eyes, tiny golden beak and coral beanie; bold navy outline, minimal detail, no lettering, transparent background, legible at favicon sizes.

Technical reference: [Godot custom web HTML shell](https://docs.godotengine.org/en/4.4/tutorials/platform/web/customizing_html5_shell.html).

## Validation

Web and Linux release exports completed. A real Chromium session loaded the exported game through to the new title screen with no JavaScript/GDScript errors observed. The loading overlay disappeared after the title readiness callback. A simulated interrupted download exposed the retry button; a 390px-wide layout had no horizontal overflow. The preview is a captured implementation, not generated concept art.
