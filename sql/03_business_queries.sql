-- ============================================
-- PARTIE 3 : QUESTIONS MÉTIER (12 QUESTIONS)
-- ============================================

-- -----------------------------------------------------
-- Q1 : Top 10 produits par quantité sur les 30 derniers jours
-- -----------------------------------------------------
SELECT 
    p.sku,
    p.name,
    SUM(oi.qty_ordered) AS quantite_totale,
    COUNT(DISTINCT o.id) AS nombre_commandes
FROM order_items oi
JOIN orders o ON oi.order_id = o.id
JOIN products p ON oi.product_id = p.id
WHERE o.order_date >= CURRENT_DATE - INTERVAL '30 days'
  AND o.status != 'cancelled'
GROUP BY p.id, p.sku, p.name
ORDER BY quantite_totale DESC
LIMIT 10;

-- -----------------------------------------------------
-- Q2 : Commandes en retard
-- -----------------------------------------------------
SELECT 
    o.order_no,
    o.customer_name,
    o.dest_city,
    o.dest_country,
    s.eta_date,
    s.ship_date,
    s.carrier,
    CURRENT_DATE - s.eta_date AS jours_retard
FROM orders o
JOIN shipments s ON o.id = s.order_id
WHERE s.eta_date < CURRENT_DATE 
  AND s.status NOT IN ('delivered', 'cancelled')
ORDER BY jours_retard DESC;

-- -----------------------------------------------------
-- Q3 : Par entrepôt - nombre de références sous safety_stock
-- -----------------------------------------------------
SELECT 
    w.name AS entrepot,
    w.city,
    w.country,
    COUNT(CASE WHEN i.qty_on_hand < i.safety_stock THEN 1 END) AS produits_en_dessous_securite,
    COUNT(*) AS total_references
FROM warehouses w
JOIN inventory i ON w.id = i.warehouse_id
GROUP BY w.id, w.name, w.city, w.country
ORDER BY produits_en_dessous_securite DESC;

-- -----------------------------------------------------
-- Q4 : Valeur des ventes par pays sur 30 jours
-- -----------------------------------------------------
SELECT 
    o.dest_country AS pays_destination,
    COUNT(DISTINCT o.id) AS nombre_commandes,
    SUM(oi.qty_ordered) AS quantite_totale,
    SUM(oi.qty_ordered * oi.unit_price) AS chiffre_affaires,
    ROUND(AVG(oi.qty_ordered * oi.unit_price), 2) AS panier_moyen
FROM orders o
JOIN order_items oi ON o.id = oi.order_id
WHERE o.order_date >= CURRENT_DATE - INTERVAL '30 days'
  AND o.status != 'cancelled'
GROUP BY o.dest_country
ORDER BY chiffre_affaires DESC;

-- -----------------------------------------------------
-- Q5 : Valeur totale par commande
-- -----------------------------------------------------
SELECT 
    o.order_no,
    o.customer_name,
    o.order_date,
    COUNT(oi.product_id) AS nombre_produits,
    SUM(oi.qty_ordered) AS quantite_totale,
    SUM(oi.qty_ordered * oi.unit_price) AS valeur_totale,
    ROUND(SUM(oi.qty_ordered * oi.unit_price) / SUM(oi.qty_ordered), 2) AS prix_moyen_unitaire
FROM orders o
JOIN order_items oi ON o.id = oi.order_id
WHERE o.status != 'cancelled'
GROUP BY o.id, o.order_no, o.customer_name, o.order_date
ORDER BY valeur_totale DESC;

-- -----------------------------------------------------
-- Q6 : Par expédition - dernier événement
-- -----------------------------------------------------
SELECT 
    s.id AS shipment_id,
    o.order_no,
    s.carrier,
    s.status,
    se.event_time AS dernier_evenement,
    se.event_type AS type_evenement,
    se.location_city AS ville_evenement
FROM shipments s
JOIN orders o ON s.order_id = o.id
LEFT JOIN LATERAL (
    SELECT se1.*
    FROM shipment_events se1
    WHERE se1.shipment_id = s.id
    ORDER BY se1.event_time DESC
    LIMIT 1
) se ON true
ORDER BY se.event_time DESC;

-- -----------------------------------------------------
-- Q7 : Top 5 entrepôts par volume expédié le mois dernier
-- -----------------------------------------------------
WITH exp_warehouse AS (
    SELECT 
        w.id,
        w.name AS entrepot,
        w.city,
        w.country,
        SUM(oi.qty_ordered * p.volume_m3) AS volume_expedie_m3,
        SUM(oi.qty_ordered * p.weight_kg) AS poids_expedie_kg,
        COUNT(DISTINCT s.id) AS nombre_expeditions
    FROM warehouses w
    JOIN inventory i ON w.id = i.warehouse_id
    JOIN products p ON i.product_id = p.id
    JOIN order_items oi ON p.id = oi.product_id
    JOIN orders o ON oi.order_id = o.id
    JOIN shipments s ON o.id = s.order_id
    WHERE s.ship_date >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month')
      AND s.ship_date < DATE_TRUNC('month', CURRENT_DATE)
      AND s.status != 'cancelled'
    GROUP BY w.id, w.name, w.city, w.country
)
SELECT 
    entrepot,
    city,
    country,
    ROUND(volume_expedie_m3::numeric, 2) AS volume_expedie_m3,
    ROUND(poids_expedie_kg::numeric, 2) AS poids_expedie_kg,
    nombre_expeditions,
    RANK() OVER (ORDER BY volume_expedie_m3 DESC) AS classement_volume
FROM exp_warehouse
ORDER BY volume_expedie_m3 DESC
LIMIT 5;

-- -----------------------------------------------------
-- Q8 : Top 10 produits par CA sur 30 jours
-- -----------------------------------------------------
SELECT 
    p.sku,
    p.name,
    SUM(oi.qty_ordered) AS quantite_vendue,
    SUM(oi.qty_ordered * oi.unit_price) AS chiffre_affaires,
    ROUND(SUM(oi.qty_ordered * oi.unit_price) / SUM(oi.qty_ordered), 2) AS prix_moyen,
    RANK() OVER (ORDER BY SUM(oi.qty_ordered * oi.unit_price) DESC) AS classement_ca,
    RANK() OVER (ORDER BY SUM(oi.qty_ordered) DESC) AS classement_quantite
FROM products p
JOIN order_items oi ON p.id = oi.product_id
JOIN orders o ON oi.order_id = o.id
WHERE o.order_date >= CURRENT_DATE - INTERVAL '30 days'
  AND o.status != 'cancelled'
GROUP BY p.id, p.sku, p.name
ORDER BY chiffre_affaires DESC
LIMIT 10;

-- -----------------------------------------------------
-- Q9 : Taux de service quotidien = livrées / totales
-- -----------------------------------------------------
WITH daily_stats AS (
    SELECT 
        DATE(s.ship_date) AS jour,
        COUNT(*) AS total_expeditions,
        COUNT(CASE WHEN s.status = 'delivered' THEN 1 END) AS expeditees_livrees,
        COUNT(CASE WHEN s.status = 'exception' THEN 1 END) AS expeditees_exception
    FROM shipments s
    WHERE s.ship_date >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY DATE(s.ship_date)
)
SELECT 
    jour,
    total_expeditions,
    expeditees_livrees,
    expeditees_exception,
    ROUND((expeditees_livrees::DECIMAL / NULLIF(total_expeditions, 0) * 100), 2) AS taux_livraison_pourcent,
    ROUND((expeditees_exception::DECIMAL / NULLIF(total_expeditions, 0) * 100), 2) AS taux_exception_pourcent
FROM daily_stats
ORDER BY jour DESC;

-- -----------------------------------------------------
-- Q10 : Expéditions 'delivered' sans événement 'delivered'
-- -----------------------------------------------------
SELECT 
    s.id AS shipment_id,
    o.order_no,
    s.carrier,
    s.ship_date,
    s.eta_date,
    s.status,
    (SELECT COUNT(*) FROM shipment_events se WHERE se.shipment_id = s.id) AS nombre_evenements,
    (SELECT MAX(event_time) FROM shipment_events se WHERE se.shipment_id = s.id) AS dernier_evenement
FROM shipments s
JOIN orders o ON s.order_id = o.id
WHERE s.status = 'delivered'
  AND NOT EXISTS (
      SELECT 1 FROM shipment_events se 
      WHERE se.shipment_id = s.id AND se.event_type = 'delivered'
  )
ORDER BY s.ship_date DESC;

-- -----------------------------------------------------
-- Q11 : Items orphelins - order_items sans order
-- -----------------------------------------------------
SELECT 
    oi.order_id,
    oi.product_id,
    p.sku,
    p.name,
    oi.qty_ordered,
    oi.unit_price
FROM order_items oi
LEFT JOIN orders o ON oi.order_id = o.id
JOIN products p ON oi.product_id = p.id
WHERE o.id IS NULL
ORDER BY oi.order_id;

-- -----------------------------------------------------
-- Q12 : Commandes "à risque" - inventaire global < besoins
-- -----------------------------------------------------
WITH commande_besoins AS (
    SELECT 
        oi.order_id,
        oi.product_id,
        p.sku,
        p.name,
        oi.qty_ordered AS besoin_commande,
        SUM(oi.qty_ordered) OVER (PARTITION BY oi.product_id) AS besoin_total_produit
    FROM order_items oi
    JOIN products p ON oi.product_id = p.id
    JOIN orders o ON oi.order_id = o.id
    WHERE o.status NOT IN ('cancelled', 'delivered')
),
inventaire_global AS (
    SELECT 
        product_id,
        SUM(qty_on_hand) AS stock_global,
        SUM(safety_stock) AS securite_globale
    FROM inventory
    GROUP BY product_id
)
SELECT 
    cb.sku,
    cb.name,
    cb.besoin_total_produit,
    ig.stock_global,
    ig.securite_globale,
    cb.besoin_total_produit - ig.stock_global AS deficit,
    ROUND((cb.besoin_total_produit::DECIMAL / NULLIF(ig.stock_global, 0) * 100), 2) AS taux_couverture_pourcent,
    COUNT(DISTINCT cb.order_id) AS nombre_commandes_impactees
FROM commande_besoins cb
JOIN inventaire_global ig ON cb.product_id = ig.product_id
WHERE ig.stock_global < cb.besoin_total_produit
GROUP BY cb.product_id, cb.sku, cb.name, cb.besoin_total_produit, ig.stock_global, ig.securite_globale
ORDER BY deficit DESC;