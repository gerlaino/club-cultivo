# Cultivo Espacial — Frontend

Vue 3 SPA for the Cultivo Espacial platform: B2B SaaS for managing cannabis clubs (REPROCANN, Argentina).

## Stack

| | Version |
|---|---|
| Node | >=20.19 |
| Vue | 3.5 |
| Vite | 7 |
| Vue Router | 4 |
| Pinia | 3 |
| Bootstrap | 5.3 |
| Chart.js | 4 |
| Test runner | Vitest 3 + @vue/test-utils |

## Local setup

```sh
# 1 — Start the full stack (backend + DB + Redis)
docker compose up

# 2 — Install frontend deps (if running outside Docker)
npm install

# 3 — Dev server (port 5173, proxies API to :3001)
npm run dev
```

## Seed credentials

All seeded accounts use password `123456Aa`.

| Email | Role |
|---|---|
| `super@clubcultivo.app` | super_admin |
| `admin@mitocondriaclub.org` | admin |
| `medico@mitocondriaclub.org` | medico |
| `cultivador@mitocondriaclub.org` | cultivador |
| `dispensador@mitocondriaclub.org` | dispensador |
| `manicurador@mitocondriaclub.org` | manicurador |

## Scripts

```sh
npm run dev        # hot-reload dev server
npm run build      # production build (dist/)
npm run test:unit  # run Vitest tests
npm run lint       # ESLint
```

## Docs

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — folder structure, data model, permissions, critical flows
- [`docs/CHANGELOG.md`](docs/CHANGELOG.md) — implementation history by block
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — upcoming features H–K
