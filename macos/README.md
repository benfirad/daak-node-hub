# daakLOLILE for macOS

This menu bar app reads the daakLOLILE API over a private Tailscale connection. It shows Windows hardware, Tor/Snowflake traffic, Folding@home, BOINC, and RIPE Atlas state, and it can switch among the constrained Windows power profiles.

## Build

On macOS 13 or newer:

```zsh
xcode-select --install
zsh build.command
```

The script creates and opens `build/daakLOLILE.app`. Enter the Windows PC's Tailscale IP in the app.

For the Intel Mac server, copy `node-config.example.json` to
`~/Library/Application Support/DAAK/node-config.json` and replace the example
addresses with private Tailnet/direct-link values. This local file is required
for server reachability, service shortcuts and Wake-on-LAN; it must not be
committed because it contains device-specific network identifiers.

The app stores only the selected host in macOS user defaults. It can read status and request one of four predefined power modes; it cannot edit Tor settings, attach external volunteer-computing accounts, or execute arbitrary commands. Tor, Snowflake, Folding@home, BOINC, RIPE Atlas, and the hardware collector continue to run on the Windows PC, not on the Mac.

## Updates

Run `zsh install.command` once. The installed app then checks the repository's
`main` branch at launch and every six hours. When the commit changes, it downloads
that exact source archive, builds it locally with Apple's Swift compiler, verifies
the ad-hoc code signature, keeps the previous app as a rollback copy, replaces the
bundle in `/Applications`, and relaunches itself. Device-specific configuration in
`~/Library/Application Support/DAAK` remains untouched.

The bottom of the menu shows the installed version and commit, plus a manual
**Kontrol et** / **Güncelle** action. Automatic checks do not download or rebuild
anything while the installed commit already matches `main`.

## Broadcast quality

The **Yayın** panel can persistently select either **1080p60** or **1440p60**
before a broadcast starts. The bundled controller applies the matching OBS
canvas, output resolution, scene bounds, and Thunderbolt intermediate bitrate
atomically. Quality changes are disabled while a stream is active. The
Tailscale fallback remains a separate 1080p30 profile.

The app bundle also carries the matching Intel receiver script for reviewed
deployment to MYA-L11. Device addresses, credentials, OBS profiles, scene
collections, and broadcast keys remain local runtime configuration and are not
committed.
