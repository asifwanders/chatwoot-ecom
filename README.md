# Chatwoot-Ecom

Chatwoot, tuned for online stores.

This is a soft fork of [Chatwoot](https://github.com/chatwoot/chatwoot) — the
open-source customer-conversation platform. It keeps everything Chatwoot can
do (shared inbox, multi-channel, automations, help center, reports) and adds
a handful of features that ecommerce teams ask for over and over again.

The fork stays small on purpose. Almost every change is a new file. The few
edits to upstream files are wrapped in clearly marked fences so future
Chatwoot updates merge cleanly.

---

## What's different from regular Chatwoot

### 1. WhatsApp via QR scan (no Meta business approval needed)

Add a WhatsApp inbox by scanning a QR code on your phone — the same way
WhatsApp Web works. Powered by [Evolution-API](https://github.com/EvolutionAPI/evolution-api)
under the hood, but your team never sees Evolution. They just see:

- "Add Inbox → WhatsApp → WhatsApp (QR Login)"
- Type a name and phone number
- Scan the QR with the phone running that WhatsApp account
- Done

If the connection drops (phone offline, session expired), the inbox shows a
red "Reconnect" banner. One click, scan again, you're back.

### 2. Schedule messages for later

Type a message, hit the clock icon next to Send, pick "+1 hour" or "Tomorrow
9am" or any custom time. It sits in a pending list above the composer.
Cancel anytime. Delivers automatically.

Also available as an **automation action** so rules can send follow-ups
("send a thank-you message 2 hours after order is delivered").

### 3. Agent signature on every message

Account setting toggle. When on, every reply from an agent is prefixed with
their name and team:

```
Asif Admin - Sales

Your order is on its way!
```

Customers always know who they're talking to. Private notes and system
activity stay untouched.

### 4. Return the chat to the original agent automatically

Common workflow: Sales answers an order question → hands off to Shipping →
Shipping marks the order as shipped → chat should bounce back to Sales for
the follow-up.

We added:

- An **assignment history** spine that records every reassignment
- A new automation condition: "custom attribute changed to <value>"
- New automation actions: "Assign to Previous Agent" / "Assign to Previous
  Team" with fallback strategies (round-robin, leave unassigned, keep
  current)

Build the full rule in Settings → Automation with zero code.

---

## Quick start (one VPS, Docker)

For a single-customer self-hosted deployment.

### Requirements

- Ubuntu 24.04 (or any Linux with Docker 24+)
- 2 GB RAM minimum, 4 GB recommended
- A domain pointed at the server

### Steps

```bash
git clone https://github.com/asifwanders/chatwoot-ecom.git
cd chatwoot-ecom
cp .env.example .env
# Fill in: SECRET_KEY_BASE, POSTGRES_PASSWORD, REDIS_PASSWORD,
#          FRONTEND_URL, EVOLUTION_API_KEY (openssl rand -hex 32)

docker compose -f docker-compose.fork.yaml build
docker compose -f docker-compose.fork.yaml up -d
docker compose -f docker-compose.fork.yaml exec rails bundle exec rails db:chatwoot_prepare
```

Then point your domain's nginx/Caddy to `127.0.0.1:3000` and grab a TLS
cert.

The first admin is created on the first visit to the site.

---

## Detailed docs

- `FORK_CHANGES.md` — exact list of every changed file and why
- `docker/install_evolution.md` — WhatsApp/Evolution operational notes
- `AGENTS.md` — development conventions (lint, test, commit style)
- Upstream Chatwoot docs still apply for everything not covered above:
  https://www.chatwoot.com/docs

---

## License

Same as upstream Chatwoot — see `LICENSE`.

The fork is permitted; the project remains open-source.

---

## A note about Evolution-API

Evolution-API is an unofficial WhatsApp Web bridge. It works well in
practice but it is not endorsed by Meta. WhatsApp can ban any phone number
using an unofficial connection. Best practice:

- Use a dedicated phone number, not your personal one
- Warm new numbers slowly (don't blast hundreds of messages on day one)
- Provide an upgrade path to the official WhatsApp Cloud API for customers
  who outgrow QR login (Chatwoot supports that natively)
