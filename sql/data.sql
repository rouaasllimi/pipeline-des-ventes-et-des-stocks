/* =====================================================================
   Données de test : clients et historique de ventes (mai-juin 2024)
   Prérequis : create_tables.sql et dim_temps_population.sql du projet 2.
   Les ventes historiques alimentent l'analyse commerciale uniquement :
   elles n'ont pas de mouvement de stock (antérieures au suivi de stock).
   ===================================================================== */

USE BaseInventaire;
GO

INSERT INTO dbo.dim_client (code_client, nom_complet, email, segment, date_acquisition, pays)
VALUES
('C001', N'Auchan Retail SAS',         'contact@auchan.fr',                  'Grand compte', '2024-01-15', 'France'),
('C002', N'Decathlon SA',              'ventes@decathlon.com',               'Grand compte', '2024-02-10', 'France'),
('C003', N'Brico Dépôt',               'achats@bricodepot.fr',               'PME',          '2024-03-05', 'France'),
('C004', N'Manomano SARL',             'pro@manomano.com',                   'E-commerce',   '2024-04-20', 'France'),
('C005', N'Migros Genève',             'logistique@migros.ch',               'Grand compte', '2024-05-12', 'Suisse'),
('C006', N'Colruyt Group',             'purchasing@colruyt.be',              'Grand compte', '2024-03-01', 'Belgique'),
('C007', N'Amazon EU SARL',            'vendor-eu@amazon.com',               'Marketplace',  '2024-03-18', 'Luxembourg'),
('C008', N'Cdiscount SA',              'partenaires@cdiscount.com',          'E-commerce',   '2024-04-22', 'France'),
('C009', N'Leroy Merlin',              'fournisseurs@leroymerlin.fr',        'PME',          '2024-04-09', 'France'),
('C010', N'Boulanger SAS',             'appro@boulanger.com',                'PME',          '2024-04-14', 'France'),
('C011', N'Fnac Darty',                'service.fournisseurs@fnacdarty.com', 'Grand compte', '2024-02-01', 'France'),
('C012', N'Zalando SE',                'vendor@zalando.ch',                  'E-commerce',   '2024-03-05', 'Suisse'),
('C013', N'MediaMarkt Saturn',         'buying@mediamarkt.de',               'Grand compte', '2024-01-20', 'Allemagne'),
('C014', N'Boulangerie Moderne Paris', 'commandes@boulangeriemoderne.fr',    'PME',          '2025-02-14', 'France'),
('C015', N'Atelier du Bricolage',      'contact@atelierbrico.fr',            'PME',          '2025-03-10', 'France');

-- produit_id = id du produit dans la table produits du projet 1
INSERT INTO dbo.fait_ventes (reference_vente, produit_id, client_id, date_complete, quantite_vendue, prix_unitaire)
VALUES
-- Widget A (1)
('HIST-001', 1, 1, '2024-05-15',  3,  9.99),
('HIST-002', 1, 2, '2024-05-16',  5,  9.99),
('HIST-003', 1, 3, '2024-05-20',  2,  9.99),
('HIST-004', 1, 1, '2024-05-25', 10,  9.99),
('HIST-005', 1, 4, '2024-06-01',  4,  9.99),
-- Gadget B (2)
('HIST-006', 2, 2, '2024-05-18',  7, 24.99),
('HIST-007', 2, 5, '2024-05-22',  3, 24.99),
('HIST-008', 2, 1, '2024-05-28', 12, 24.99),
-- Bolt M6 (3)
('HIST-009', 3, 6, '2024-05-19', 20,  0.15),
('HIST-010', 3, 7, '2024-05-21', 45,  0.15),
('HIST-011', 3, 3, '2024-05-26', 30,  0.15),
-- Sensor Pro X (4)
('HIST-012', 4, 8, '2024-05-17',  5, 45.00),
('HIST-013', 4, 9, '2024-05-24',  8, 45.00),
-- USB-C Cable 2m (6)
('HIST-014', 6, 10, '2024-05-20', 15,  6.49),
('HIST-015', 6, 11, '2024-05-27', 22,  6.49),
-- Power Supply 500W (10)
('HIST-016', 10, 12, '2024-05-23',  2, 54.99),
('HIST-017', 10, 13, '2024-05-29',  1, 54.99);
GO

-- Vérification : attendu 1 793,89 EUR et 194 unités
SELECT SUM(montant_total) AS chiffre_affaires, SUM(quantite_vendue) AS unites_vendues
FROM dbo.fait_ventes;
GO
