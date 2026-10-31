-- How BantAI's data sources were registered in Zetaris, from itoolbox-data-platform.
-- No passwords here: zetaris_ro's lives only inside Zetaris, encrypted.
--
-- Source: itoolbox-data-platform's TimescaleDB, database itoolbox_db, on the host at
-- port 5436. One Zetaris data source per Postgres schema: without a `schema` option
-- Zetaris scans only `public` and registers nothing.

-- ── 1. In itoolbox_db, as its owner (itoolbox) ───────────────────────────────
-- A login that can read the registered schemas and nothing else. Generate the
-- password, use it once below, and do not store it anywhere else.
DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'zetaris_ro') THEN CREATE ROLE zetaris_ro LOGIN; END IF;
END $$;
ALTER ROLE zetaris_ro WITH LOGIN PASSWORD '<generated>';
GRANT CONNECT ON DATABASE itoolbox_db TO zetaris_ro;

-- Per schema. Default privileges cover tables the ingest job creates later.
GRANT USAGE ON SCHEMA weather TO zetaris_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA weather TO zetaris_ro;
ALTER DEFAULT PRIVILEGES FOR ROLE itoolbox IN SCHEMA weather GRANT SELECT ON TABLES TO zetaris_ro;

-- ── 2. In Zetaris, over JDBC as the admin (2026-10-31) ───────────────────────
-- The UI's query box accepts SELECT only, so run these from DBeaver or another
-- JDBC client. DESCRIBE BY allows letters, digits, spaces and _ . - , only.
CREATE DATASOURCE WEATHER DESCRIBE BY "OpenWeather observations, forecasts and air quality for Philippine cities, itoolbox-data-platform, read-only" OPTIONS (
  jdbcdriver "org.postgresql.Driver",
  jdbcurl "jdbc:postgresql://host.docker.internal:5436/itoolbox_db",
  username "zetaris_ro",
  password "<generated>",
  schema "weather"
);
REGISTER DATASOURCE TABLES FROM WEATHER;

-- Check:
--   SHOW DATASOURCES
--   SHOW TABLES IN WEATHER                  -- air_quality, forecasts, locations, observations
--   SELECT COUNT(*) FROM WEATHER.observations
--
-- A new table in the schema needs `REGISTER DATASOURCE TABLES FROM WEATHER` again.
-- A new schema needs its own GRANTs above and its own data source.
--
-- To remove:
--   In Zetaris:     DROP DATASOURCE WEATHER;
--   In itoolbox_db: DROP OWNED BY zetaris_ro; DROP ROLE zetaris_ro;
