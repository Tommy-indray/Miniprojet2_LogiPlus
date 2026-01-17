### Miniprojet 2 : LogiPlus

## Contexte
Système de gestion logistique spatiale pour optimiser les opérations de la société LogiPlus, qui rencontre des retards, ruptures de stock locales et écarts de performance entre transporteurs.

## Objectifs
- Prioriser produits/entrepôts critiques avec analyse géographique
- Améliorer fiabilité des expéditions selon distances
- Réduire ruptures locales via rééquilibrage intra-pays
- Optimiser taux de remplissage des tournées

## Technologies
- SGBD : PostgreSQL 14+
- Extension : PostGIS 3+
- SRID : EPSG:3857 (Web Mercator)
- Schéma : logistik

## Structure des fichiers
# Scripts SQL (à exécuter dans l'ordre) :
- 01_schema_creation.sql - Création du schéma, tables et index
- 02_data_insertion.sql - Données de test avec géométries spatiales
- 03_business_queries.sql - 12 questions métier classiques
- 04_spatial_queries.sql - 20 questions avec analyse spatiale
- 05_optimization.sql - Indexation avancée et optimisation
- 06_validation_tests.sql - Tests de validation et instructions
# Résultats des requêtes :
- business.pdf
- spatial.pdf
# Explications techniques : 
- technic.pdf
# Diagramme des tables :
- diagram.png

## Questions implémentées
# Métier (12 questions)
- Q1 : Top 10 produits par quantité (30 derniers jours)
- Q2 : Commandes en retard
- Q3 : Références sous safety_stock par entrepôt
- Q4 : Valeur des ventes par pays
- Q5 : Valeur totale par commande
- Q6 : Dernier événement par expédition
- Q7 : Top 5 entrepôts par volume expédié
- Q8 : Top 10 produits par CA
- Q9 : Taux de service quotidien
- Q10 : Expéditions livrées sans événement
- Q11 : Items orphelins
- Q12 : Commandes "à risque"
# Spatiales (20 questions)
- QS1 : Appariement commande → entrepôt le plus proche
- QS2 : Portée moyenne des entrepôts
- QS3 : Classement entrepôts par volume attribué
- QS4 : Distance moyenne par produit
- QS5 : Segmentation en bandes de distance
- QS6 : Fiabilité transporteur par distance
- QS7 : Retards anormaux par lane et distance
- QS8 : Rééquilibrage intra-pays minimal
- QS9 : Couples d'entrepôts éligibles au transfert
- QS10 : "Reorder list" avec rayon de desserte
- QS11 : Choix du dépôt d'expédition alternatif
- QS12 : Impact distance sur coût/temps
- QS13 : Parcours de route approximé
- QS14 : Taux de remplissage vs distance
- QS15 : Concentration de la demande par zone
- QS16 : Optimisation par clustering spatial
- QS17 : Zones de couverture optimale
- QS18 : Analyse des corridors logistiques
- QS19 : Prévision de demande par zone
- QS20 : Optimisation multi-critères nouveaux entrepôts

## Optimisations techniques
# Indexation spatiale
- Index GIST sur toutes les colonnes geometry(Point, 3857)
- Opérateur KNN (<->) pour recherches de proximité
- Index composite pour requêtes fréquentes
# Performances
- Distances calculées en mètres (métrique euclidienne)
- Transformation WGS84 → 3857 à l'insertion
- Requêtes optimisées avec LATERAL JOIN

## Données de test
- 10 entrepôts en Europe
- 12 produits avec poids/volume
- 15 commandes clients
- 11 expéditions avec suivi
- 7 véhicules de transport
- Géométries spatiales pour toutes les destinations

## Validation
# Le projet inclut des tests de validation :
- Intégrité des géométries spatiales
- Cohérence des données
- Performances des requêtes
- Utilisation des index GIST

## Rendu
- Date limite : 18/01/2026