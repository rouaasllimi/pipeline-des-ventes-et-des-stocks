
INSERT INTO dim_client (code_client, nom_complet, email, segment, date_acquisition, pays)
VALUES
('C001', 'Auchan Retail SAS', 'contact@auchan.fr', 'Grand compte', '2024-01-15', 'France'),
('C002', 'Decathlon SA', 'ventes@decathlon.com', 'Grand compte', '2024-02-10', 'France'),
('C003', 'Brico Dépôt', 'achats@bricodepot.fr', 'Moyenne entreprise', '2024-03-05', 'France'),
('C004', 'Manomano SARL', 'pro@manomano.com', 'E-commerce', '2024-04-20', 'France'),
('C005', 'Migros Genève', 'logistique@migros.ch', 'Grand compte', '2024-05-12', 'Suisse'),
('C006', 'Colruyt Group', 'purchasing@colruyt.be', 'Grand compte', '2024-06-01', 'Belgique'),
('C007', 'Amazon EU SARL', 'vendor-eu@amazon.com', 'Marketplace', '2024-07-18', 'Luxembourg'),
('C008', 'Cdiscount SA', 'partenaires@cdiscount.com', 'E-commerce', '2024-08-22', 'France'),
('C009', 'Leroy Merlin', 'fournisseurs@leroymerlin.fr', 'Moyenne entreprise', '2024-09-09', 'France'),
('C010', 'Boulanger SAS', 'appro@boulanger.com', 'Moyenne entreprise', '2024-10-14', 'France'),
('C011', 'Fnac Darty', 'service.fournisseurs@fnacdarty.com', 'Grand compte', '2024-11-01', 'France'),
('C012', 'Zalando SE', 'vendor@zalando.ch', 'E-commerce', '2024-12-05', 'Suisse'),
('C013', 'MediaMarkt Saturn', 'buying@mediamarkt.de', 'Grand compte', '2025-01-20', 'Allemagne'),
('C014', 'Boulangerie Moderne Paris', 'commandes@boulangeriemoderne.fr', 'PME', '2025-02-14', 'France'),
('C015', 'Atelier du Bricolage', 'contact@atelierbrico.fr', 'PME', '2025-03-10', 'France');
INSERT INTO fait_ventes (produit_id, client_id, date_complete, quantite_vendue, prix_unitaire)
VALUES
-- Widget A (produit_id=1) sales
(1, 1, '2024-05-15', 3, 9.99),
(1, 2, '2024-05-16', 5, 9.99),
(1, 3, '2024-05-20', 2, 9.99),
(1, 1, '2024-05-25', 10, 9.99),
(1, 4, '2024-06-01', 4, 9.99),

-- Gadget B (produit_id=2)
(2, 2, '2024-05-18', 7, 24.99),
(2, 5, '2024-05-22', 3, 24.99),
(2, 1, '2024-05-28', 12, 24.99),

-- Bolt M6 (produit_id=3)
(3, 6, '2024-05-19', 20, 0.15),
(3, 7, '2024-05-21', 45, 0.15),
(3, 3, '2024-05-26', 30, 0.15),

-- Sensor Pro X (produit_id=4)
(4, 8, '2024-05-17', 5, 45.00),
(4, 9, '2024-05-24', 8, 45.00),

-- USB-C Cable (produit_id=6)
(6, 10, '2024-05-20', 15, 6.49),
(6, 11, '2024-05-27', 22, 6.49),

-- Power Supply 500W (produit_id=10)
(10, 12, '2024-05-23', 2, 54.99),
(10, 13, '2024-05-29', 1, 54.99);