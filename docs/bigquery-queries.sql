-- ------------------------------------------------------------
-- Query 1: Recent logs from both GKE clusters
-- ------------------------------------------------------------
SELECT
  timestamp,
  resource.labels.cluster_name AS cluster_name,
  resource.labels.pod_name AS pod_name,
  textPayload
FROM
  `starfleet-gke-platform-lab.starfleet_gke_logs.stderr`
WHERE
  timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
ORDER BY
  timestamp DESC
LIMIT 50;


-- ------------------------------------------------------------
-- Query 2: Log count by cluster
-- ------------------------------------------------------------
SELECT
  resource.labels.cluster_name AS cluster_name,
  COUNT(*) AS log_count
FROM
  `starfleet-gke-platform-lab.starfleet_gke_logs.stderr`
WHERE
  timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
GROUP BY
  cluster_name
ORDER BY
  log_count DESC;


-- ------------------------------------------------------------
-- Query 3: Log count by application
-- ------------------------------------------------------------
SELECT
  CASE
    WHEN resource.labels.pod_name LIKE 'starfleet-navigation-service%' THEN 'navigation'
    WHEN resource.labels.pod_name LIKE 'starfleet-communications-service%' THEN 'communications'
    ELSE 'other'
  END AS service,
  COUNT(*) AS log_count
FROM
  `starfleet-gke-platform-lab.starfleet_gke_logs.stderr`
WHERE
  timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
GROUP BY
  service
ORDER BY
  log_count DESC;


-- ------------------------------------------------------------
-- Query 4: HTTP 200 request count
-- ------------------------------------------------------------
SELECT
  resource.labels.cluster_name AS cluster_name,
  COUNT(*) AS http_200_count
FROM
  `starfleet-gke-platform-lab.starfleet_gke_logs.stderr`
WHERE
  timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
  AND textPayload LIKE '% 200 -%'
GROUP BY
  cluster_name
ORDER BY
  http_200_count DESC;
