# itoolbox-zetaris-data-harness

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
| **itoolbox-zetaris-data-harness** (this) | Zetaris: query engine, catalog, API |

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

- **UI on port 3001**, not 3000, which nm-web already uses on the machine this
  runs on. `UI_PORT`, `ALLOWED_ORIGINS` and `GUI_URL` in `.env` must agree.
- **UI bound to 127.0.0.1** in `docker-compose.yml`, like every other port. Over
  plain HTTP the UI only works at localhost anyway.
- **`.env` is not committed.** It holds the admin password; `.env.example` is the
  same file without it.
- **LF line endings, enforced by `.gitattributes`.** The scripts in `init/` run
  inside Linux containers, and a Windows checkout with CRLF breaks the first start
  with `$'\r': command not found`.

## Data sources

| Source | What | From |
| --- | --- | --- |
| `NM_RAN` | Radio access network: sites, outages, 4G/5G KPIs, Ookla | nm-data-platform TimescaleDB, schema `ran` |
| `NM_STUDIES` | Weekly capacity studies | nm-data-platform TimescaleDB, schema `studies` |
| `NY_TAXI`, `TPCDS_DB` | Bundled samples | Zetaris's public S3 bucket |

[datasources/nm-data-platform.sql](datasources/nm-data-platform.sql) records how
NM_RAN and NM_STUDIES were registered, through a read-only database role, so the
setup can be rebuilt. It holds no passwords.

## How itoolbox-backend connects

itoolbox-backend calls this harness's API, at `http://host.docker.internal:8888`
from its container, with a Zetaris API key: `ZETARIS_API_KEY` in its own `.env`.
Create a key as a Zetaris admin with `POST /api/v1.0/auth/api-key` (body: `name`,
`expiryDate`). The key in use, `itoolbox-agent`, expires on 31 December 2026.

The API's reference is at <http://localhost:8888/redoc/index.html>, behind the
Zetaris admin's username and password.
