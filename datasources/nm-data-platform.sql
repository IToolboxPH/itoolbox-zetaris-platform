-- How NM_RAN and NM_STUDIES were registered in Zetaris (2026-10-21).
--
-- Source: nm-data-platform's TimescaleDB, database nm_db, on the host at port 5433.
-- Zetaris reaches it through a read-only role, and each Postgres schema is its own data
-- source: without a `schema` option Zetaris registers the tables of `public` only.
--
-- No passwords are recorded here. The role's password lives only inside Zetaris,
-- encrypted with the keypair in the driver-data volume.


-- ── 1. In nm_db, as its owner (nm) ───────────────────────────────────────────
-- A login that can read ran and studies and nothing else: no auth or etl schema, no
-- writes. Default privileges cover tables nm creates there later.

CREATE ROLE zetaris_ro LOGIN PASSWORD '<a new random password>';
GRANT CONNECT ON DATABASE nm_db TO zetaris_ro;
GRANT USAGE ON SCHEMA ran, studies TO zetaris_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA ran, studies TO zetaris_ro;
ALTER DEFAULT PRIVILEGES FOR ROLE nm IN SCHEMA ran, studies GRANT SELECT ON TABLES TO zetaris_ro;


-- ── 2. In Zetaris, over JDBC, as a Zetaris admin ─────────────────────────────
-- For example from DBeaver with jdbc/ndp-jdbc-driver-*.jar, URL
-- jdbc:zetaris:lightning@localhost:10000. host.docker.internal is the host as the
-- Zetaris containers see it. DESCRIBE BY accepts only letters, digits, spaces and
-- _ . - ,

CREATE DATASOURCE NM_RAN DESCRIBE BY "nm-data-platform TimescaleDB, schema ran, read-only" OPTIONS (
  jdbcdriver "org.postgresql.Driver",
  jdbcurl "jdbc:postgresql://host.docker.internal:5433/nm_db",
  username "zetaris_ro",
  password "<the zetaris_ro password>",
  schema "ran"
);
REGISTER DATASOURCE TABLES FROM NM_RAN;

CREATE DATASOURCE NM_STUDIES DESCRIBE BY "nm-data-platform TimescaleDB, schema studies, read-only" OPTIONS (
  jdbcdriver "org.postgresql.Driver",
  jdbcurl "jdbc:postgresql://host.docker.internal:5433/nm_db",
  username "zetaris_ro",
  password "<the zetaris_ro password>",
  schema "studies"
);
REGISTER DATASOURCE TABLES FROM NM_STUDIES;


-- ── Check ────────────────────────────────────────────────────────────────────
--   SHOW DATASOURCES
--   SHOW TABLES IN NM_RAN            -- 9 tables
--   SHOW TABLES IN NM_STUDIES        -- 6 tables
--   SELECT COUNT(*) FROM NM_RAN.sites
--
-- Plain SHOW DATABASES / SHOW TABLES are disabled in this Zetaris build; use the
-- `... IN <source>` forms.


-- ── Undo ─────────────────────────────────────────────────────────────────────
--   In Zetaris:  DROP DATASOURCE NM_RAN;  DROP DATASOURCE NM_STUDIES;
--   In nm_db:    DROP OWNED BY zetaris_ro;  DROP ROLE zetaris_ro;
