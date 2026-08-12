# MYA-L11 private mail platform

This deploys a free, local-first mail workflow on the Intel Mac:

- **listmonk** manages permission-based lists, opt-outs and campaigns.
- **Mailpit** captures every test message so a mistake cannot email real people.
- **Stalwart** is installed for future private mailboxes; its production identity
  stays in bootstrap mode until hostname, TLS and DNS are ready.
- **PostgreSQL** persists listmonk state.
- **Portainer** provides private container administration.
- **Cloudflare Tunnel** publishes only subscription and unsubscribe routes over
  HTTPS after a domain is connected; the listmonk admin UI stays private.
- **Brevo feedback sync** imports hard/soft bounces, spam complaints and provider
  unsubscribes into listmonk. Hard bounces and complaints are blocklisted after
  the first event.

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

The gate intentionally blocks until DNS, relay credentials, public HTTPS
unsubscribe routes, provider authentication, feedback processing and a
validated consent ledger are all working. No setting can guarantee inbox
placement; reputation also depends on recipient consent, complaint rate,
content and gradual sending history.

## Domain-ready layout

For a domain such as `example.com`, keep the roles separate:

- sending identity: `news.example.com`
- From address: `fuar@news.example.com`
- public subscription/unsubscribe host: `mail.example.com`
- private admin UI: the existing Tailscale URL only

Do not publish Stalwart SMTP/IMAP ports or add an MX record pointing at the
residential connection. Outbound delivery uses Brevo STARTTLS on port 587.

## Connect a domain

These steps are deliberately performed only after the domain is owned and the
Brevo and Cloudflare accounts exist.

1. Add the root domain to a free Cloudflare account. At the registrar, replace
   the nameservers with the two Cloudflare nameservers. If the domain already
   receives mail, copy every existing MX/TXT/CNAME record first; never delete or
   replace an existing mail record blindly.
2. In Cloudflare Zero Trust, create a remotely managed tunnel named
   `mya-l11-mail`. Add public hostname `mail.example.com` with service
   `http://public_gateway:8088`. Save the connector token, not the install
   command, in `.runtime/cloudflare-tunnel-token` with mode `0600`.
3. Create a Brevo account and generate an API key, SMTP key and SMTP login. Save
   the two keys in `.runtime/brevo-api-key` and `.runtime/brevo-smtp-key` with
   mode `0600`; do not paste them into Git, chat, or a shell command line.
4. Register the isolated sending subdomain and print the exact provider records:

   ```zsh
   mkdir -p .runtime && chmod 700 .runtime
   ./brevo_domain_onboard.py news.example.com .runtime/brevo-api-key
   ```

   Add every record printed by Brevo in Cloudflare DNS. Also publish one SPF TXT
   record on `news.example.com`: `v=spf1 include:spf.brevo.com mx ~all`. A name
   may have only one SPF record, so merge an existing one rather than adding a
   second. Leave the initial DMARC policy at `p=none` while reports are checked;
   move to `quarantine` and later `reject` only after all legitimate senders are
   aligned.
5. In listmonk Admin -> Users, create an API role containing only
   `bounces:get` and `webhooks:post_bounce`, then create API user
   `brevo-bounce`. Store its generated token in
   `.runtime/listmonk-bounce-token` with mode `0600`.
6. Copy `.production.env.example` to `.production.env` and replace the example
   domain, From identity, a real monitored Reply-To mailbox, the truthful legal
   sender/address footer, Brevo SMTP login and DKIM selector. Do not put secret
   values in that file.
7. Validate the recipient CSV. It must contain `email`, `name`, `permission`,
   `consent_source`, and ISO-8601 `consent_at` columns:

   ```zsh
   ./prepare_subscribers.py recipients.csv .runtime/import
   cp .runtime/import/consent-ledger.csv .runtime/consent-ledger.csv
   ```

   Purchased, scraped, unknown-source and non-permissioned rows are rejected.
   Import only `.runtime/import/subscribers.clean.csv` into a double-opt-in
   list.
8. After DNS has propagated and Brevo reports the domain as authenticated, run:

   ```zsh
   ./activate-production.zsh
   ```

   This first brings up the HTTPS-only public gateway, verifies Brevo API domain
   status, performs an SMTP login without sending, verifies the restricted
   listmonk feedback token and consent ledger, and only then switches listmonk
   away from Mailpit.

## First delivery audit

Production activation permits seed tests, not a bulk campaign. Send first to
inboxes you control at Gmail, Outlook and Yahoo. Inspect the received headers
and require `SPF=pass`, `DKIM=pass`, `DMARC=pass`, working visible and one-click
unsubscribe, correct From/Reply-To identity, and successful feedback sync. Keep
Gmail Postmaster spam rate below 0.3%; pause and investigate immediately on a
complaint spike or repeated deferrals. Start with a small, engaged segment and
increase volume gradually without sudden bursts.

## Sources

- Google sender requirements: https://support.google.com/mail/answer/81126
- Yahoo sender requirements: https://senders.yahooinc.com/faqs/
- Brevo Free-plan limits: https://help.brevo.com/hc/en-us/articles/208580669-FAQs-What-are-the-limits-of-the-Free-plan
- Brevo domain API: https://developers.brevo.com/reference/get-domain-configuration
- Brevo events API: https://developers.brevo.com/reference/get-email-event-report
- listmonk configuration: https://listmonk.app/docs/configuration/
- listmonk bounce processing: https://listmonk.app/docs/bounces/
- Cloudflare Tunnel: https://developers.cloudflare.com/tunnel/
- Stalwart Docker setup: https://stalw.art/docs/install/platform/docker/
