-- PROJET : INVENTORY ANALYTICS 
-- creation de la base SOURCE et de ses 9 tables

-- Objectif metier : analyser les stocks afin de reduire les ruptures, limiter le surstock, ameliorer la rotation, surveiller les ecarts d'inventaire et evaluer la performance des fournisseurs.

-- Creation de la base de donnees source
DROP DATABASE Inventory_Analytics
CREATE DATABASE Inventory_Analytics;
GO

USE Inventory_Analytics;
GO

-- Entrepots : les 6 sites de stockage (ville, province, capacite en unites)
CREATE TABLE Entrepots (
    id_entrepot     VARCHAR(10) PRIMARY KEY,   
    ville           NVARCHAR(100),
    province        NVARCHAR(100),
    capacite_unites INT                        
);

-- Fournisseurs : les 30 fournisseurs, avec leur delai declare et leur cible de service
CREATE TABLE Fournisseurs (
    id_fournisseur     VARCHAR(10) PRIMARY KEY, 
    nom_fournisseur    NVARCHAR(150),
    pays               NVARCHAR(100),
    delai_moyen_jours  INT,                     
    taux_service_cible DECIMAL(8,4),           
    statut             NVARCHAR(30)             
);

-- Produits : les 200 produits, avec couts, prix et regles de reapprovisionnement
CREATE TABLE Produits (
    id_produit                 VARCHAR(10) PRIMARY KEY,  
    nom_produit                NVARCHAR(200),
    categorie                  NVARCHAR(100),
    sous_categorie             NVARCHAR(100),
    marque                     NVARCHAR(100),
    id_fournisseur_principal   VARCHAR(10),              
    cout_unitaire              DECIMAL(12,2),            
    prix_vente                 DECIMAL(12,2),
    seuil_reapprovisionnement  INT,                      
    stock_securite             INT,                      
    statut_produit             NVARCHAR(30),             
    FOREIGN KEY (id_fournisseur_principal) REFERENCES Fournisseurs(id_fournisseur)
);

-- Stocks :
CREATE TABLE Stocks (
    id_entrepot          VARCHAR(10),
    id_produit           VARCHAR(10),
    quantite_stock       INT,    
    quantite_reservee    INT,    
    quantite_disponible  INT,    
    date_maj             DATE,
    PRIMARY KEY (id_entrepot, id_produit),
    FOREIGN KEY (id_entrepot) REFERENCES Entrepots(id_entrepot),
    FOREIGN KEY (id_produit)  REFERENCES Produits(id_produit)
);

-- Commandes_Fournisseurs 
CREATE TABLE Commandes_Fournisseurs (
    id_commande_fournisseur VARCHAR(15) PRIMARY KEY,  
    date_commande           DATE,
    id_fournisseur          VARCHAR(10),
    id_entrepot             VARCHAR(10),               
    date_prevue_livraison   DATE,
    statut_commande         NVARCHAR(50),             
    FOREIGN KEY (id_fournisseur) REFERENCES Fournisseurs(id_fournisseur),
    FOREIGN KEY (id_entrepot)    REFERENCES Entrepots(id_entrepot)
);

-- Details_Commandes_Fournisseurs 
CREATE TABLE Details_Commandes_Fournisseurs (
    id_ligne_cf             VARCHAR(20) PRIMARY KEY,   
    id_commande_fournisseur VARCHAR(15),
    id_produit              VARCHAR(10),
    quantite_commandee      INT,
    cout_unitaire_achat     DECIMAL(12,2),
    montant_commande        DECIMAL(14,2),             
    FOREIGN KEY (id_commande_fournisseur) REFERENCES Commandes_Fournisseurs(id_commande_fournisseur),
    FOREIGN KEY (id_produit)              REFERENCES Produits(id_produit)
);

-- Livraisons 
CREATE TABLE Livraisons (
    id_livraison            VARCHAR(15) PRIMARY KEY,   
    id_commande_fournisseur VARCHAR(15),
    date_prevue             DATE,
    date_reelle             DATE,
    retard_jours            INT,                       
    livraison_a_temps       BIT,                       
    FOREIGN KEY (id_commande_fournisseur) REFERENCES Commandes_Fournisseurs(id_commande_fournisseur)
);

-- Mouvements_Stock 

CREATE TABLE Mouvements_Stock (
    id_mouvement    VARCHAR(15) PRIMARY KEY,          
    date_mouvement  DATE,
    id_entrepot     VARCHAR(10),
    id_produit      VARCHAR(10),
    type_mouvement  NVARCHAR(50),                      
    quantite        INT,                               
    reference       NVARCHAR(50),                      
    cout_unitaire   DECIMAL(12,2),
    FOREIGN KEY (id_entrepot) REFERENCES Entrepots(id_entrepot),
    FOREIGN KEY (id_produit)  REFERENCES Produits(id_produit)
);

-- Inventaires 
CREATE TABLE Inventaires (
    id_inventaire    VARCHAR(20) PRIMARY KEY,          
    date_inventaire  DATE,
    id_entrepot      VARCHAR(10),
    id_produit       VARCHAR(10),
    stock_theorique  INT,                             
    stock_physique   INT,                              
    ecart_quantite   INT,                              
    valeur_ecart     DECIMAL(14,2),                    
    FOREIGN KEY (id_entrepot) REFERENCES Entrepots(id_entrepot),
    FOREIGN KEY (id_produit)  REFERENCES Produits(id_produit)
);
GO

-- VERIFICATION 
   
SELECT name AS table_creee
FROM sys.tables
ORDER BY name;
GO

SELECT 'Entrepots' AS table_nom, COUNT(*) AS nb_lignes FROM dbo.Entrepots
UNION ALL SELECT 'Fournisseurs', COUNT(*) FROM dbo.Fournisseurs
UNION ALL SELECT 'Produits', COUNT(*) FROM dbo.Produits
UNION ALL SELECT 'Stocks', COUNT(*) FROM dbo.Stocks
UNION ALL SELECT 'Commandes_Fournisseurs', COUNT(*) FROM dbo.Commandes_Fournisseurs
UNION ALL SELECT 'Details_Commandes_Fournisseurs', COUNT(*) FROM dbo.Details_Commandes_Fournisseurs
UNION ALL SELECT 'Livraisons', COUNT(*) FROM dbo.Livraisons
UNION ALL SELECT 'Mouvements_Stock', COUNT(*) FROM dbo.Mouvements_Stock
UNION ALL SELECT 'Inventaires', COUNT(*) FROM dbo.Inventaires;
GO

SELECT
    (SELECT COUNT(*) FROM dbo.Inventaires)                                       AS nb_inventaires,
    (SELECT SUM(quantite_stock) FROM dbo.Stocks)                                 AS stock_total_unites,
    (SELECT COUNT(*) FROM dbo.Stocks WHERE quantite_disponible = 0)              AS lignes_en_rupture,
    (SELECT COUNT(*) FROM dbo.Inventaires WHERE ecart_quantite <> 0)             AS inventaires_avec_ecart,
    (SELECT COUNT(*) FROM dbo.Inventaires WHERE date_inventaire > '2026-08-31')  AS inventaires_hors_periode,
    (SELECT CAST(AVG(CAST(livraison_a_temps AS FLOAT)) AS DECIMAL(5,3)) FROM dbo.Livraisons) AS taux_livraison_a_temps;
    GO

--creation de l'entrepot Inventory_DW (modele en etoile)

CREATE DATABASE Inventory_DW;
GO
USE Inventory_DW;
GO

CREATE SCHEMA stg;   -- zone de transit (optionnelle)
GO
CREATE SCHEMA dwh;   -- entrepot (dimensions et faits)
GO
CREATE SCHEMA etl;   -- journalisation des chargements
GO

--JOURNAL DES CHARGEMENTS (audit ETL)

CREATE TABLE etl.Journal_Chargement (
    journal_id       INT IDENTITY(1,1) PRIMARY KEY,
    nom_package      NVARCHAR(100) NOT NULL,
    date_debut       DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    date_fin         DATETIME2     NULL,
    lignes_lues      INT           NULL,
    lignes_chargees  INT           NULL,
    lignes_rejetees  INT           NULL,
    statut           NVARCHAR(20)  NULL,  
    message          NVARCHAR(500) NULL
);
GO

--DIMENSIONS

CREATE TABLE dwh.Dim_Date (
    date_key         INT         NOT NULL PRIMARY KEY,   -- AAAAMMJJ
    date_complete    DATE        NOT NULL UNIQUE,
    annee            INT         NOT NULL,
    numero_mois      INT         NOT NULL,
    mois             NVARCHAR(20) NOT NULL,
    trimestre        CHAR(2)     NOT NULL,
    annee_mois       CHAR(7)     NOT NULL,                -- AAAA-MM
    jour_semaine     NVARCHAR(20) NOT NULL,
    est_hors_periode BIT         NOT NULL DEFAULT 0       -- apres 2026-08-31
);
GO

CREATE TABLE dwh.Dim_Produit (
    produit_key                INT IDENTITY(1,1) PRIMARY KEY,
    id_produit                 VARCHAR(10)   NOT NULL UNIQUE,   -- cle metier
    nom_produit                NVARCHAR(200) NOT NULL,
    categorie                  NVARCHAR(100) NULL,
    sous_categorie             NVARCHAR(100) NULL,
    marque                     NVARCHAR(100) NULL,
    id_fournisseur_principal   VARCHAR(10)   NULL,
    cout_unitaire              DECIMAL(12,2) NULL,
    prix_vente                 DECIMAL(12,2) NULL,
    seuil_reapprovisionnement  INT           NULL,
    stock_securite             INT           NULL,
    statut_produit             NVARCHAR(30)  NULL
);
GO

CREATE TABLE dwh.Dim_Fournisseur (
    fournisseur_key     INT IDENTITY(1,1) PRIMARY KEY,
    id_fournisseur      VARCHAR(10)   NOT NULL UNIQUE,           -- cle metier
    nom_fournisseur     NVARCHAR(150) NOT NULL,
    pays                NVARCHAR(100) NULL,
    delai_moyen_jours   INT           NULL,    
    taux_service_cible  DECIMAL(8,4)  NULL,
    statut              NVARCHAR(30)  NULL
);
GO

CREATE TABLE dwh.Dim_Entrepot (
    entrepot_key     INT IDENTITY(1,1) PRIMARY KEY,
    id_entrepot      VARCHAR(10)   NOT NULL UNIQUE,              -- cle metier
    ville            NVARCHAR(100) NULL,
    province         NVARCHAR(100) NULL,
    capacite_unites  INT           NULL
);
GO

CREATE TABLE dwh.Dim_Type_Mouvement (
    type_mouvement_key  INT IDENTITY(1,1) PRIMARY KEY,
    type_mouvement      NVARCHAR(50) NOT NULL UNIQUE,
    groupe_mouvement    NVARCHAR(30) NOT NULL,  
    sens                NVARCHAR(10) NOT NULL    -- Entree / Sortie
);
GO

INSERT INTO dwh.Dim_Type_Mouvement (type_mouvement, groupe_mouvement, sens) VALUES
 (N'Entrée',            N'Réception',  N'Entrée'),
 (N'Sortie',            N'Sortie',     N'Sortie'),
 (N'Transfert entrant', N'Transfert',  N'Entrée'),
 (N'Transfert sortant', N'Transfert',  N'Sortie'),
 (N'Ajustement +',      N'Ajustement', N'Entrée'),
 (N'Ajustement -',      N'Ajustement', N'Sortie');
GO

--Remplissage de Dim_Date (2023-01-01 a 2026-12-31)
SET LANGUAGE French;
GO
WITH d AS (
    SELECT CAST('2023-01-01' AS DATE) AS dt
    UNION ALL
    SELECT DATEADD(DAY, 1, dt) FROM d WHERE dt < '2026-12-31'
)
INSERT INTO dwh.Dim_Date
    (date_key, date_complete, annee, numero_mois, mois, trimestre,
     annee_mois, jour_semaine, est_hors_periode)
SELECT
    CONVERT(INT, CONVERT(CHAR(8), dt, 112)),
    dt,
    YEAR(dt),
    MONTH(dt),
    UPPER(LEFT(DATENAME(MONTH, dt), 1)) + SUBSTRING(DATENAME(MONTH, dt), 2, 20),
    'T' + CAST(DATEPART(QUARTER, dt) AS CHAR(1)),
    CONVERT(CHAR(7), dt, 120),
    UPPER(LEFT(DATENAME(WEEKDAY, dt), 1)) + SUBSTRING(DATENAME(WEEKDAY, dt), 2, 20),
    CASE WHEN dt > '2026-08-31' THEN 1 ELSE 0 END
FROM d
OPTION (MAXRECURSION 2000);
GO
SET LANGUAGE us_english;
GO

--TABLES DE FAITS

-- Grain : un mouvement de stock
CREATE TABLE dwh.Fact_Mouvement_Stock (
    id_mouvement        VARCHAR(15)   NOT NULL PRIMARY KEY,      -- dimension degeneree
    date_key            INT           NOT NULL REFERENCES dwh.Dim_Date(date_key),
    produit_key         INT           NOT NULL REFERENCES dwh.Dim_Produit(produit_key),
    entrepot_key        INT           NOT NULL REFERENCES dwh.Dim_Entrepot(entrepot_key),
    type_mouvement_key  INT           NOT NULL REFERENCES dwh.Dim_Type_Mouvement(type_mouvement_key),
    quantite_signee     INT           NOT NULL,
    quantite_abs        INT           NOT NULL,
    cout_unitaire       DECIMAL(12,2) NULL,
    valeur_mouvement    DECIMAL(16,2) NULL,                      -- quantite_abs x cout_unitaire
    reference           NVARCHAR(50)  NULL
);
GO

-- Grain : une ligne produit x entrepot a la date de mise a jour (photo du stock courant)
CREATE TABLE dwh.Fact_Stock_Courant (
    date_key                 INT NOT NULL REFERENCES dwh.Dim_Date(date_key),
    produit_key              INT NOT NULL REFERENCES dwh.Dim_Produit(produit_key),
    entrepot_key             INT NOT NULL REFERENCES dwh.Dim_Entrepot(entrepot_key),
    quantite_stock           INT NOT NULL,
    quantite_reservee        INT NOT NULL,
    quantite_disponible      INT NOT NULL,
    valeur_stock             DECIMAL(16,2) NULL,                 -- quantite_stock x cout produit
    est_rupture              BIT NOT NULL,                       -- disponible = 0
    est_sous_seuil           BIT NOT NULL,                       -- stock < seuil de reapprovisionnement
    est_sous_stock_securite  BIT NOT NULL,                       -- stock < stock de securite
    PRIMARY KEY (date_key, produit_key, entrepot_key)
);
GO

-- Grain : une livraison fournisseur (commandes livrees ou partiellement livrees)
CREATE TABLE dwh.Fact_Livraison (
    id_livraison           VARCHAR(15) NOT NULL PRIMARY KEY,     -- dimension degeneree
    id_commande_fournisseur VARCHAR(15) NOT NULL,                -- dimension degeneree
    fournisseur_key        INT NOT NULL REFERENCES dwh.Dim_Fournisseur(fournisseur_key),
    entrepot_key           INT NOT NULL REFERENCES dwh.Dim_Entrepot(entrepot_key),
    date_commande_key      INT NOT NULL REFERENCES dwh.Dim_Date(date_key),
    date_prevue_key        INT NOT NULL REFERENCES dwh.Dim_Date(date_key),
    date_reelle_key        INT NOT NULL REFERENCES dwh.Dim_Date(date_key),
    statut_commande        NVARCHAR(50) NULL,
    retard_jours           INT NOT NULL,
    delai_reel_jours       INT NOT NULL,                         -- date_reelle - date_commande
    livraison_a_temps      BIT NOT NULL,
    montant_commande       DECIMAL(16,2) NULL,                   -- somme des lignes de la commande
    est_hors_periode       BIT NOT NULL DEFAULT 0
);
GO

-- Grain : une ligne d'inventaire physique (produit x entrepot x date)
CREATE TABLE dwh.Fact_Inventaire (
    id_inventaire      VARCHAR(20) NOT NULL PRIMARY KEY,         -- dimension degeneree
    date_key           INT NOT NULL REFERENCES dwh.Dim_Date(date_key),
    produit_key        INT NOT NULL REFERENCES dwh.Dim_Produit(produit_key),
    entrepot_key       INT NOT NULL REFERENCES dwh.Dim_Entrepot(entrepot_key),
    stock_theorique    INT NOT NULL,
    stock_physique     INT NOT NULL,
    ecart_quantite     INT NOT NULL,
    ecart_quantite_abs INT NOT NULL,
    valeur_ecart       DECIMAL(16,2) NOT NULL,
    valeur_ecart_abs   DECIMAL(16,2) NOT NULL,
    a_ecart            BIT NOT NULL,
    est_hors_periode   BIT NOT NULL DEFAULT 0                    -- date apres 2026-08-31
);
GO

--Controle rapide apres creation
SELECT 'Dim_Date' AS table_nom, COUNT(*) AS nb_lignes FROM dwh.Dim_Date
UNION ALL SELECT 'Dim_Type_Mouvement', COUNT(*) FROM dwh.Dim_Type_Mouvement;
GO

