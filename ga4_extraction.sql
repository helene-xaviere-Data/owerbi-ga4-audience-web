-- =====================================================================
-- Projet : Analyse d'audience web (Google Analytics 4) - Power BI
-- Source : bigquery-public-data.ga4_obfuscated_sample_ecommerce
--          (export GA4 réel et anonymisé, 01/11/2020 -> 31/01/2021)
-- Outil  : BigQuery Sandbox (gratuit, sans carte bancaire)
-- =====================================================================
-- Mode d'emploi :
-- 0. Créer un dataset "ga4_portfolio" dans ton projet, emplacement US
--    (obligatoire : les données publiques GA4 sont stockées aux US).
-- 1. Coller et exécuter la requête 1 seule : elle crée la table ga4_portfolio.sessions.
-- 2. Coller et exécuter la requête 2 seule : elle crée la table ga4_portfolio.pages.
-- 3. Dans Power BI : Obtenir des données > Google BigQuery > ton projet
--    > ga4_portfolio > cocher les 2 tables.
-- =====================================================================


-- ---------------------------------------------------------------------
-- REQUÊTE 1 : table des SESSIONS (1 ligne = 1 session)
-- Sert aux KPI d'audience, d'engagement et d'acquisition.
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE ga4_portfolio.sessions AS
WITH events AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS date,
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_number') AS session_number,
    event_name,
    device.category        AS device_category,
    geo.country            AS country,
    traffic_source.source  AS user_source,   -- source d'acquisition du 1er contact de l'utilisateur
    traffic_source.medium  AS user_medium,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'engagement_time_msec') AS engagement_time_msec,
    (SELECT COALESCE(value.string_value, CAST(value.int_value AS STRING))
       FROM UNNEST(event_params) WHERE key = 'session_engaged') AS session_engaged
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
)
SELECT
  CONCAT(user_pseudo_id, '-', CAST(session_id AS STRING)) AS session_key,
  user_pseudo_id,
  MIN(date)                                         AS date,
  IF(MIN(session_number) = 1, 'Nouveau', 'Connu')   AS type_visiteur,
  ANY_VALUE(device_category)                        AS device_category,
  ANY_VALUE(country)                                AS country,
  ANY_VALUE(user_source)                            AS user_source,
  ANY_VALUE(user_medium)                            AS user_medium,
  COUNTIF(event_name = 'page_view')                 AS page_views,
  ROUND(SUM(IFNULL(engagement_time_msec, 0)) / 1000, 1) AS engagement_time_sec,
  MAX(IF(session_engaged = '1', 1, 0))              AS is_engaged,
  MAX(IF(event_name = 'purchase', 1, 0))            AS has_conversion
FROM events
WHERE session_id IS NOT NULL
GROUP BY session_key, user_pseudo_id;


-- ---------------------------------------------------------------------
-- REQUÊTE 2 : table des PAGES (1 ligne = 1 page x 1 jour x 1 appareil)
-- Sert à l'analyse de performance des contenus (vision "média").
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE ga4_portfolio.pages AS
SELECT
  PARSE_DATE('%Y%m%d', event_date) AS date,
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_title') AS page_title,
  REGEXP_REPLACE(
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location'),
    r'\?.*$', ''
  )                                AS page_url,          -- URL sans paramètres
  device.category                  AS device_category,
  COUNT(*)                         AS page_views
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  AND event_name = 'page_view'
GROUP BY date, page_title, page_url, device_category;
