-- How BantAI's data sources were registered in Zetaris, from itoolbox-data-platform.
-- No passwords here: zetaris_ro's lives only inside Zetaris, encrypted.
--
-- Source: itoolbox-data-platform's TimescaleDB, database itoolbox_db, on the host at
-- port 5436. One Zetaris data source per Postgres schema: without a `schema` option
-- Zetaris scans only `public` and registers nothing.
--
--   Zetaris source   schema      what
--   WEATHER          weather     OpenWeather observations, forecasts, air quality; NASA POWER daily history
--   BULLETINS        bulletins   PAGASA bulletins, wind signals, rainfall advisories (self-hosted BagyoAPI)
--   HAZARDS          hazards     USGS earthquakes, GDACS alerts, Project NOAH hazard per city
--   TYPHOONS         typhoons    IBTrACS storms inside PAR since 1951, tracks, closest passes per city
--   REFERENCE        reference   PSGC places, PSA province population, OpenStreetMap facilities

-- ── 1. In itoolbox_db, as its owner (itoolbox) ───────────────────────────────
-- A login that can read the registered schemas and nothing else. Generate the
-- password, use it once below, and do not store it anywhere else. Changing it
-- means dropping and re-creating every data source below with the new one.
DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'zetaris_ro') THEN CREATE ROLE zetaris_ro LOGIN; END IF;
END $$;
ALTER ROLE zetaris_ro WITH LOGIN PASSWORD '<generated>';
GRANT CONNECT ON DATABASE itoolbox_db TO zetaris_ro;

-- Per schema (repeat for weather, bulletins, hazards, typhoons, reference). Default
-- privileges cover tables the ingest jobs create later.
GRANT USAGE ON SCHEMA weather TO zetaris_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA weather TO zetaris_ro;
ALTER DEFAULT PRIVILEGES FOR ROLE itoolbox IN SCHEMA weather GRANT SELECT ON TABLES TO zetaris_ro;

-- ── 2. In Zetaris, over JDBC as the admin (2026-11-01) ───────────────────────
-- The UI's query box accepts SELECT only, so run these from DBeaver or another
-- JDBC client. DESCRIBE BY allows letters, digits, spaces and _ . - , only.
-- Every source uses the same OPTIONS except `schema`:
--   OPTIONS (jdbcdriver "org.postgresql.Driver",
--            jdbcurl "jdbc:postgresql://host.docker.internal:5436/itoolbox_db",
--            username "zetaris_ro", password "<generated>", schema "<schema>")
CREATE DATASOURCE WEATHER DESCRIBE BY "OpenWeather observations, forecasts and air quality, and NASA POWER daily history, for 24 Philippine cities, itoolbox-data-platform, read-only" OPTIONS (
  jdbcdriver "org.postgresql.Driver", jdbcurl "jdbc:postgresql://host.docker.internal:5436/itoolbox_db",
  username "zetaris_ro", password "<generated>", schema "weather");
REGISTER DATASOURCE TABLES FROM WEATHER;

CREATE DATASOURCE BULLETINS DESCRIBE BY "PAGASA tropical cyclone bulletins, wind signals and rainfall advisories via self-hosted BagyoAPI, itoolbox-data-platform, read-only" OPTIONS (
  jdbcdriver "org.postgresql.Driver", jdbcurl "jdbc:postgresql://host.docker.internal:5436/itoolbox_db",
  username "zetaris_ro", password "<generated>", schema "bulletins");
REGISTER DATASOURCE TABLES FROM BULLETINS;

CREATE DATASOURCE HAZARDS DESCRIBE BY "USGS earthquakes, GDACS disaster alerts and Project NOAH hazard per city, itoolbox-data-platform, read-only" OPTIONS (
  jdbcdriver "org.postgresql.Driver", jdbcurl "jdbc:postgresql://host.docker.internal:5436/itoolbox_db",
  username "zetaris_ro", password "<generated>", schema "hazards");
REGISTER DATASOURCE TABLES FROM HAZARDS;

CREATE DATASOURCE TYPHOONS DESCRIBE BY "IBTrACS tropical cyclone tracks inside PAR since 1951 and closest passes to each city, itoolbox-data-platform, read-only" OPTIONS (
  jdbcdriver "org.postgresql.Driver", jdbcurl "jdbc:postgresql://host.docker.internal:5436/itoolbox_db",
  username "zetaris_ro", password "<generated>", schema "typhoons");
REGISTER DATASOURCE TABLES FROM TYPHOONS;

CREATE DATASOURCE REFERENCE DESCRIBE BY "PSGC places, PSA province population and OpenStreetMap facilities near each city, itoolbox-data-platform, read-only" OPTIONS (
  jdbcdriver "org.postgresql.Driver", jdbcurl "jdbc:postgresql://host.docker.internal:5436/itoolbox_db",
  username "zetaris_ro", password "<generated>", schema "reference");
REGISTER DATASOURCE TABLES FROM REFERENCE;

-- Check:
--   SHOW DATASOURCES                         -- the five above
--   SHOW TABLES IN HAZARDS                   -- city_hazard, disaster_alerts, earthquakes
--   SELECT COUNT(*) FROM TYPHOONS.storms
--
-- A new table in a schema needs `REGISTER DATASOURCE TABLES FROM <SOURCE>` again.
-- A new schema needs its own GRANTs above and its own data source.
--
-- To remove one:  DROP DATASOURCE <SOURCE>;
-- To remove all:  drop each, then in itoolbox_db: DROP OWNED BY zetaris_ro; DROP ROLE zetaris_ro;
