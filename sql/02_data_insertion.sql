-- ============================================
-- PARTIE 2 : PEUPLEMENT DE DONNÉES DE TEST
-- ============================================

-- -----------------------------------------------------
-- 2.1 Insertion des entrepôts avec positions spatiales
-- -----------------------------------------------------
-- TRANSFORMATION : WGS84 (4326) → Web Mercator (3857) pour les calculs métriques
INSERT INTO warehouses (name, city, country, position) VALUES
('WH-Nord', 'Lille', 'France', ST_Transform(ST_SetSRID(ST_MakePoint(3.0573, 50.6292), 4326), 3857)),
('WH-Est', 'Strasbourg', 'France', ST_Transform(ST_SetSRID(ST_MakePoint(7.7521, 48.5734), 4326), 3857)),
('WH-Centro', 'Madrid', 'Espagne', ST_Transform(ST_SetSRID(ST_MakePoint(-3.7038, 40.4168), 4326), 3857)),
('WH-Porto', 'Porto', 'Portugal', ST_Transform(ST_SetSRID(ST_MakePoint(-8.6291, 41.1579), 4326), 3857)),
('WH-Lyon', 'Lyon', 'France', ST_Transform(ST_SetSRID(ST_MakePoint(4.8357, 45.7640), 4326), 3857)),
('WH-Berlin', 'Berlin', 'Allemagne', ST_Transform(ST_SetSRID(ST_MakePoint(13.4050, 52.5200), 4326), 3857)),
('WH-Roma', 'Rome', 'Italie', ST_Transform(ST_SetSRID(ST_MakePoint(12.4964, 41.9028), 4326), 3857)),
('WH-Lisbonne', 'Lisbonne', 'Portugal', ST_Transform(ST_SetSRID(ST_MakePoint(-9.1393, 38.7223), 4326), 3857)),
('WH-Bordeaux', 'Bordeaux', 'France', ST_Transform(ST_SetSRID(ST_MakePoint(-0.5792, 44.8378), 4326), 3857)),
('WH-Milan', 'Milan', 'Italie', ST_Transform(ST_SetSRID(ST_MakePoint(9.1900, 45.4642), 4326), 3857))
ON CONFLICT DO NOTHING;

-- -----------------------------------------------------
-- 2.2 Insertion des produits
-- -----------------------------------------------------
INSERT INTO products (sku, name, weight_kg, volume_m3) VALUES
('SKU-BOX-01', 'Boîte carton S', 0.200, 0.002),
('SKU-BOX-02', 'Boîte carton M', 0.500, 0.006),
('SKU-ELC-10', 'Chargeur USB', 0.080, 0.001),
('SKU-HSE-20', 'Balai multi', 0.900, 0.020),
('SKU-FOO-30', 'Pack biscuits', 0.400, 0.003),
('SKU-TOY-40', 'Jouet éducatif', 0.300, 0.008),
('SKU-BOK-50', 'Livre technique', 0.600, 0.004),
('SKU-CLP-60', 'Papier imprimante', 2.500, 0.015),
('SKU-TOO-70', 'Outil manuel', 1.200, 0.010),
('SKU-COS-80', 'Produit cosmétique', 0.150, 0.001),
('SKU-MED-90', 'Tensiomètre', 0.350, 0.005),
('SKU-SPT-95', 'Ballon de football', 0.420, 0.012)
ON CONFLICT (sku) DO NOTHING;

-- -----------------------------------------------------
-- 2.3 Insertion de l'inventaire
-- -----------------------------------------------------
INSERT INTO inventory (warehouse_id, product_id, qty_on_hand, safety_stock) VALUES
((SELECT id FROM warehouses WHERE name='WH-Nord'), (SELECT id FROM products WHERE sku='SKU-BOX-01'), 500, 150),
((SELECT id FROM warehouses WHERE name='WH-Nord'), (SELECT id FROM products WHERE sku='SKU-BOX-02'), 200, 100),
((SELECT id FROM warehouses WHERE name='WH-Nord'), (SELECT id FROM products WHERE sku='SKU-ELC-10'), 120, 40),
((SELECT id FROM warehouses WHERE name='WH-Est'), (SELECT id FROM products WHERE sku='SKU-BOX-01'), 300, 120),
((SELECT id FROM warehouses WHERE name='WH-Est'), (SELECT id FROM products WHERE sku='SKU-ELC-10'), 30, 50),
((SELECT id FROM warehouses WHERE name='WH-Est'), (SELECT id FROM products WHERE sku='SKU-HSE-20'), 80, 30),
((SELECT id FROM warehouses WHERE name='WH-Centro'), (SELECT id FROM products WHERE sku='SKU-BOX-02'), 180, 90),
((SELECT id FROM warehouses WHERE name='WH-Centro'), (SELECT id FROM products WHERE sku='SKU-FOO-30'), 400, 120),
((SELECT id FROM warehouses WHERE name='WH-Porto'), (SELECT id FROM products WHERE sku='SKU-FOO-30'), 50, 70),
((SELECT id FROM warehouses WHERE name='WH-Porto'), (SELECT id FROM products WHERE sku='SKU-HSE-20'), 40, 20),
((SELECT id FROM warehouses WHERE name='WH-Lyon'), (SELECT id FROM products WHERE sku='SKU-TOY-40'), 150, 50),
((SELECT id FROM warehouses WHERE name='WH-Berlin'), (SELECT id FROM products WHERE sku='SKU-BOK-50'), 220, 80),
((SELECT id FROM warehouses WHERE name='WH-Roma'), (SELECT id FROM products WHERE sku='SKU-CLP-60'), 75, 25),
((SELECT id FROM warehouses WHERE name='WH-Lisbonne'), (SELECT id FROM products WHERE sku='SKU-COS-80'), 180, 60),
((SELECT id FROM warehouses WHERE name='WH-Bordeaux'), (SELECT id FROM products WHERE sku='SKU-MED-90'), 90, 30),
((SELECT id FROM warehouses WHERE name='WH-Milan'), (SELECT id FROM products WHERE sku='SKU-SPT-95'), 110, 40)
ON CONFLICT DO NOTHING;

-- -----------------------------------------------------
-- 2.4 Insertion des commandes
-- -----------------------------------------------------
INSERT INTO orders (order_no, customer_name, order_date, dest_city, dest_country, status) VALUES
('ORD-1001', 'Client A', '2025-11-25', 'Paris', 'France', 'delivered'),
('ORD-1002', 'Client B', '2025-12-01', 'Lyon', 'France', 'shipped'),
('ORD-1003', 'Client C', '2025-12-05', 'Porto', 'Portugal', 'confirmed'),
('ORD-1004', 'Client D', '2025-12-10', 'Bordeaux', 'France', 'created'),
('ORD-1005', 'Client E', '2025-12-12', 'Munich', 'Allemagne', 'confirmed'),
('ORD-1006', 'Client F', '2025-12-15', 'Milan', 'Italie', 'shipped'),
('ORD-1007', 'Client G', '2025-12-18', 'Barcelone', 'Espagne', 'created'),
('ORD-1008', 'Client H', '2025-12-20', 'Amsterdam', 'Pays-Bas', 'delivered'),
('ORD-1009', 'Client I', '2025-12-22', 'Toulouse', 'France', 'cancelled'),
('ORD-1010', 'Client J', '2025-12-25', 'Lisbonne', 'Portugal', 'confirmed'),
('ORD-1011', 'Client K', '2025-12-28', 'Strasbourg', 'France', 'shipped'),
('ORD-1012', 'Client L', '2025-12-30', 'Berlin', 'Allemagne', 'created'),
('ORD-1013', 'Client M', '2026-01-02', 'Rome', 'Italie', 'confirmed'),
('ORD-1014', 'Client N', '2026-01-05', 'Lille', 'France', 'delivered'),
('ORD-1015', 'Client O', '2026-01-08', 'Madrid', 'Espagne', 'shipped')
ON CONFLICT DO NOTHING;

-- -----------------------------------------------------
-- 2.5 Insertion des items de commande
-- -----------------------------------------------------
INSERT INTO order_items (order_id, product_id, qty_ordered, unit_price) VALUES
((SELECT id FROM orders WHERE order_no='ORD-1001'), (SELECT id FROM products WHERE sku='SKU-BOX-01'), 60, 1.20),
((SELECT id FROM orders WHERE order_no='ORD-1001'), (SELECT id FROM products WHERE sku='SKU-ELC-10'), 20, 7.50),
((SELECT id FROM orders WHERE order_no='ORD-1002'), (SELECT id FROM products WHERE sku='SKU-BOX-02'), 40, 2.20),
((SELECT id FROM orders WHERE order_no='ORD-1002'), (SELECT id FROM products WHERE sku='SKU-HSE-20'), 10, 12.00),
((SELECT id FROM orders WHERE order_no='ORD-1003'), (SELECT id FROM products WHERE sku='SKU-FOO-30'), 90, 1.80),
((SELECT id FROM orders WHERE order_no='ORD-1004'), (SELECT id FROM products WHERE sku='SKU-TOY-40'), 25, 15.00),
((SELECT id FROM orders WHERE order_no='ORD-1005'), (SELECT id FROM products WHERE sku='SKU-BOK-50'), 12, 24.50),
((SELECT id FROM orders WHERE order_no='ORD-1006'), (SELECT id FROM products WHERE sku='SKU-CLP-60'), 5, 45.00),
((SELECT id FROM orders WHERE order_no='ORD-1007'), (SELECT id FROM products WHERE sku='SKU-TOO-70'), 8, 32.00),
((SELECT id FROM orders WHERE order_no='ORD-1008'), (SELECT id FROM products WHERE sku='SKU-COS-80'), 100, 3.50),
((SELECT id FROM orders WHERE order_no='ORD-1009'), (SELECT id FROM products WHERE sku='SKU-BOX-01'), 30, 1.20),
((SELECT id FROM orders WHERE order_no='ORD-1010'), (SELECT id FROM products WHERE sku='SKU-ELC-10'), 45, 7.50),
((SELECT id FROM orders WHERE order_no='ORD-1011'), (SELECT id FROM products WHERE sku='SKU-HSE-20'), 15, 12.00),
((SELECT id FROM orders WHERE order_no='ORD-1012'), (SELECT id FROM products WHERE sku='SKU-FOO-30'), 70, 1.80),
((SELECT id FROM orders WHERE order_no='ORD-1013'), (SELECT id FROM products WHERE sku='SKU-TOY-40'), 18, 15.00),
((SELECT id FROM orders WHERE order_no='ORD-1014'), (SELECT id FROM products WHERE sku='SKU-BOK-50'), 8, 24.50),
((SELECT id FROM orders WHERE order_no='ORD-1015'), (SELECT id FROM products WHERE sku='SKU-CLP-60'), 3, 45.00)
ON CONFLICT DO NOTHING;

-- -----------------------------------------------------
-- 2.6 Insertion des expéditions
-- -----------------------------------------------------
INSERT INTO shipments (order_id, carrier, ship_date, eta_date, status) VALUES
((SELECT id FROM orders WHERE order_no='ORD-1001'), 'FastShip', '2025-11-26', '2025-11-28', 'delivered'),
((SELECT id FROM orders WHERE order_no='ORD-1002'), 'EuroCarrier', '2025-12-02', '2025-12-06', 'in_transit'),
((SELECT id FROM orders WHERE order_no='ORD-1003'), 'IberTrans', '2025-12-06', '2025-12-10', 'created'),
((SELECT id FROM orders WHERE order_no='ORD-1004'), 'FranceLog', '2025-12-11', '2025-12-15', 'created'),
((SELECT id FROM orders WHERE order_no='ORD-1005'), 'DeutschPost', '2025-12-13', '2025-12-20', 'exception'),
((SELECT id FROM orders WHERE order_no='ORD-1006'), 'ItaliaExp', '2025-12-16', '2025-12-19', 'in_transit'),
((SELECT id FROM orders WHERE order_no='ORD-1008'), 'BeneluxLog', '2025-12-21', '2025-12-23', 'delivered'),
((SELECT id FROM orders WHERE order_no='ORD-1010'), 'IberTrans', '2025-12-26', '2025-12-30', 'created'),
((SELECT id FROM orders WHERE order_no='ORD-1011'), 'FastShip', '2025-12-29', '2025-12-31', 'delivered'),
((SELECT id FROM orders WHERE order_no='ORD-1014'), 'FranceLog', '2026-01-06', '2026-01-08', 'in_transit'),
((SELECT id FROM orders WHERE order_no='ORD-1015'), 'EuroCarrier', '2026-01-09', '2026-01-12', 'created')
ON CONFLICT DO NOTHING;

-- -----------------------------------------------------
-- 2.7 Insertion des événements d'expédition
-- -----------------------------------------------------
INSERT INTO shipment_events (shipment_id, event_time, event_type, location_city, notes) VALUES
((SELECT id FROM shipments WHERE order_id = (SELECT id FROM orders WHERE order_no='ORD-1001')), '2025-11-26 08:00+00', 'picked_up', 'Lille', ''),
((SELECT id FROM shipments WHERE order_id = (SELECT id FROM orders WHERE order_no='ORD-1001')), '2025-11-27 09:00+00', 'in_transit', 'Paris', ''),
((SELECT id FROM shipments WHERE order_id = (SELECT id FROM orders WHERE order_no='ORD-1001')), '2025-11-28 10:00+00', 'delivered', 'Paris', ''),
((SELECT id FROM shipments WHERE order_id = (SELECT id FROM orders WHERE order_no='ORD-1002')), '2025-12-02 07:30+00', 'picked_up', 'Strasbourg', ''),
((SELECT id FROM shipments WHERE order_id = (SELECT id FROM orders WHERE order_no='ORD-1002')), '2025-12-03 12:00+00', 'in_transit', 'Dijon', ''),
((SELECT id FROM shipments WHERE order_id = (SELECT id FROM orders WHERE order_no='ORD-1005')), '2025-12-13 09:15+00', 'picked_up', 'Berlin', ''),
((SELECT id FROM shipments WHERE order_id = (SELECT id FROM orders WHERE order_no='ORD-1005')), '2025-12-15 14:30+00', 'exception', 'Francfort', 'Problème douane'),
((SELECT id FROM shipments WHERE order_id = (SELECT id FROM orders WHERE order_no='ORD-1006')), '2025-12-16 11:00+00', 'picked_up', 'Rome', ''),
((SELECT id FROM shipments WHERE order_id = (SELECT id FROM orders WHERE order_no='ORD-1008')), '2025-12-21 08:45+00', 'picked_up', 'Lille', ''),
((SELECT id FROM shipments WHERE order_id = (SELECT id FROM orders WHERE order_no='ORD-1008')), '2025-12-22 16:20+00', 'delivered', 'Amsterdam', ''),
((SELECT id FROM shipments WHERE order_id = (SELECT id FROM orders WHERE order_no='ORD-1011')), '2025-12-29 10:30+00', 'picked_up', 'Strasbourg', ''),
((SELECT id FROM shipments WHERE order_id = (SELECT id FROM orders WHERE order_no='ORD-1011')), '2025-12-30 14:15+00', 'delivered', 'Strasbourg', ''),
((SELECT id FROM shipments WHERE order_id = (SELECT id FROM orders WHERE order_no='ORD-1014')), '2026-01-06 09:00+00', 'picked_up', 'Lille', '')
ON CONFLICT DO NOTHING;

-- -----------------------------------------------------
-- 2.8 Insertion des véhicules
-- -----------------------------------------------------
INSERT INTO vehicles (plate, capacity_kg, capacity_m3, home_warehouse_id) VALUES
('FR-123-AB', 5000.00, 30.000, (SELECT id FROM warehouses WHERE name='WH-Nord')),
('FR-456-CD', 7500.00, 45.000, (SELECT id FROM warehouses WHERE name='WH-Est')),
('ES-789-EF', 10000.00, 60.000, (SELECT id FROM warehouses WHERE name='WH-Centro')),
('PT-012-GH', 3000.00, 20.000, (SELECT id FROM warehouses WHERE name='WH-Porto')),
('FR-345-IJ', 6000.00, 35.000, (SELECT id FROM warehouses WHERE name='WH-Lyon')),
('DE-678-KL', 8000.00, 50.000, (SELECT id FROM warehouses WHERE name='WH-Berlin')),
('IT-901-MN', 5500.00, 40.000, (SELECT id FROM warehouses WHERE name='WH-Roma'))
ON CONFLICT DO NOTHING;

-- -----------------------------------------------------
-- 2.9 Insertion des géométries des destinations (SPATIAL)
-- -----------------------------------------------------
INSERT INTO order_dest_geo (order_id, geom) VALUES
((SELECT id FROM orders WHERE order_no='ORD-1001'), ST_Transform(ST_SetSRID(ST_MakePoint(2.3522, 48.8566), 4326), 3857)), -- Paris
((SELECT id FROM orders WHERE order_no='ORD-1002'), ST_Transform(ST_SetSRID(ST_MakePoint(4.8357, 45.7640), 4326), 3857)), -- Lyon
((SELECT id FROM orders WHERE order_no='ORD-1003'), ST_Transform(ST_SetSRID(ST_MakePoint(-8.6291, 41.1579), 4326), 3857)), -- Porto
((SELECT id FROM orders WHERE order_no='ORD-1004'), ST_Transform(ST_SetSRID(ST_MakePoint(-0.5792, 44.8378), 4326), 3857)), -- Bordeaux
((SELECT id FROM orders WHERE order_no='ORD-1005'), ST_Transform(ST_SetSRID(ST_MakePoint(11.5820, 48.1351), 4326), 3857)), -- Munich
((SELECT id FROM orders WHERE order_no='ORD-1006'), ST_Transform(ST_SetSRID(ST_MakePoint(9.1900, 45.4642), 4326), 3857)), -- Milan
((SELECT id FROM orders WHERE order_no='ORD-1007'), ST_Transform(ST_SetSRID(ST_MakePoint(2.1734, 41.3851), 4326), 3857)), -- Barcelone
((SELECT id FROM orders WHERE order_no='ORD-1008'), ST_Transform(ST_SetSRID(ST_MakePoint(4.9041, 52.3676), 4326), 3857)), -- Amsterdam
((SELECT id FROM orders WHERE order_no='ORD-1009'), ST_Transform(ST_SetSRID(ST_MakePoint(1.4442, 43.6047), 4326), 3857)), -- Toulouse
((SELECT id FROM orders WHERE order_no='ORD-1010'), ST_Transform(ST_SetSRID(ST_MakePoint(-9.1393, 38.7223), 4326), 3857)), -- Lisbonne
((SELECT id FROM orders WHERE order_no='ORD-1011'), ST_Transform(ST_SetSRID(ST_MakePoint(7.7521, 48.5734), 4326), 3857)), -- Strasbourg
((SELECT id FROM orders WHERE order_no='ORD-1012'), ST_Transform(ST_SetSRID(ST_MakePoint(13.4050, 52.5200), 4326), 3857)), -- Berlin
((SELECT id FROM orders WHERE order_no='ORD-1013'), ST_Transform(ST_SetSRID(ST_MakePoint(12.4964, 41.9028), 4326), 3857)), -- Rome
((SELECT id FROM orders WHERE order_no='ORD-1014'), ST_Transform(ST_SetSRID(ST_MakePoint(3.0573, 50.6292), 4326), 3857)), -- Lille
((SELECT id FROM orders WHERE order_no='ORD-1015'), ST_Transform(ST_SetSRID(ST_MakePoint(-3.7038, 40.4168), 4326), 3857)) -- Madrid
ON CONFLICT DO NOTHING;