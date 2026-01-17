-- ============================================
-- PARTIE 4 : QUESTIONS SPATIALES (20 QUESTIONS)
-- ============================================

-- -----------------------------------------------------
-- NOTE TECHNIQUE : APPROCHE SPATIALE COMMUNE
-- -----------------------------------------------------
-- HYPOTHÈSE : Approximation euclidienne (Terre ≈ plan) pour l'Europe
-- SYSTÈME : EPSG:3857 (Web Mercator) pour distances en mètres
-- MÉTHODE : ST_Distance() pour calculs, <-> pour KNN, ST_DWithin() pour rayons
-- INDEXATION : GIST sur toutes les colonnes geometry pour performance

-- -----------------------------------------------------
-- QS1 : Appariement commande → entrepôt le plus proche
-- -----------------------------------------------------
WITH commande_plus_proche AS (
    SELECT 
        o.id AS order_id,
        o.order_no,
        o.dest_city,
        o.dest_country,
        w.id AS warehouse_id,
        w.name AS entrepot,
        w.city AS ville_entrepot,
        w.country AS pays_entrepot,
        ST_Distance(w.position, odg.geom) / 1000 AS distance_km,
        ROW_NUMBER() OVER (PARTITION BY o.id ORDER BY ST_Distance(w.position, odg.geom)) AS rang_proximite
    FROM orders o
    JOIN order_dest_geo odg ON o.id = odg.order_id
    CROSS JOIN warehouses w
    WHERE w.country = o.dest_country
)
SELECT 
    order_no,
    dest_city,
    dest_country,
    entrepot,
    ville_entrepot,
    pays_entrepot,
    ROUND(distance_km::numeric, 2) AS distance_km,
    CASE 
        WHEN distance_km < 50 THEN 'Très proche (<50km)'
        WHEN distance_km < 150 THEN 'Proche (50-150km)'
        WHEN distance_km < 300 THEN 'Moyenne distance (150-300km)'
        ELSE 'Longue distance (≥300km)'
    END AS classification_distance
FROM commande_plus_proche
WHERE rang_proximite = 1
ORDER BY distance_km;

-- -----------------------------------------------------
-- QS2 : Portée moyenne des entrepôts
-- -----------------------------------------------------
WITH appariement_commandes AS (
    SELECT 
        w.id AS warehouse_id,
        w.name AS entrepot,
        COUNT(DISTINCT o.id) AS nombre_commandes,
        AVG(ST_Distance(w.position, odg.geom) / 1000) AS distance_moyenne_km,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ST_Distance(w.position, odg.geom) / 1000) AS distance_mediane_km,
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY ST_Distance(w.position, odg.geom) / 1000) AS distance_p95_km,
        MAX(ST_Distance(w.position, odg.geom) / 1000) AS distance_max_km
    FROM warehouses w
    JOIN order_dest_geo odg ON ST_DWithin(w.position, odg.geom, 1000000)
    JOIN orders o ON odg.order_id = o.id
    WHERE o.status != 'cancelled'
    GROUP BY w.id, w.name
)
SELECT 
    entrepot,
    nombre_commandes,
    ROUND(distance_moyenne_km::numeric, 2) AS distance_moyenne_km,
    ROUND(distance_mediane_km::numeric, 2) AS distance_mediane_km,
    ROUND(distance_p95_km::numeric, 2) AS distance_p95_km,
    ROUND(distance_max_km::numeric, 2) AS distance_max_km,
    CASE 
        WHEN distance_moyenne_km < 100 THEN 'Locale (<100km)'
        WHEN distance_moyenne_km < 300 THEN 'Régionale (100-300km)'
        WHEN distance_moyenne_km < 800 THEN 'Nationale (300-800km)'
        ELSE 'Internationale (≥800km)'
    END AS portee_classification
FROM appariement_commandes
ORDER BY distance_moyenne_km DESC;

-- -----------------------------------------------------
-- QS3 : Classement des entrepôts par volume attribué
-- -----------------------------------------------------
WITH commandes_appariees AS (
    SELECT 
        w.id AS warehouse_id,
        w.name AS entrepot,
        SUM(oi.qty_ordered) AS quantite_totale,
        SUM(oi.qty_ordered * p.volume_m3) AS volume_total_m3,
        SUM(oi.qty_ordered * p.weight_kg) AS poids_total_kg,
        COUNT(DISTINCT o.id) AS nombre_commandes,
        AVG(ST_Distance(w.position, odg.geom) / 1000) AS distance_moyenne_km
    FROM warehouses w
    JOIN order_dest_geo odg ON ST_DWithin(w.position, odg.geom, 500000)
    JOIN orders o ON odg.order_id = o.id
    JOIN order_items oi ON o.id = oi.order_id
    JOIN products p ON oi.product_id = p.id
    WHERE o.status != 'cancelled'
    GROUP BY w.id, w.name
)
SELECT 
    entrepot,
    nombre_commandes,
    quantite_totale,
    ROUND(volume_total_m3::numeric, 2) AS volume_total_m3,
    ROUND(poids_total_kg::numeric, 2) AS poids_total_kg,
    ROUND(distance_moyenne_km::numeric, 2) AS distance_moyenne_km,
    RANK() OVER (ORDER BY quantite_totale DESC) AS rang_quantite,
    RANK() OVER (ORDER BY volume_total_m3 DESC) AS rang_volume,
    RANK() OVER (ORDER BY nombre_commandes DESC) AS rang_commandes
FROM commandes_appariees
ORDER BY quantite_totale DESC;

-- -----------------------------------------------------
-- QS4 : Distance moyenne par produit
-- -----------------------------------------------------
WITH distances_produits AS (
    SELECT 
        p.id,
        p.sku,
        p.name,
        oi.order_id,
        ST_Distance(w.position, odg.geom) / 1000 AS distance_km
    FROM products p
    JOIN order_items oi ON p.id = oi.product_id
    JOIN orders o ON oi.order_id = o.id
    JOIN order_dest_geo odg ON o.id = odg.order_id
    JOIN warehouses w ON ST_Distance(w.position, odg.geom) = (
        SELECT MIN(ST_Distance(w2.position, odg.geom))
        FROM warehouses w2
        WHERE w2.country = o.dest_country
    )
    WHERE o.status != 'cancelled'
)
SELECT 
    sku,
    name,
    COUNT(DISTINCT order_id) AS nombre_commandes,
    ROUND(AVG(distance_km)::numeric, 2) AS distance_moyenne_km,
    ROUND(MIN(distance_km)::numeric, 2) AS distance_min_km,
    ROUND(MAX(distance_km)::numeric, 2) AS distance_max_km,
    ROUND(STDDEV(distance_km)::numeric, 2) AS ecart_type_km
FROM distances_produits
GROUP BY id, sku, name
ORDER BY distance_moyenne_km DESC;

-- -----------------------------------------------------
-- QS5 : Segmentation en bandes de distance
-- -----------------------------------------------------
WITH commandes_distance AS (
    SELECT 
        o.id AS order_id,
        o.order_no,
        o.dest_city,
        o.dest_country,
        w.name AS entrepot_proche,
        ST_Distance(w.position, odg.geom) / 1000 AS distance_km,
        CASE 
            WHEN ST_Distance(w.position, odg.geom) / 1000 < 50 THEN '< 50 km'
            WHEN ST_Distance(w.position, odg.geom) / 1000 < 150 THEN '50 - 150 km'
            WHEN ST_Distance(w.position, odg.geom) / 1000 < 300 THEN '150 - 300 km'
            ELSE '≥ 300 km'
        END AS bande_distance
    FROM orders o
    JOIN order_dest_geo odg ON o.id = odg.order_id
    CROSS JOIN LATERAL (
        SELECT w.*
        FROM warehouses w
        WHERE w.country = o.dest_country
        ORDER BY ST_Distance(w.position, odg.geom)
        LIMIT 1
    ) w
    WHERE o.status != 'cancelled'
)
SELECT 
    bande_distance,
    COUNT(DISTINCT order_id) AS nombre_commandes,
    COUNT(DISTINCT dest_country) AS nombre_pays,
    ROUND(AVG(distance_km)::numeric, 2) AS distance_moyenne_km,
    ROUND(MIN(distance_km)::numeric, 2) AS distance_min_km,
    ROUND(MAX(distance_km)::numeric, 2) AS distance_max_km,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pourcentage_commandes
FROM commandes_distance
GROUP BY bande_distance
ORDER BY 
    CASE bande_distance
        WHEN '< 50 km' THEN 1
        WHEN '50 - 150 km' THEN 2
        WHEN '150 - 300 km' THEN 3
        ELSE 4
    END;

-- -----------------------------------------------------
-- QS6 : Fiabilité transporteur par bande de distance
-- -----------------------------------------------------
WITH expeditions_bandes AS (
    SELECT 
        s.carrier,
        o.order_no,
        s.ship_date,
        s.eta_date,
        ST_Distance(w.position, odg.geom) / 1000 AS distance_km,
        CASE 
            WHEN ST_Distance(w.position, odg.geom) / 1000 < 50 THEN '< 50 km'
            WHEN ST_Distance(w.position, odg.geom) / 1000 < 150 THEN '50 - 150 km'
            WHEN ST_Distance(w.position, odg.geom) / 1000 < 300 THEN '150 - 300 km'
            ELSE '≥ 300 km'
        END AS bande_distance,
        CASE 
            WHEN s.status = 'delivered' AND s.eta_date >= s.ship_date THEN 
                (s.eta_date - s.ship_date)::integer
            ELSE NULL
        END AS duree_transit_jours,
        CASE 
            WHEN s.status = 'delivered' AND s.eta_date >= s.ship_date THEN 
                CASE WHEN s.eta_date > CURRENT_DATE THEN 1 ELSE 0 END
            ELSE NULL
        END AS en_retard
    FROM shipments s
    JOIN orders o ON s.order_id = o.id
    JOIN order_dest_geo odg ON o.id = odg.order_id
    CROSS JOIN LATERAL (
        SELECT w.*
        FROM warehouses w
        WHERE w.country = o.dest_country
        ORDER BY ST_Distance(w.position, odg.geom)
        LIMIT 1
    ) w
    WHERE s.status = 'delivered'
)
SELECT 
    carrier,
    bande_distance,
    COUNT(*) AS nombre_expeditions,
    ROUND(AVG(duree_transit_jours)::numeric, 2) AS duree_moyenne_jours,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY duree_transit_jours) AS duree_mediane_jours,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duree_transit_jours) AS duree_p95_jours,
    ROUND(AVG(distance_km)::numeric, 2) AS distance_moyenne_km,
    SUM(en_retard) AS retards,
    ROUND(SUM(en_retard) * 100.0 / NULLIF(COUNT(*), 0), 2) AS taux_retard_pourcent
FROM expeditions_bandes
GROUP BY carrier, bande_distance
ORDER BY carrier, 
    CASE bande_distance
        WHEN '< 50 km' THEN 1
        WHEN '50 - 150 km' THEN 2
        WHEN '150 - 300 km' THEN 3
        ELSE 4
    END;

-- -----------------------------------------------------
-- QS7 : Retards anormaux par lane et distance
-- -----------------------------------------------------
WITH lanes_retards AS (
    SELECT 
        w.country AS pays_depart,
        o.dest_country AS pays_arrivee,
        s.carrier,
        ST_Distance(w.position, odg.geom) / 1000 AS distance_km,
        CASE 
            WHEN ST_Distance(w.position, odg.geom) / 1000 < 50 THEN '< 50 km'
            WHEN ST_Distance(w.position, odg.geom) / 1000 < 150 THEN '50 - 150 km'
            WHEN ST_Distance(w.position, odg.geom) / 1000 < 300 THEN '150 - 300 km'
            ELSE '≥ 300 km'
        END AS bande_distance,
        (s.eta_date - s.ship_date)::integer AS duree_estimee,
        (CURRENT_DATE - s.ship_date)::integer AS duree_actuelle,
        ((CURRENT_DATE - s.ship_date)::integer - (s.eta_date - s.ship_date)::integer) AS retard_jours
    FROM shipments s
    JOIN orders o ON s.order_id = o.id
    JOIN order_dest_geo odg ON o.id = odg.order_id
    CROSS JOIN LATERAL (
        SELECT w.*
        FROM warehouses w
        WHERE w.country = o.dest_country
        ORDER BY ST_Distance(w.position, odg.geom)
        LIMIT 1
    ) w
    WHERE s.status = 'in_transit'
),
seuils_par_lane AS (
    SELECT 
        pays_depart,
        pays_arrivee,
        bande_distance,
        PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY retard_jours) AS seuil_p90
    FROM lanes_retards
    GROUP BY pays_depart, pays_arrivee, bande_distance
)
SELECT 
    lr.pays_depart,
    lr.pays_arrivee,
    lr.carrier,
    lr.bande_distance,
    lr.distance_km,
    lr.retard_jours,
    sp.seuil_p90,
    CASE WHEN lr.retard_jours > sp.seuil_p90 THEN 'ANORMAL' ELSE 'NORMAL' END AS statut_retard
FROM lanes_retards lr
JOIN seuils_par_lane sp ON lr.pays_depart = sp.pays_depart 
    AND lr.pays_arrivee = sp.pays_arrivee 
    AND lr.bande_distance = sp.bande_distance
WHERE lr.retard_jours > 0
ORDER BY retard_jours DESC;

-- -----------------------------------------------------
-- QS8 : Rééquilibrage intra-pays minimal
-- -----------------------------------------------------
WITH stocks_par_entrepot AS (
    SELECT 
        w.id AS warehouse_id,
        w.name AS entrepot,
        w.country,
        p.id AS product_id,
        p.sku,
        p.name,
        i.qty_on_hand,
        i.safety_stock,
        i.qty_on_hand - i.safety_stock AS surplus_deficit,
        CASE 
            WHEN i.qty_on_hand - i.safety_stock > 0 THEN 'excédent'
            WHEN i.qty_on_hand - i.safety_stock < 0 THEN 'déficit'
            ELSE 'équilibre'
        END AS statut
    FROM warehouses w
    JOIN inventory i ON w.id = i.warehouse_id
    JOIN products p ON i.product_id = p.id
),
excédents AS (
    SELECT * FROM stocks_par_entrepot WHERE statut = 'excédent'
),
deficits AS (
    SELECT * FROM stocks_par_entrepot WHERE statut = 'déficit'
)
SELECT 
    d.entrepot AS entrepot_deficitaire,
    d.country AS pays,
    d.sku,
    d.name AS produit,
    ABS(d.surplus_deficit) AS quantite_manquante,
    e.entrepot AS entrepot_excedentaire,
    e.surplus_deficit AS quantite_disponible,
    ROUND((ST_Distance(wd.position, we.position) / 1000)::numeric, 2) AS distance_km,
    ROW_NUMBER() OVER (
        PARTITION BY d.warehouse_id, d.product_id 
        ORDER BY ST_Distance(wd.position, we.position)
    ) AS rang_proximite
FROM deficits d
JOIN excédents e ON d.product_id = e.product_id AND d.country = e.country
JOIN warehouses wd ON d.warehouse_id = wd.id
JOIN warehouses we ON e.warehouse_id = we.id
WHERE ST_Distance(wd.position, we.position) / 1000 <= 300
  AND e.surplus_deficit >= ABS(d.surplus_deficit)
ORDER BY distance_km;

-- -----------------------------------------------------
-- QS9 : Couples d'entrepôts éligibles au transfert (seuil 300 km)
-- -----------------------------------------------------
WITH couples_entrepots AS (
    SELECT 
        w1.id AS wh1_id,
        w1.name AS wh1_nom,
        w1.country AS wh1_pays,
        w2.id AS wh2_id,
        w2.name AS wh2_nom,
        w2.country AS wh2_pays,
        ST_Distance(w1.position, w2.position) / 1000 AS distance_km
    FROM warehouses w1
    CROSS JOIN warehouses w2
    WHERE w1.id < w2.id
      AND w1.country = w2.country  -- Intra-pays seulement
      AND ST_Distance(w1.position, w2.position) / 1000 <= 300
),
transfers_possibles AS (
    SELECT 
        ce.*,
        p.sku,
        p.name AS produit,
        i1.qty_on_hand AS stock_wh1,
        i1.safety_stock AS securite_wh1,
        i2.qty_on_hand AS stock_wh2,
        i2.safety_stock AS securite_wh2,
        CASE 
            WHEN i1.qty_on_hand < i1.safety_stock AND i2.qty_on_hand > i2.safety_stock THEN 'WH1←WH2'
            WHEN i2.qty_on_hand < i2.safety_stock AND i1.qty_on_hand > i1.safety_stock THEN 'WH1→WH2'
            ELSE 'Équilibre'
        END AS sens_transfert,
        ABS(i1.qty_on_hand - i1.safety_stock) AS besoin_wh1,
        ABS(i2.qty_on_hand - i2.safety_stock) AS besoin_wh2
    FROM couples_entrepots ce
    JOIN inventory i1 ON ce.wh1_id = i1.warehouse_id
    JOIN inventory i2 ON ce.wh2_id = i2.warehouse_id AND i1.product_id = i2.product_id
    JOIN products p ON i1.product_id = p.id
    WHERE (i1.qty_on_hand < i1.safety_stock OR i2.qty_on_hand < i2.safety_stock)
)
SELECT DISTINCT
    wh1_nom,
    wh2_nom,
    wh1_pays,
    ROUND(distance_km::numeric, 2) AS distance_km,
    COUNT(DISTINCT sku) AS produits_transferables,
    SUM(CASE WHEN sens_transfert = 'WH1←WH2' THEN 1 ELSE 0 END) AS transferts_vers_wh1,
    SUM(CASE WHEN sens_transfert = 'WH1→WH2' THEN 1 ELSE 0 END) AS transferts_vers_wh2
FROM transfers_possibles
GROUP BY wh1_nom, wh2_nom, wh1_pays, distance_km
ORDER BY wh1_pays, distance_km;

-- -----------------------------------------------------
-- QS10 : "Reorder list" avec rayon de desserte
-- -----------------------------------------------------
WITH demande_locale AS (
    SELECT 
        w.id AS warehouse_id,
        w.name AS entrepot,
        p.id AS product_id,
        p.sku,
        p.name AS produit,
        COUNT(DISTINCT o.id) AS commandes_30j,
        SUM(oi.qty_ordered) AS quantite_demandee_30j,
        AVG(ST_Distance(w.position, odg.geom) / 1000) AS distance_moyenne_km,
        i.qty_on_hand AS stock_actuel,
        i.safety_stock AS stock_securite
    FROM warehouses w
    JOIN order_dest_geo odg ON ST_DWithin(w.position, odg.geom, 200000)
    JOIN orders o ON odg.order_id = o.id
    JOIN order_items oi ON o.id = oi.order_id
    JOIN products p ON oi.product_id = p.id
    LEFT JOIN inventory i ON w.id = i.warehouse_id AND p.id = i.product_id
    WHERE o.order_date >= CURRENT_DATE - INTERVAL '30 days'
      AND o.status != 'cancelled'
    GROUP BY w.id, w.name, p.id, p.sku, p.name, i.qty_on_hand, i.safety_stock
)
SELECT 
    entrepot,
    sku,
    produit,
    commandes_30j,
    quantite_demandee_30j,
    ROUND(distance_moyenne_km::numeric, 2) AS distance_moyenne_km,
    COALESCE(stock_actuel, 0) AS stock_actuel,
    COALESCE(stock_securite, 0) AS stock_securite,
    CASE 
        WHEN COALESCE(stock_actuel, 0) = 0 THEN 'STOCK NUL'
        WHEN COALESCE(stock_actuel, 0) < COALESCE(stock_securite, 0) THEN 'EN DESSOUS SÉCURITÉ'
        WHEN COALESCE(stock_actuel, 0) < quantite_demandee_30j THEN 'INSUFFISANT POUR DEMANDE'
        ELSE 'SUFFISANT'
    END AS statut_stock,
    GREATEST(
        COALESCE(stock_securite, quantite_demandee_30j) - COALESCE(stock_actuel, 0),
        0
    ) AS quantite_a_reapprovisionner
FROM demande_locale
WHERE COALESCE(stock_actuel, 0) < COALESCE(stock_securite, quantite_demandee_30j)
ORDER BY quantite_a_reapprovisionner DESC, commandes_30j DESC;

-- -----------------------------------------------------
-- QS11 : Choix du dépôt d'expédition alternatif
-- -----------------------------------------------------
WITH entrepots_proximite AS (
    SELECT 
        o.id AS order_id,
        o.order_no,
        odg.geom AS destination,
        w.id AS warehouse_id,
        w.name AS entrepot,
        w.position,
        ST_Distance(w.position, odg.geom) / 1000 AS distance_km,
        ROW_NUMBER() OVER (PARTITION BY o.id ORDER BY ST_Distance(w.position, odg.geom)) AS rang_proximite
    FROM orders o
    JOIN order_dest_geo odg ON o.id = odg.order_id
    CROSS JOIN warehouses w
    WHERE w.country = o.dest_country
      AND o.status NOT IN ('cancelled', 'delivered')
),
inventaire_disponible AS (
    SELECT 
        warehouse_id,
        product_id,
        qty_on_hand
    FROM inventory
    WHERE qty_on_hand > 0
)
SELECT 
    ep1.order_no,
    ep1.entrepot AS entrepot_optimal,
    ROUND(ep1.distance_km::numeric, 2) AS distance_optimale_km,
    ep2.entrepot AS entrepot_alternatif,
    ROUND(ep2.distance_km::numeric, 2) AS distance_alternative_km,
    ROUND((ep2.distance_km - ep1.distance_km)::numeric, 2) AS distance_supplementaire_km,
    ROUND(((ep2.distance_km - ep1.distance_km) / NULLIF(ep1.distance_km, 0) * 100)::numeric, 2) AS augmentation_pourcentage,
    COUNT(DISTINCT id.product_id) AS produits_disponibles
FROM entrepots_proximite ep1
JOIN entrepots_proximite ep2 ON ep1.order_id = ep2.order_id AND ep2.rang_proximite = 2
LEFT JOIN inventaire_disponible id ON ep2.warehouse_id = id.warehouse_id
WHERE ep1.rang_proximite = 1
GROUP BY 
    ep1.order_no, ep1.entrepot, ep1.distance_km, 
    ep2.entrepot, ep2.distance_km
ORDER BY distance_supplementaire_km DESC;

-- -----------------------------------------------------
-- QS12 : Impact distance sur coût ou temps
-- -----------------------------------------------------
WITH expeditions_analyse AS (
    SELECT 
        s.carrier,
        CASE 
            WHEN ST_Distance(w.position, odg.geom) / 1000 < 100 THEN '< 100 km'
            WHEN ST_Distance(w.position, odg.geom) / 1000 < 300 THEN '100-300 km'
            WHEN ST_Distance(w.position, odg.geom) / 1000 < 600 THEN '300-600 km'
            ELSE '≥ 600 km'
        END AS tranche_distance,
        ST_Distance(w.position, odg.geom) / 1000 AS distance_km,
        (s.eta_date - s.ship_date)::integer AS duree_estimee_jours,
        EXTRACT(DAY FROM (se_delivered.event_time - se_picked.event_time))::integer AS duree_reelle_jours,
        oi.qty_ordered * oi.unit_price AS valeur_commande
    FROM shipments s
    JOIN orders o ON s.order_id = o.id
    JOIN order_dest_geo odg ON o.id = odg.order_id
    CROSS JOIN LATERAL (
        SELECT w.*
        FROM warehouses w
        WHERE w.country = o.dest_country
        ORDER BY ST_Distance(w.position, odg.geom)
        LIMIT 1
    ) w
    LEFT JOIN shipment_events se_picked ON s.id = se_picked.shipment_id AND se_picked.event_type = 'picked_up'
    LEFT JOIN shipment_events se_delivered ON s.id = se_delivered.shipment_id AND se_delivered.event_type = 'delivered'
    LEFT JOIN order_items oi ON o.id = oi.order_id
    WHERE s.status = 'delivered'
)
SELECT 
    carrier,
    tranche_distance,
    COUNT(*) AS nombre_expeditions,
    ROUND(AVG(distance_km)::numeric, 2) AS distance_moyenne_km,
    ROUND(AVG(duree_estimee_jours)::numeric, 2) AS duree_estimee_moyenne,
    ROUND(AVG(duree_reelle_jours)::numeric, 2) AS duree_reelle_moyenne,
    ROUND(AVG(valeur_commande)::numeric, 2) AS valeur_moyenne_commande,
    ROUND(CORR(distance_km, duree_reelle_jours)::numeric, 3) AS correlation_distance_duree
FROM expeditions_analyse
GROUP BY carrier, tranche_distance
ORDER BY carrier, 
    CASE tranche_distance
        WHEN '< 100 km' THEN 1
        WHEN '100-300 km' THEN 2
        WHEN '300-600 km' THEN 3
        ELSE 4
    END;

-- -----------------------------------------------------
-- QS13 : Parcours de route approximé et longueur par tournée
-- -----------------------------------------------------
-- Note: Cette requête nécessite des données de routes complètes
WITH routes_geometries AS (
    SELECT 
        r.id AS route_id,
        r.route_date,
        v.plate,
        rs.stop_seq,
        rs.stop_type,
        rs.city,
        CASE 
            WHEN rs.stop_type = 'pickup_warehouse' THEN w.position
            WHEN rs.stop_type = 'delivery_order' THEN odg.geom
            ELSE NULL
        END AS position_geom
    FROM routes r
    JOIN vehicles v ON r.vehicle_id = v.id
    JOIN route_stops rs ON r.id = rs.route_id
    LEFT JOIN warehouses w ON rs.ref_id = w.id AND rs.stop_type = 'pickup_warehouse'
    LEFT JOIN orders o ON rs.ref_id = o.id AND rs.stop_type = 'delivery_order'
    LEFT JOIN order_dest_geo odg ON o.id = odg.order_id
    WHERE (rs.stop_type = 'pickup_warehouse' AND w.position IS NOT NULL)
       OR (rs.stop_type = 'delivery_order' AND odg.geom IS NOT NULL)
    ORDER BY r.id, rs.stop_seq
),
routes_aggregated AS (
    SELECT 
        route_id,
        route_date,
        plate,
        COUNT(*) AS nombre_stops,
        ST_MakeLine(array_agg(position_geom ORDER BY stop_seq)) AS trajet_geom
    FROM routes_geometries
    GROUP BY route_id, route_date, plate
)
SELECT 
    route_id,
    route_date,
    plate,
    nombre_stops,
    ROUND((ST_Length(trajet_geom) / 1000)::numeric, 2) AS longueur_trajet_km,
    ST_AsText(ST_StartPoint(trajet_geom)) AS point_depart,
    ST_AsText(ST_EndPoint(trajet_geom)) AS point_arrivee
FROM routes_aggregated
ORDER BY longueur_trajet_km DESC;

-- -----------------------------------------------------
-- QS14 : Taux de remplissage vs distance de tournée
-- -----------------------------------------------------
WITH routes_details AS (
    SELECT 
        r.id AS route_id,
        v.plate,
        v.capacity_kg,
        v.capacity_m3,
        r.route_date,
        SUM(CASE WHEN rs.stop_type = 'pickup_warehouse' THEN 1 ELSE 0 END) AS nombre_pickups,
        SUM(CASE WHEN rs.stop_type = 'delivery_order' THEN 1 ELSE 0 END) AS nombre_deliveries
    FROM routes r
    JOIN vehicles v ON r.vehicle_id = v.id
    JOIN route_stops rs ON r.id = rs.route_id
    GROUP BY r.id, v.plate, v.capacity_kg, v.capacity_m3, r.route_date
),
routes_geometries AS (
    SELECT 
        r.id AS route_id,
        ST_MakeLine(array_agg(
            CASE 
                WHEN rs.stop_type = 'pickup_warehouse' THEN w.position
                WHEN rs.stop_type = 'delivery_order' THEN odg.geom
            END ORDER BY rs.stop_seq
        )) AS trajet_geom
    FROM routes r
    JOIN route_stops rs ON r.id = rs.route_id
    LEFT JOIN warehouses w ON rs.ref_id = w.id AND rs.stop_type = 'pickup_warehouse'
    LEFT JOIN orders o ON rs.ref_id = o.id AND rs.stop_type = 'delivery_order'
    LEFT JOIN order_dest_geo odg ON o.id = odg.order_id
    WHERE (rs.stop_type = 'pickup_warehouse' AND w.position IS NOT NULL)
       OR (rs.stop_type = 'delivery_order' AND odg.geom IS NOT NULL)
    GROUP BY r.id
),
charges_routes AS (
    SELECT 
        r.id AS route_id,
        SUM(oi.qty_ordered * p.weight_kg) AS poids_total_kg,
        SUM(oi.qty_ordered * p.volume_m3) AS volume_total_m3
    FROM routes r
    JOIN route_stops rs ON r.id = rs.route_id
    JOIN orders o ON rs.ref_id = o.id AND rs.stop_type = 'delivery_order'
    JOIN order_items oi ON o.id = oi.order_id
    JOIN products p ON oi.product_id = p.id
    GROUP BY r.id
)
SELECT 
    rd.route_id,
    rd.plate,
    rd.route_date,
    rd.nombre_pickups,
    rd.nombre_deliveries,
    ROUND((ST_Length(rg.trajet_geom) / 1000)::numeric, 2) AS distance_km,
    ROUND(cr.poids_total_kg, 2) AS poids_total_kg,
    ROUND(cr.volume_total_m3, 3) AS volume_total_m3,
    ROUND((cr.poids_total_kg / rd.capacity_kg * 100)::numeric, 1) AS taux_remplissage_poids,
    ROUND((cr.volume_total_m3 / rd.capacity_m3 * 100)::numeric, 1) AS taux_remplissage_volume,
    CASE 
        WHEN ST_Length(rg.trajet_geom) / 1000 < 200 THEN 'Courte (<200km)'
        WHEN ST_Length(rg.trajet_geom) / 1000 < 500 THEN 'Moyenne (200-500km)'
        ELSE 'Longue (≥500km)'
    END AS categorie_distance
FROM routes_details rd
LEFT JOIN routes_geometries rg ON rd.route_id = rg.route_id
LEFT JOIN charges_routes cr ON rd.route_id = cr.route_id
WHERE rg.trajet_geom IS NOT NULL
ORDER BY distance_km DESC;

-- -----------------------------------------------------
-- QS15 : Concentration de la demande par zone
-- -----------------------------------------------------
WITH densite_commandes AS (
    SELECT 
        w.id AS warehouse_id,
        w.name AS entrepot,
        w.city AS ville_entrepot,
        w.country AS pays_entrepot,
        ST_Buffer(w.position, 100000) AS zone_100km,  -- Zone de 100km de rayon
        COUNT(DISTINCT o.id) AS commandes_dans_zone,
        SUM(oi.qty_ordered) AS quantite_dans_zone,
        ROUND(AVG(ST_Distance(w.position, odg.geom) / 1000)::numeric, 2) AS distance_moyenne_km
    FROM warehouses w
    CROSS JOIN LATERAL (
        SELECT 
            o.id,
            odg.geom
        FROM orders o
        JOIN order_dest_geo odg ON o.id = odg.order_id
        WHERE ST_DWithin(w.position, odg.geom, 100000)
          AND o.status != 'cancelled'
    ) AS commandes_proches
    JOIN orders o ON commandes_proches.id = o.id
    JOIN order_dest_geo odg ON o.id = odg.order_id
    JOIN order_items oi ON o.id = oi.order_id
    GROUP BY w.id, w.name, w.city, w.country
)
SELECT 
    entrepot,
    ville_entrepot,
    pays_entrepot,
    commandes_dans_zone,
    quantite_dans_zone,
    distance_moyenne_km,
    ROUND(quantite_dans_zone / NULLIF(distance_moyenne_km, 0), 2) AS densite_quantite_par_km,
    CASE 
        WHEN commandes_dans_zone >= 15 THEN 'Très haute concentration'
        WHEN commandes_dans_zone >= 8 THEN 'Haute concentration'
        WHEN commandes_dans_zone >= 3 THEN 'Concentration moyenne'
        ELSE 'Faible concentration'
    END AS niveau_concentration,
    RANK() OVER (ORDER BY commandes_dans_zone DESC) AS rang_concentration
FROM densite_commandes
ORDER BY densite_quantite_par_km DESC NULLS LAST;

-- -----------------------------------------------------
-- QS16 : Optimisation des tournées par clustering spatial
-- -----------------------------------------------------
WITH destinations_clustering AS (
    SELECT 
        odg.geom,
        o.dest_city,
        o.dest_country,
        ST_ClusterDBSCAN(odg.geom, 50000, 3) OVER (PARTITION BY o.dest_country) AS cluster_id
    FROM order_dest_geo odg
    JOIN orders o ON odg.order_id = o.id
    WHERE o.status NOT IN ('cancelled', 'delivered')
      AND o.order_date >= CURRENT_DATE - INTERVAL '7 days'
),
clusters_analysis AS (
    SELECT 
        dest_country,
        cluster_id,
        COUNT(*) AS nombre_destinations,
        ST_Centroid(ST_Collect(geom)) AS centre_cluster,
        ST_ConvexHull(ST_Collect(geom)) AS enveloppe_cluster
    FROM destinations_clustering
    WHERE cluster_id IS NOT NULL
    GROUP BY dest_country, cluster_id
    HAVING COUNT(*) >= 3
)
SELECT 
    dest_country AS pays,
    cluster_id,
    nombre_destinations,
    ROUND((ST_Area(enveloppe_cluster) / 1000000)::numeric, 2) AS surface_km2,
    ROUND((ST_Perimeter(enveloppe_cluster) / 1000)::numeric, 2) AS perimetre_km,
    CASE 
        WHEN ST_Area(enveloppe_cluster) / 1000000 < 100 THEN 'Petit cluster'
        WHEN ST_Area(enveloppe_cluster) / 1000000 < 500 THEN 'Cluster moyen'
        ELSE 'Grand cluster'
    END AS taille_cluster
FROM clusters_analysis
ORDER BY nombre_destinations DESC;

-- -----------------------------------------------------
-- QS17 : Zones de couverture optimale des entrepôts
-- -----------------------------------------------------
WITH voronoi_zones AS (
    SELECT 
        ST_VoronoiPolygons(ST_Collect(w.position)) AS voronoi_geom
    FROM warehouses w
),
voronoi_dumped AS (
    SELECT 
        (ST_Dump(vz.voronoi_geom)).geom AS zone_voronoi
    FROM voronoi_zones vz
),
warehouse_list AS (
    SELECT 
        w.name AS entrepot,
        w.city AS ville_entrepot,
        w.position
    FROM warehouses w
),
entrepot_voronoi AS (
    SELECT 
        wl.entrepot,
        wl.ville_entrepot,
        vd.zone_voronoi
    FROM voronoi_dumped vd
    CROSS JOIN warehouse_list wl
    WHERE ST_Contains(vd.zone_voronoi, wl.position)
),
commandes_par_zone AS (
    SELECT 
        ev.entrepot,
        ev.ville_entrepot,
        COUNT(DISTINCT o.id) AS commandes_couvertes,
        SUM(oi.qty_ordered) AS quantite_couverte,
        ROUND((ST_Area(ev.zone_voronoi) / 1000000)::numeric, 2) AS surface_zone_km2,
        ROUND((AVG(ST_Distance(wl.position, odg.geom)) / 1000)::numeric, 2) AS distance_moyenne_km
    FROM entrepot_voronoi ev
    JOIN warehouse_list wl ON ev.entrepot = wl.entrepot AND ev.ville_entrepot = wl.ville_entrepot
    JOIN order_dest_geo odg ON ST_Contains(ev.zone_voronoi, odg.geom)
    JOIN orders o ON odg.order_id = o.id
    JOIN order_items oi ON o.id = oi.order_id
    WHERE o.status != 'cancelled'
    GROUP BY ev.entrepot, ev.ville_entrepot, ev.zone_voronoi, wl.position
)
SELECT 
    entrepot,
    ville_entrepot,
    commandes_couvertes,
    quantite_couverte,
    surface_zone_km2,
    distance_moyenne_km,
    ROUND(quantite_couverte / NULLIF(surface_zone_km2, 0), 2) AS densite_par_km2,
    CASE 
        WHEN distance_moyenne_km < 100 THEN 'Couverture optimale'
        WHEN distance_moyenne_km < 250 THEN 'Couverture correcte'
        ELSE 'Couverture étendue'
    END AS evaluation_couverture
FROM commandes_par_zone
ORDER BY densite_par_km2 DESC;

-- -----------------------------------------------------
-- QS18 : Analyse des corridors logistiques
-- -----------------------------------------------------
WITH corridors AS (
    SELECT 
        w.country AS pays_depart,
        o.dest_country AS pays_arrivee,
        COUNT(DISTINCT s.id) AS nombre_expeditions,
        AVG(ST_Distance(w.position, odg.geom) / 1000) AS distance_moyenne_km,
        AVG((s.eta_date - s.ship_date)::integer) AS duree_moyenne_jours,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY (s.eta_date - s.ship_date)::integer) AS duree_mediane_jours,
        SUM(oi.qty_ordered * oi.unit_price) AS valeur_totale_transportee
    FROM shipments s
    JOIN orders o ON s.order_id = o.id
    JOIN order_dest_geo odg ON o.id = odg.order_id
    CROSS JOIN LATERAL (
        SELECT w.*
        FROM warehouses w
        WHERE w.country = o.dest_country
        ORDER BY ST_Distance(w.position, odg.geom)
        LIMIT 1
    ) w
    JOIN order_items oi ON o.id = oi.order_id
    WHERE s.status = 'delivered'
      AND s.ship_date >= CURRENT_DATE - INTERVAL '90 days'
    GROUP BY w.country, o.dest_country
    HAVING COUNT(DISTINCT s.id) >= 1
)
SELECT 
    pays_depart,
    pays_arrivee,
    nombre_expeditions,
    ROUND(distance_moyenne_km::numeric, 2) AS distance_moyenne_km,
    ROUND(duree_moyenne_jours::numeric, 2) AS duree_moyenne_jours,
    ROUND(duree_mediane_jours::numeric, 2) AS duree_mediane_jours,
    ROUND(valeur_totale_transportee::numeric, 2) AS valeur_totale_transportee,
    ROUND(valeur_totale_transportee / nombre_expeditions, 2) AS valeur_moyenne_par_expedition,
    CASE 
        WHEN nombre_expeditions >= 20 THEN 'Corridor majeur'
        WHEN nombre_expeditions >= 10 THEN 'Corridor secondaire'
        ELSE 'Corridor mineur'
    END AS classification_corridor
FROM corridors
ORDER BY nombre_expeditions DESC;

-- -----------------------------------------------------
-- QS19 : Prévision de demande par zone géographique
-- -----------------------------------------------------
WITH historique_demande AS (
    SELECT 
        DATE_TRUNC('month', o.order_date) AS mois,
        o.dest_country AS pays,
        ST_SnapToGrid(odg.geom, 10000) AS zone_grille,  -- Grille de 10km
        p.sku,
        SUM(oi.qty_ordered) AS quantite_commandee
    FROM orders o
    JOIN order_dest_geo odg ON o.id = odg.order_id
    JOIN order_items oi ON o.id = oi.order_id
    JOIN products p ON oi.product_id = p.id
    WHERE o.order_date >= CURRENT_DATE - INTERVAL '12 months'
      AND o.status != 'cancelled'
    GROUP BY DATE_TRUNC('month', o.order_date), o.dest_country, ST_SnapToGrid(odg.geom, 10000), p.sku
),
tendance_demande AS (
    SELECT 
        pays,
        sku,
        zone_grille,
        COUNT(DISTINCT mois) AS mois_avec_demande,
        AVG(quantite_commandee) AS demande_moyenne_mensuelle,
        STDDEV(quantite_commandee) AS ecart_type_demande,
        MIN(quantite_commandee) AS demande_minimale,
        MAX(quantite_commandee) AS demande_maximale,
        CORR(EXTRACT(MONTH FROM mois)::numeric, quantite_commandee) AS correlation_saisonniere
    FROM historique_demande
    GROUP BY pays, sku, zone_grille
    HAVING COUNT(DISTINCT mois) >= 1
)
SELECT 
    pays,
    sku,
    ST_X(ST_Centroid(zone_grille)) AS centre_x,
    ST_Y(ST_Centroid(zone_grille)) AS centre_y,
    mois_avec_demande,
    ROUND(demande_moyenne_mensuelle::numeric, 2) AS demande_moyenne_mensuelle,
    ROUND(ecart_type_demande::numeric, 2) AS ecart_type_demande,
    demande_minimale,
    demande_maximale,
    ROUND(correlation_saisonniere::numeric, 3) AS correlation_saisonniere,
    ROUND((demande_moyenne_mensuelle + ecart_type_demande)::numeric, 2) AS prevision_optimiste,
    ROUND(GREATEST(demande_moyenne_mensuelle - ecart_type_demande, 0)::numeric, 2) AS prevision_pessimiste,
    CASE 
        WHEN correlation_saisonniere > 0.5 THEN 'Forte saisonnalité'
        WHEN correlation_saisonniere > 0.2 THEN 'Saisonnalité modérée'
        ELSE 'Faible saisonnalité'
    END AS type_saisonnalite
FROM tendance_demande
ORDER BY demande_moyenne_mensuelle DESC;

-- -----------------------------------------------------
-- QS20 : Optimisation multi-critères pour nouveaux entrepôts
-- -----------------------------------------------------
WITH zones_candidates AS (
    SELECT 
        ST_SetSRID(ST_MakePoint(lon, lat), 4326) AS point_candidate,
        ST_Transform(ST_SetSRID(ST_MakePoint(lon, lat), 4326), 3857) AS point_candidate_3857,
        ville,
        pays
    FROM (VALUES
        (5.3698, 43.2965, 'Marseille', 'France'),      -- Sud-Est France
        (-1.6778, 48.1173, 'Rennes', 'France'),        -- Ouest France
        (8.5417, 47.3769, 'Zurich', 'Suisse'),         -- Suisse
        (4.3517, 50.8503, 'Bruxelles', 'Belgique'),    -- Belgique
        (12.5674, 41.8719, 'Rome', 'Italie'),          -- Italie du Sud
        (8.6821, 50.1109, 'Francfort', 'Allemagne')    -- Centre Allemagne
    ) AS candidates(lon, lat, ville, pays)
),
analyse_candidates AS (
    SELECT 
        zc.ville,
        zc.pays,
        zc.point_candidate_3857,
        -- 1. Distance aux entrepôts existants (éviter la concurrence)
        MIN(ST_Distance(zc.point_candidate_3857, w.position) / 1000) AS distance_entrepot_plus_proche_km,
        -- 2. Nombre de commandes dans un rayon de 200km
        COUNT(DISTINCT o.id) AS commandes_dans_rayon_200km,
        -- 3. Valeur potentielle des commandes
        SUM(oi.qty_ordered * oi.unit_price) AS valeur_potentielle,
        -- 4. Diversité des produits demandés
        COUNT(DISTINCT p.sku) AS produits_differents,
        -- 5. Distance moyenne aux commandes dans le rayon
        AVG(ST_Distance(zc.point_candidate_3857, odg.geom) / 1000) AS distance_moyenne_commandes_km
    FROM zones_candidates zc
    LEFT JOIN order_dest_geo odg ON ST_DWithin(zc.point_candidate_3857, odg.geom, 200000)
    LEFT JOIN orders o ON odg.order_id = o.id AND o.status != 'cancelled'
    LEFT JOIN order_items oi ON o.id = oi.order_id
    LEFT JOIN products p ON oi.product_id = p.id
    CROSS JOIN warehouses w
    GROUP BY zc.ville, zc.pays, zc.point_candidate_3857
)
SELECT 
    ville,
    pays,
    ROUND(distance_entrepot_plus_proche_km::numeric, 2) AS distance_entrepot_plus_proche_km,
    commandes_dans_rayon_200km,
    ROUND(valeur_potentielle::numeric, 2) AS valeur_potentielle,
    produits_differents,
    ROUND(distance_moyenne_commandes_km::numeric, 2) AS distance_moyenne_commandes_km,
    -- Score composite (plus élevé = meilleur)
    ROUND((
        (COALESCE(commandes_dans_rayon_200km, 0) * 0.3) +
        (COALESCE(valeur_potentielle, 0) / 1000 * 0.25) +
        (COALESCE(produits_differents, 0) * 0.2) +
        (CASE WHEN distance_entrepot_plus_proche_km > 150 THEN 100 ELSE distance_entrepot_plus_proche_km * 0.67 END * 0.15) +
        (CASE WHEN distance_moyenne_commandes_km < 100 THEN 100 ELSE 200 - distance_moyenne_commandes_km END * 0.1)
    )::numeric, 2) AS score_implantation,
    CASE 
        WHEN distance_entrepot_plus_proche_km < 100 THEN 'Zone saturée'
        WHEN commandes_dans_rayon_200km > 50 THEN 'Forte demande'
        WHEN commandes_dans_rayon_200km > 20 THEN 'Demande moyenne'
        ELSE 'Demande faible'
    END AS evaluation_demande,
    CASE 
        WHEN distance_moyenne_commandes_km < 80 THEN 'Couverture optimale possible'
        WHEN distance_moyenne_commandes_km < 150 THEN 'Couverture correcte'
        ELSE 'Couverture limitée'
    END AS evaluation_couverture
FROM analyse_candidates
ORDER BY score_implantation DESC;