------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS meta
(
    key     VARCHAR UNIQUE NOT NULL,
    value   VARCHAR UNIQUE NULL
);

INSERT INTO meta VALUES ('version', '1') ON CONFLICT (key) DO NOTHING;

CREATE TABLE IF NOT EXISTS charts
(
    id         BIGSERIAL PRIMARY KEY,
    name       VARCHAR UNIQUE           NOT NULL, -- DSID_DSNM
    scale      INTEGER                  NOT NULL, -- DSPM_CSCL
    file_name  VARCHAR                  NOT NULL, -- actual file name
    updated    VARCHAR                  NOT NULL, -- DSID_UADT
    issued     VARCHAR                  NOT NULL, -- DSID_ISDT

    -- Although these could be stored in th features table these we need some of this meta data in order to
    -- derive MINZ and MAXX when SCAMIN and SCAMAX are not defined. This allows us to NOT have to rely on insertion
    -- order.
    zoom       INTEGER                  NOT NULL, -- Best display zoom level derived from scale and center latitude
    covr       GEOMETRY(GEOMETRY, 4326) NOT NULL, -- Coverage area from "M_COVR" layer feature with "CATCOV" = 1
    dsid_props JSONB                    NOT NULL, -- DSID
    chart_txt  JSONB                    NOT NULL  -- Chart text file contents e.g. { "US5WA22A.TXT": "<file contents>" }
);

-- indices
CREATE INDEX IF NOT EXISTS charts_gist ON charts USING GIST (covr);
CREATE INDEX IF NOT EXISTS charts_idx ON charts (id);

------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS features
(
    id        BIGSERIAL PRIMARY KEY,
    layer     VARCHAR                       NOT NULL,
    geom      GEOMETRY(GEOMETRY, 4326)      NOT NULL,
    props     JSONB                         NOT NULL,
    chart_id  BIGINT REFERENCES charts (id) NOT NULL,
    lnam_refs VARCHAR[]                     NULL,
    z_range   INT4RANGE                     NOT NULL
);

-- indices
CREATE INDEX IF NOT EXISTS features_gist ON features USING GIST (geom);
CREATE INDEX IF NOT EXISTS features_idx ON features (id);
CREATE INDEX IF NOT EXISTS features_layer_idx ON features (layer);
CREATE INDEX IF NOT EXISTS features_zoom_idx ON features USING GIST (z_range);
CREATE INDEX IF NOT EXISTS features_lnam_idx ON features USING GIN (lnam_refs);

------------------------------------------------------------------

-- CREATE OR REPLACE FUNCTION public.concat_mvt(z INTEGER, x INTEGER, y INTEGER)
--     RETURNS BYTEA
--     LANGUAGE plpgsql
-- AS
-- $BODY$
-- DECLARE
--     i   TEXT;
--     res BYTEA DEFAULT '';
--     rec BYTEA;
-- BEGIN
--     FOR i IN SELECT DISTINCT layer from features
--         LOOP
--             WITH mvtdata AS (
--                 SELECT ST_AsMvtGeom(geom, ST_Transform(ST_TileEnvelope(z, x, y), 4326)) AS geom,
--                        layer                                                            AS name,
--                        props                                                            AS properties,
--                        z_range
--                 FROM features
--                 WHERE layer = i
--                   AND geom && ST_Transform(ST_TileEnvelope(z, x, y), 4326)
--                   AND z <@ z_range
--             )
--             SELECT ST_AsMVT(mvtdata.*, i)
--             FROM mvtdata
--             INTO rec;
--             res := res || rec;
--         END LOOP;
--     RETURN res;
-- END
-- $BODY$;

------------------------------------------------------------------
-- https://postgis.net/docs/reference.html#Geometry_Processing
-- https://postgis.net/docs/ST_Intersection.html
-- https://postgis.net/docs/ST_Difference.html
--
-- 1 find the chart covr geometries within the tile envelope ordered by scale
-- 2
--
-- CREATE OR REPLACE FUNCTION public.concat_mvt_occluded(z INTEGER, x INTEGER, y INTEGER)
--     RETURNS BYTEA
--     LANGUAGE plpgsql
-- AS
-- $BODY$
-- DECLARE
--     tileEnvelope geometry;
--     coverage     geometry;
--     chart        RECORD;
--     i            TEXT;
--     res          BYTEA DEFAULT '';
--     rec          BYTEA;
-- BEGIN
--     tileEnvelope = ST_Transform(ST_TileEnvelope(z, x, y), 4326);
--     coverage = null;
--     FOR chart in SELECT id, covr FROM charts WHERE st_intersects(covr, tileEnvelope) ORDER BY scale
--         LOOP
--             coverage = CASE
--                            WHEN coverage IS NULL THEN st_intersection(chart.covr, tileEnvelope)
--                            ELSE st_union(chart.covr, coverage)
--                 END;
--
--             FOR i IN SELECT DISTINCT layer from features WHERE chart_id = chart.id
--                 LOOP
--                     WITH mvtdata AS (
--                         SELECT ST_AsMvtGeom(geom, tileEnvelope) AS geom,
--                                layer                            AS name,
--                                props                            AS properties,
--                                z_range
--                         FROM features
--                         WHERE layer = i
--                           AND chart_id = chart.id
--                           AND geom && tileEnvelope
--                           AND z <@ z_range
--                     )
--                     SELECT ST_AsMVT(mvtdata.*, i)
--                     FROM mvtdata
--                     INTO rec;
--                     res := res || rec;
--                 END LOOP;
--
--             IF st_within(coverage, tileEnvelope) THEN EXIT;
--             END IF;
--
--         END LOOP;
--     RETURN res;
-- END
-- $BODY$;
