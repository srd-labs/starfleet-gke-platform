-- -----------------------------------------------------------------------------
-- GKE Log Count by Cluster and Application Service
-- -----------------------------------------------------------------------------
-- Purpose:
-- Counts application log entries grouped by both GKE cluster and Starfleet
-- service during the last hour.
--
-- This query demonstrates centralized log analytics across the complete
-- multi-cluster, multi-application platform.
--
-- Expected groups:
--   enterprise-gke-alpha -> navigation
--   enterprise-gke-alpha -> communications
--   enterprise-gke-delta -> navigation
--   enterprise-gke-delta -> communications
--
-- Source:
-- Dataset: starfleet_gke_logs
-- Table:   stderr
-- -----------------------------------------------------------------------------

SELECT
  resource.labels.cluster_name AS cluster_name,

  CASE
    WHEN resource.labels.pod_name LIKE 'starfleet-navigation-service%'
      THEN 'navigation'
    WHEN resource.labels.pod_name LIKE 'starfleet-communications-service%'
      THEN 'communications'
    ELSE 'other'
  END AS service,

  COUNT(*) AS log_count

FROM
  `starfleet-gke-platform-lab.starfleet_gke_logs.stderr`

WHERE
  timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)

GROUP BY
  cluster_name,
  service

ORDER BY
  cluster_name,
  service;
