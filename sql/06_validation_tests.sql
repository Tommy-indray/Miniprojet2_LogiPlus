-- ============================================
-- VALIDATION FINALE ET TESTS
-- ============================================

-- Test 1 : Vérification intégrité données spatiales
SELECT 
 'warehouses' AS table_name,
 COUNT(*) AS total_rows,
 COUNT(CASE WHEN ST_IsValid(position) THEN 1 END) AS geometries_valides,
 COUNT(CASE WHEN ST_SRID(position) = 3857 THEN 1 END) AS srid_correct
FROM warehouses
UNION ALL
SELECT 
 'order_dest_geo',
 COUNT(*),
 COUNT(CASE WHEN ST_IsValid(geom) THEN 1 END),
 COUNT(CASE WHEN ST_SRID(geom) = 3857 THEN 1 END)
FROM order_dest_geo;

-- Test 2 : Performance requête spatiale typique
EXPLAIN (ANALYZE, FORMAT JSON)
SELECT 
 w.name AS entrepot,
 COUNT(o.id) AS commandes_proches,
 ROUND(AVG(ST_Distance(w.position, odg.geom) / 1000)::numeric, 2) AS distance_moyenne_km
FROM warehouses w
JOIN order_dest_geo odg ON ST_DWithin(w.position, odg.geom, 200000)
JOIN orders o ON odg.order_id = o.id
WHERE o.order_date >= CURRENT_DATE - INTERVAL '90 days'
AND o.status != 'cancelled'
GROUP BY w.id, w.name
ORDER BY commandes_proches DESC
LIMIT 10;

-- Test 3 : Vérification KNN avec opérateur <-> (Plus proche voisin)
SELECT 
 w.name AS entrepot_le_plus_proche,
 ROUND(((w.position <-> odg.geom) / 1000)::numeric, 2) AS distance_km
FROM order_dest_geo odg
CROSS JOIN LATERAL (
 SELECT w.*
 FROM warehouses w
 ORDER BY w.position <-> odg.geom
 LIMIT 1
) w
WHERE odg.order_id = (SELECT id FROM orders WHERE order_no = 'ORD-1001')
LIMIT 1;

/*
NOTE FINALE :
Ce script implémente une solution complète de logistique spatiale
avec optimisation des performances via indexation GIST et utilisation
de l'approximation euclidienne (EPSG:3857) adaptée au contexte européen.
*/

-- =================================================================
-- FIN DU SCRIPT MINIPROJET 2 : LOGIPLUS
-- =================================================================