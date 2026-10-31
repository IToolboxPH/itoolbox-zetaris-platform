# itoolbox-zetaris-platform

**The data harness for the IToolbox Ecosystem Platform: Zetaris, run locally.**

> One login, one dashboard, every tool.

The IToolbox agent reaches data only through Zetaris. Zetaris federates read-only
SQL to the source databases, so the data stays where it is and is governed there,
locally, before anything moves to the cloud. This repo is the Zetaris platform
bundle (release 2.4.3.1, hackathon build) as IToolbox runs it.

| Repo | Contains |
| --- | --- |
| `itoolbox-backend` | FastAPI service and the agent; calls this harness's API on :8888 |
| `itoolbox-frontend` | Next.js web app |
| **itoolbox-zetaris-platform** (this) | Zetaris: query engine, catalog, API |
| `itoolbox-data-platform` | TimescaleDB and JupyterLab for analysis |

The bundle's own documentation is in [ZETARIS.md](ZETARIS.md): sizing, tuning the
query engine, JDBC, and what to do when something fails.

---

## Running it

```bash
cp .env.example .env                       # then set ZETARIS_ADMIN_PASSWORD
docker login zetarishackathon.azurecr.io   # the command from the Zetaris Cloud download page
./preflight.sh                             # Docker memory, CPUs, disk, registry sign-in
docker compose pull                        # about 4 GB
docker compose up -d                       # first start: 5-10 minutes
./verify.sh                                # nine checks, ending with a query through the stack
```

Then open <http://localhost:3001> and sign in as `admin@zetaris.com`. On Windows, run
the `.sh` scripts from Git Bash.

| Port | Service | Bound to |
| --- | --- | --- |
| 3001 | Zetaris UI | 127.0.0.1 |
| 8888, 8889 | Zetaris API (public, internal) | 127.0.0.1 |
| 10000 | Query engine (JDBC) | 127.0.0.1 |
| 4040 | Spark UI | 127.0.0.1 |

`docker compose down` stops it and keeps the data. **Never run
`docker compose down -v` on a working install**: it deletes the metastore, the
registered data sources and the field-encryption keypair, and with them every
stored data source credential.

## Changes from the stock bundle

- **UI on port 3001**, not 3000, which another app on the host already uses.
  `UI_PORT`, `ALLOWED_ORIGINS` and `GUI_URL` in `.env` must agree.
- **No sample data.** The bootstrap job registers the bundle's `NY_TAXI` and
  `TPCDS_DB` samples only when `ZETARIS_SEED_SAMPLE_DATA=true` in `.env`; IToolbox
  leaves it `false`.
- **UI bound to 127.0.0.1** in `docker-compose.yml`, like every other port. Over
  plain HTTP the UI only works at localhost anyway.
- **`.env` is not committed.** It holds the admin password; `.env.example` is the
  same file without it.
- **Compose project `itoolbox_zetaris-platform`**, so Docker Desktop lists it with
  the other IToolbox stacks (`itoolbox_backend`, `itoolbox_frontend`,
  `itoolbox_data-platform`). The stock `name: zetaris` also named the containers
  and volumes, so those are pinned in `docker-compose.yml` instead: containers
  `zetaris-postgres`, `zetaris-driver`, `zetaris-api`, `zetaris-ui`,
  `zetaris-init`, `zetaris-bootstrap`, and volumes `zetaris_pgdata`,
  `zetaris_driver-data` and the rest, the names an install from the stock bundle
  already has.
- **LF line endings, enforced by `.gitattributes`.** The scripts in `init/` run
  inside Linux containers, and a Windows checkout with CRLF breaks the first start
  with `$'\r': command not found`.

## Data sources

BantAI's data is loaded into `itoolbox-data-platform`'s TimescaleDB first, governed
there, and registered here one Postgres schema per data source, through a read-only
database role. Each registration is recorded under `datasources/`, without
passwords, so the setup can be rebuilt.

| Source | What | From |
| --- | --- | --- |
| `WEATHER` | Current weather, 5-day/3-hour forecast and air quality for 24 Philippine cities, loaded hourly from OpenWeather | itoolbox-data-platform, schema `weather` |

[datasources/itoolbox-data-platform.sql](datasources/itoolbox-data-platform.sql) records
the registration.

## How itoolbox-backend connects

itoolbox-backend calls this harness's API, at `http://host.docker.internal:8888`
from its container, with a Zetaris API key: `ZETARIS_API_KEY` in its own `.env`.
Create a key as a Zetaris admin with `POST /api/v1.0/auth/api-key` (body: `name`,
`expiryDate`). The key in use, `itoolbox-agent`, expires on 31 December 2026.

The API's reference is at <http://localhost:8888/redoc/index.html>, behind the
Zetaris admin's username and password.
