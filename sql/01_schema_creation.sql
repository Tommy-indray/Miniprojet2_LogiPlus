-- =================================================================
-- MINIPROJET N°2 : SYSTÈME DE GESTION LOGISTIQUE SPATIALE - LOGIPLUS
-- =================================================================
-- Auteur : INDRAY Christommy
-- Date : Janvier 2026
-- Description : Script SQL complet pour la création, le peuplement et 
--               la gestion de la base de données de logistique spatiale
-- 
-- IMPORTANT : Ce script utilise PostgreSQL 14+ avec l'extension PostGIS
-- Toutes les distances sont calculées en mètres dans le système Web Mercator (EPSG:3857)
-- =================================================================

-- ============================================
-- PARTIE 1 : CONFIGURATION ET CRÉATION DU SCHÉMA
-- ============================================

-- -----------------------------------------------------
-- 1.1 Configuration de l'environnement
-- -----------------------------------------------------
SET client_encoding = 'UTF8';
SET TIMEZONE = 'Europe/Paris';

-- Création du schéma dédié à la logistique spatiale
CREATE SCHEMA IF NOT EXISTS logistik;
SET search_path TO logistik, public;

-- Activation de l'extension PostGIS (CRITIQUE)
CREATE EXTENSION IF NOT EXISTS postgis;

-- -----------------------------------------------------
-- 1.2 Création des tables métier avec intégration spatiale
-- -----------------------------------------------------
-- NOTE TECHNIQUE : Choix d'EPSG:3857 (Web Mercator) pour :
-- 1. Calculs de distance en mètres (métrique euclidienne)
-- 2. Compatibilité avec les index GIST pour performances optimales
-- 3. Standard pour les applications cartographiques web

-- 1.2.1 Table des entrepôts (avec position spatiale)
CREATE TABLE IF NOT EXISTS warehouses (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name TEXT NOT NULL,
    city TEXT NOT NULL,
    country TEXT NOT NULL,
    position geometry(Point, 3857) NOT NULL,  -- Stockage en Web Mercator
    UNIQUE (name, city, country)
);

-- Index GIST pour les requêtes spatiales (KNN, distances, rayons)
CREATE INDEX IF NOT EXISTS warehouses_position_gist ON warehouses USING GIST (position);
CREATE INDEX IF NOT EXISTS warehouses_country_idx ON warehouses (country);

-- 1.2.2 Table des produits
CREATE TABLE IF NOT EXISTS products (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sku TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    weight_kg NUMERIC(10,3) NOT NULL CHECK (weight_kg >= 0),
    volume_m3 NUMERIC(12,4) NOT NULL CHECK (volume_m3 >= 0)
);

-- 1.2.3 Table d'inventaire
CREATE TABLE IF NOT EXISTS inventory (
    warehouse_id BIGINT NOT NULL REFERENCES warehouses(id) ON DELETE CASCADE,
    product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    qty_on_hand INTEGER NOT NULL CHECK (qty_on_hand >= 0),
    safety_stock INTEGER NOT NULL CHECK (safety_stock >= 0),
    PRIMARY KEY (warehouse_id, product_id)
);

CREATE INDEX IF NOT EXISTS inventory_wh_idx ON inventory (warehouse_id);
CREATE INDEX IF NOT EXISTS inventory_prod_idx ON inventory (product_id);

-- 1.2.4 Table des commandes
CREATE TABLE IF NOT EXISTS orders (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_no TEXT NOT NULL UNIQUE,
    customer_name TEXT NOT NULL,
    order_date DATE NOT NULL,
    dest_city TEXT NOT NULL,
    dest_country TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('created', 'confirmed', 'shipped', 'delivered', 'cancelled'))
);

CREATE INDEX IF NOT EXISTS orders_date_idx ON orders (order_date);
CREATE INDEX IF NOT EXISTS orders_status_idx ON orders (status);

-- 1.2.5 Table des items de commande
CREATE TABLE IF NOT EXISTS order_items (
    order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    qty_ordered INTEGER NOT NULL CHECK (qty_ordered > 0),
    unit_price NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0),
    PRIMARY KEY (order_id, product_id)
);

CREATE INDEX IF NOT EXISTS order_items_prod_idx ON order_items (product_id);

-- 1.2.6 Table des expéditions
CREATE TABLE IF NOT EXISTS shipments (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    carrier TEXT NOT NULL,
    ship_date DATE NOT NULL,
    eta_date DATE NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('created', 'in_transit', 'delivered', 'exception', 'cancelled'))
);

CREATE INDEX IF NOT EXISTS shipments_order_idx ON shipments (order_id);
CREATE INDEX IF NOT EXISTS shipments_eta_idx ON shipments (eta_date);

-- 1.2.7 Table des événements d'expédition
CREATE TABLE IF NOT EXISTS shipment_events (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    shipment_id BIGINT NOT NULL REFERENCES shipments(id) ON DELETE CASCADE,
    event_time TIMESTAMPTZ NOT NULL,
    event_type TEXT NOT NULL CHECK (event_type IN ('created', 'picked_up', 'in_transit', 'out_for_delivery', 'delivered', 'exception')),
    location_city TEXT NOT NULL,
    notes TEXT DEFAULT ''
);

CREATE INDEX IF NOT EXISTS shipment_events_idx ON shipment_events (shipment_id, event_time DESC);

-- 1.2.8 Table des véhicules
CREATE TABLE IF NOT EXISTS vehicles (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    plate TEXT NOT NULL UNIQUE,
    capacity_kg NUMERIC(12,2) NOT NULL CHECK (capacity_kg > 0),
    capacity_m3 NUMERIC(12,3) NOT NULL CHECK (capacity_m3 > 0),
    home_warehouse_id BIGINT NOT NULL REFERENCES warehouses(id) ON DELETE RESTRICT
);

-- 1.2.9 Table des tournées
CREATE TABLE IF NOT EXISTS routes (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    vehicle_id BIGINT NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
    route_date DATE NOT NULL
);

CREATE INDEX IF NOT EXISTS routes_idx ON routes (vehicle_id, route_date);

-- 1.2.10 Table des arrêts de tournée
CREATE TABLE IF NOT EXISTS route_stops (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    route_id BIGINT NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
    stop_seq INTEGER NOT NULL CHECK (stop_seq >= 1),
    stop_type TEXT NOT NULL CHECK (stop_type IN ('pickup_warehouse', 'delivery_order')),
    ref_id BIGINT NOT NULL,
    city TEXT NOT NULL,
    UNIQUE (route_id, stop_seq)
);

-- 1.2.11 Table spatiale des destinations de commandes (SÉPARÉE comme demandé)
CREATE TABLE IF NOT EXISTS order_dest_geo (
    order_id BIGINT PRIMARY KEY REFERENCES orders(id) ON DELETE CASCADE,
    geom geometry(Point, 3857) NOT NULL
);

-- Index GIST critique pour les requêtes spatiales
CREATE INDEX IF NOT EXISTS order_dest_geo_geom_gist ON order_dest_geo USING GIST (geom);