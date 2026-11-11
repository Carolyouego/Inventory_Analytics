USE [Inventory_DW]
GO

/****** Objet : StoredProcedure [etl].[usp_Charger_Dimensions] Date de script : 2026-11-10 23:30:51 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE   PROCEDURE [etl].[usp_Charger_Dimensions]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @journal_id INT;
    DECLARE @lus        INT = 0;    -- lignes lues dans la source
    DECLARE @ajoutees   INT = 0;    -- nouvelles lignes inserees
    DECLARE @n          INT;

    -- 1) Ouverture d'une ligne dans le journal
    INSERT INTO etl.Journal_Chargement (nom_package)
    VALUES (N'usp_Charger_Dimensions');
    SET @journal_id = SCOPE_IDENTITY();

    BEGIN TRY

        /* ---------------------------------------------------------------
           DIM_ENTREPOT
           --------------------------------------------------------------- */
        SELECT @n = COUNT(*) FROM Inventory_Analytics.dbo.Entrepots;
        SET @lus += @n;

        -- Mise a jour des entrepots deja presents (au cas ou une valeur aurait change)
        UPDATE d
        SET d.ville           = s.ville,
            d.province        = s.province,
            d.capacite_unites = s.capacite_unites
        FROM dwh.Dim_Entrepot AS d
        JOIN Inventory_Analytics.dbo.Entrepots AS s
             ON s.id_entrepot = d.id_entrepot;

        -- Ajout des nouveaux entrepots
        INSERT INTO dwh.Dim_Entrepot (id_entrepot, ville, province, capacite_unites)
        SELECT s.id_entrepot, s.ville, s.province, s.capacite_unites
        FROM Inventory_Analytics.dbo.Entrepots AS s
        WHERE NOT EXISTS (SELECT 1 FROM dwh.Dim_Entrepot d WHERE d.id_entrepot = s.id_entrepot);
        SET @ajoutees += @@ROWCOUNT;

        /* ---------------------------------------------------------------
           DIM_FOURNISSEUR
           --------------------------------------------------------------- */
        SELECT @n = COUNT(*) FROM Inventory_Analytics.dbo.Fournisseurs;
        SET @lus += @n;

        UPDATE d
        SET d.nom_fournisseur    = s.nom_fournisseur,
            d.pays               = s.pays,
            d.delai_moyen_jours  = s.delai_moyen_jours,
            d.taux_service_cible = s.taux_service_cible,
            d.statut             = s.statut
        FROM dwh.Dim_Fournisseur AS d
        JOIN Inventory_Analytics.dbo.Fournisseurs AS s
             ON s.id_fournisseur = d.id_fournisseur;

        INSERT INTO dwh.Dim_Fournisseur
            (id_fournisseur, nom_fournisseur, pays, delai_moyen_jours, taux_service_cible, statut)
        SELECT s.id_fournisseur, s.nom_fournisseur, s.pays,
               s.delai_moyen_jours, s.taux_service_cible, s.statut
        FROM Inventory_Analytics.dbo.Fournisseurs AS s
        WHERE NOT EXISTS (SELECT 1 FROM dwh.Dim_Fournisseur d WHERE d.id_fournisseur = s.id_fournisseur);
        SET @ajoutees += @@ROWCOUNT;

        /* ---------------------------------------------------------------
           DIM_PRODUIT
           --------------------------------------------------------------- */
        SELECT @n = COUNT(*) FROM Inventory_Analytics.dbo.Produits;
        SET @lus += @n;

        UPDATE d
        SET d.nom_produit                = s.nom_produit,
            d.categorie                  = s.categorie,
            d.sous_categorie             = s.sous_categorie,
            d.marque                     = s.marque,
            d.id_fournisseur_principal   = s.id_fournisseur_principal,
            d.cout_unitaire              = s.cout_unitaire,
            d.prix_vente                 = s.prix_vente,
            d.seuil_reapprovisionnement  = s.seuil_reapprovisionnement,
            d.stock_securite             = s.stock_securite,
            d.statut_produit             = s.statut_produit
        FROM dwh.Dim_Produit AS d
        JOIN Inventory_Analytics.dbo.Produits AS s
             ON s.id_produit = d.id_produit;

        INSERT INTO dwh.Dim_Produit
            (id_produit, nom_produit, categorie, sous_categorie, marque,
             id_fournisseur_principal, cout_unitaire, prix_vente,
             seuil_reapprovisionnement, stock_securite, statut_produit)
        SELECT s.id_produit, s.nom_produit, s.categorie, s.sous_categorie, s.marque,
               s.id_fournisseur_principal, s.cout_unitaire, s.prix_vente,
               s.seuil_reapprovisionnement, s.stock_securite, s.statut_produit
        FROM Inventory_Analytics.dbo.Produits AS s
        WHERE NOT EXISTS (SELECT 1 FROM dwh.Dim_Produit d WHERE d.id_produit = s.id_produit);
        SET @ajoutees += @@ROWCOUNT;

        -- 2) Fermeture du journal : succes
        UPDATE etl.Journal_Chargement
        SET date_fin        = SYSDATETIME(),
            lignes_lues     = @lus,
            lignes_chargees = @ajoutees,
            lignes_rejetees = 0,
            statut          = N'Succes'
        WHERE journal_id = @journal_id;

    END TRY
    BEGIN CATCH
        -- 3) En cas d'erreur : on l'enregistre dans le journal, puis on la relance
        UPDATE etl.Journal_Chargement
        SET date_fin = SYSDATETIME(),
            statut   = N'Echec',
            message  = LEFT(ERROR_MESSAGE(), 500)
        WHERE journal_id = @journal_id;
        THROW;
    END CATCH
END;

GO


