-- Seed data: Algerian education levels and subjects
-- +goose Up

-- ═══════════════════════════════════════════════════════════════
-- Levels — Primaire
-- ═══════════════════════════════════════════════════════════════
INSERT INTO levels (name, code, cycle, "order") VALUES
('1ère Année Primaire', '1AP', 'primaire', 1),
('2ème Année Primaire', '2AP', 'primaire', 2),
('3ème Année Primaire', '3AP', 'primaire', 3),
('4ème Année Primaire', '4AP', 'primaire', 4),
('5ème Année Primaire', '5AP', 'primaire', 5);

-- ═══════════════════════════════════════════════════════════════
-- Levels — CEM (Moyen)
-- ═══════════════════════════════════════════════════════════════
INSERT INTO levels (name, code, cycle, "order") VALUES
('1ère Année Moyenne', '1AM', 'cem', 6),
('2ème Année Moyenne', '2AM', 'cem', 7),
('3ème Année Moyenne', '3AM', 'cem', 8),
('4ème Année Moyenne', '4AM', 'cem', 9);

-- ═══════════════════════════════════════════════════════════════
-- Levels — Lycée (Tronc Commun)
-- ═══════════════════════════════════════════════════════════════
INSERT INTO levels (name, code, cycle, "order") VALUES
('1AS — Sciences et Technologie', '1AS-ST', 'lycee', 10),
('1AS — Lettres', '1AS-L', 'lycee', 11);

-- ═══════════════════════════════════════════════════════════════
-- Levels — Lycée (Spécialisation 2AS)
-- ═══════════════════════════════════════════════════════════════
INSERT INTO levels (name, code, cycle, "order") VALUES
('2AS — Sciences Expérimentales', '2AS-SE', 'lycee', 12),
('2AS — Mathématiques', '2AS-M', 'lycee', 13),
('2AS — Technique Mathématique', '2AS-TM', 'lycee', 14),
('2AS — Gestion et Économie', '2AS-GE', 'lycee', 15),
('2AS — Lettres et Philosophie', '2AS-LP', 'lycee', 16),
('2AS — Langues Étrangères', '2AS-LE', 'lycee', 17);

-- ═══════════════════════════════════════════════════════════════
-- Levels — Lycée (Spécialisation 3AS / BAC)
-- ═══════════════════════════════════════════════════════════════
INSERT INTO levels (name, code, cycle, "order") VALUES
('3AS — Sciences Expérimentales', '3AS-SE', 'lycee', 18),
('3AS — Mathématiques', '3AS-M', 'lycee', 19),
('3AS — Technique Mathématique', '3AS-TM', 'lycee', 20),
('3AS — Gestion et Économie', '3AS-GE', 'lycee', 21),
('3AS — Lettres et Philosophie', '3AS-LP', 'lycee', 22),
('3AS — Langues Étrangères', '3AS-LE', 'lycee', 23);

-- ═══════════════════════════════════════════════════════════════
-- Subjects
-- ═══════════════════════════════════════════════════════════════
INSERT INTO subjects (name_fr, name_ar, name_en, category) VALUES
-- Languages
('Langue Arabe', 'اللغة العربية', 'Arabic Language', 'languages'),
('Langue Française', 'اللغة الفرنسية', 'French Language', 'languages'),
('Langue Anglaise', 'اللغة الإنجليزية', 'English Language', 'languages'),
('Tamazight', 'تمازيغت', 'Tamazight', 'languages'),
('Langue Espagnole', 'اللغة الإسبانية', 'Spanish Language', 'languages'),
('Langue Allemande', 'اللغة الألمانية', 'German Language', 'languages'),

-- Sciences
('Mathématiques', 'الرياضيات', 'Mathematics', 'sciences'),
('Physique', 'الفيزياء', 'Physics', 'sciences'),
('Chimie', 'الكيمياء', 'Chemistry', 'sciences'),
('Sciences Naturelles', 'علوم الطبيعة والحياة', 'Natural Sciences', 'sciences'),
('Éveil Scientifique', 'التربية العلمية', 'Scientific Education', 'sciences'),

-- Humanities
('Histoire', 'التاريخ', 'History', 'humanities'),
('Géographie', 'الجغرافيا', 'Geography', 'humanities'),
('Philosophie', 'الفلسفة', 'Philosophy', 'humanities'),
('Éducation Islamique', 'التربية الإسلامية', 'Islamic Education', 'humanities'),
('Éducation Civique', 'التربية المدنية', 'Civic Education', 'humanities'),

-- Technical
('Informatique', 'الإعلام الآلي', 'Informatics', 'technical'),
('Sciences de l''Ingénieur', 'هندسة', 'Engineering Sciences', 'technical'),
('Technologie', 'التكنولوجيا', 'Technology', 'technical'),

-- Business
('Gestion', 'التسيير', 'Management', 'business'),
('Économie', 'الاقتصاد', 'Economics', 'business'),
('Comptabilité', 'المحاسبة', 'Accounting', 'business'),
('Droit', 'القانون', 'Law', 'business'),

-- Other
('Éducation Physique', 'التربية البدنية', 'Physical Education', 'other'),
('Éducation Artistique', 'التربية الفنية', 'Arts Education', 'other'),
('Éducation Musicale', 'التربية الموسيقية', 'Music Education', 'other');

-- +goose Down
DELETE FROM level_subjects;
DELETE FROM subjects;
DELETE FROM levels;
