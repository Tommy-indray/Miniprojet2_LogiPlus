-- ============================================
-- PARTIE 5 : OPTIMISATION ET INDEXATION
-- ============================================

-- -----------------------------------------------------
-- 5.1 Indexation avancée pour performances spatiales
-- -----------------------------------------------------
-- Index composite pour les requêtes KNN fréquentes
CREATE INDEX IF NOT EXISTS idx_warehouses_country_position 
ON warehouses (country, position);

-- Index pour les requêtes temporelles-spatiales combinées
CREATE INDEX IF NOT EXISTS idx_orders_date_status_country 
ON orders (order_date, status, dest_country);

-- Index partiel pour les expéditions actives
CREATE INDEX IF NOT EXISTS idx_shipments_active 
ON shipments (status) WHERE status NOT IN ('delivered', 'cancelled');

-- Index pour les agrégations spatiales fréquentes
CREATE INDEX IF NOT EXISTS idx_order_dest_geo_order_id 
ON order_dest_geo (order_id);

-- Index GIST pour les buffers et zones
CREATE INDEX IF NOT EXISTS idx_warehouses_position_buffer 
ON warehouses USING GIST (ST_Buffer(position, 100000));

-- -----------------------------------------------------
-- 5.2 Analyse EXPLAIN pour validation des performances
-- -----------------------------------------------------
EXPLAIN (ANALYZE, BUFFERS)
WITH commandes_proches AS (
    SELECT 
        o.id,
        o.order_no,
        odg.geom,
        w.name AS entrepot_proche,
        ST_Distance(w.position, odg.geom) / 1000 AS distance_km
    FROM orders o
    JOIN order_dest_geo odg ON o.id = odg.order_id
    CROSS JOIN LATERAL (
        SELECT w.*
        FROM warehouses w
        WHERE w.country = o.dest_country
        ORDER BY w.position <-> odg.geom
        LIMIT 1
    ) w
    WHERE o.order_date >= CURRENT_DATE - INTERVAL '30 days'
      AND o.status != 'cancelled'
)
SELECT 
    entrepot_proche,
    COUNT(*) AS nombre_commandes,
    ROUND(AVG(distance_km)::numeric, 2) AS distance_moyenne,
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY distance_km)::numeric, 2) AS distance_p95
FROM commandes_proches
GROUP BY entrepot_proche
ORDER BY nombre_commandes DESC;