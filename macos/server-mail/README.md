# MYA-L11 private mail platform

This deploys a free, local-first mail workflow on the Intel Mac:

- **listmonk** manages permission-based lists, opt-outs and campaigns.
- **Mailpit** captures every test message so a mistake cannot email real people.
- **Stalwart** is installed for future private mailboxes; its production identity
  stays in bootstrap mode until hostname, TLS and DNS are ready.
- **PostgreSQL** persists listmonk state.
- **Portainer** provides private container administration.

All published container ports bind to loopback. Reach them through Tailscale or
an SSH tunnel; do not open them on the router. The installer uses Tailscale
Serve TCP proxies for the private web ports and never enables Funnel.

## Install on MYA-L11

```zsh
cd macos/server-mail
chmod +x ./*.zsh
./bootstrap-secrets.zsh
./server-components-ensure.zsh
./install-launch-agent.zsh
./test-local-delivery.zsh
```

The LaunchAgent runs at login and every five minutes. It starts Colima only
while AC power is available and ensures the containers are present. Existing
containers remain alive when the charger is removed so the Mac battery can act
as a short UPS.

Private URLs on the current tailnet:

- listmonk: `http://100.106.212.28:9000`
- Mailpit: `http://100.106.212.28:8025`
- Stalwart bootstrap: `http://100.106.212.28:8080/admin`
- Portainer: `https://100.106.212.28:9443`

Secrets are generated once in `.env` with mode `0600`. The repository ignores
that file. Never paste it into an issue, chat, email or commit.

## Production relay decision

Do not send directly from the residential IP. It has no controllable matching
PTR/rDNS and outbound TCP/25 is blocked. Use an authenticated relay on port 587.
For the current free stage, Brevo is the practical default (300 messages/day on
its Free plan); move to a paid relay if the legitimate opted-in volume grows.

Use a separate marketing subdomain such as `news.redmono.com`. Keep the existing
IONOS MX/SPF records for normal `@redmono.com` mail untouched. In the relay:

1. Add and authenticate `news.redmono.com`.
2. Publish the exact DKIM and SPF records the relay provides.
3. Publish `_dmarc.news.redmono.com` initially with `p=none` and aggregate
   reports, then enforce only after all legitimate senders align.
4. Create an SMTP key, store it only in the local listmonk settings, and use
   STARTTLS on `smtp-relay.brevo.com:587`.
5. Enable provider bounce/complaint webhooks and listmonk suppression handling.
6. Keep double opt-in, a visible unsubscribe link and one-click unsubscribe.
7. Send only to documented opt-in recipients, start with seed inboxes and warm
   volume gradually.

Run the production gate before any real test:

```zsh
./mail-preflight.zsh news.redmono.com <provider-dkim-selector>
```

The gate intentionally blocks until DNS, relay credentials, unsubscribe,
bounces, complaints and consent are explicitly confirmed. No setting can
guarantee inbox placement.

## Sources

- Google sender requirements: https://support.google.com/mail/answer/81126
- Brevo Free-plan limits: https://help.brevo.com/hc/en-us/articles/208580669-FAQs-What-are-the-limits-of-the-Free-plan
- listmonk configuration: https://listmonk.app/docs/configuration/
- Stalwart Docker setup: https://stalw.art/docs/install/platform/docker/
