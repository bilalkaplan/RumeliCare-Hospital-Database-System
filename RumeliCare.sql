-- **********************************************************
-- PROJE: RUMELICARE KLİNİK YÖNETİM SİSTEMİ
-- HAZIRLAYAN: Bilal KOCAKAPLAN-231201007-Bilgisayar Mühendisliği
-- TARIH: 11.01.2026
-- **********************************************************

DROP DATABASE IF EXISTS RumeliCare;
CREATE DATABASE RumeliCare CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE RumeliCare;

-- ==========================================================
-- 1. TABLO TASARIMLARI 
-- ==========================================================

CREATE TABLE Bolumler (
    BolumID INT PRIMARY KEY AUTO_INCREMENT,
    BolumAdi VARCHAR(50) NOT NULL UNIQUE,
    BulunduguKat INT NOT NULL,
    CalismaSaatleri VARCHAR(50)
);

CREATE TABLE Hastalar (
    HastaID INT PRIMARY KEY AUTO_INCREMENT,
    TCNo CHAR(11) NOT NULL UNIQUE,
    Ad VARCHAR(50) NOT NULL,
    Soyad VARCHAR(50) NOT NULL,
    DogumTarihi DATE NOT NULL,
    Cinsiyet ENUM('E', 'K') NOT NULL,
    Telefon VARCHAR(15),
    Adres TEXT,
    KanGrubu VARCHAR(5),
    Alerjiler TEXT,
    KayitTarihi DATETIME DEFAULT CURRENT_TIMESTAMP,
    SonZiyaretTarihi DATETIME
);

CREATE TABLE Doktorlar (
    DoktorID INT PRIMARY KEY AUTO_INCREMENT,
    SicilNo VARCHAR(20) NOT NULL UNIQUE,
    Ad VARCHAR(50) NOT NULL,
    Soyad VARCHAR(50) NOT NULL,
    BolumID INT,
    UzmanlikAlani VARCHAR(100),
    MuayeneUcreti DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (BolumID) REFERENCES Bolumler(BolumID)
);

CREATE TABLE Randevular (
    RandevuID INT PRIMARY KEY AUTO_INCREMENT,
    HastaID INT,
    DoktorID INT,
    RandevuTarihi DATE NOT NULL,
    RandevuSaati TIME NOT NULL,
    Durum ENUM('Bekliyor', 'Tamamlandı', 'İptal') DEFAULT 'Bekliyor',
    OlusturmaTarihi DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (HastaID) REFERENCES Hastalar(HastaID),
    FOREIGN KEY (DoktorID) REFERENCES Doktorlar(DoktorID)
);

CREATE TABLE Muayeneler (
    MuayeneID INT PRIMARY KEY AUTO_INCREMENT,
    RandevuID INT UNIQUE,
    Sikayet TEXT,
    Teshis TEXT,
    TedaviNotu TEXT,
    KontrolGerekliMi BOOLEAN DEFAULT FALSE,
    MuayeneTarihi DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (RandevuID) REFERENCES Randevular(RandevuID)
);

CREATE TABLE Ilaclar (
    IlacID INT PRIMARY KEY AUTO_INCREMENT,
    IlacAdi VARCHAR(100) NOT NULL,
    EtkenMadde VARCHAR(100),
    Fiyat DECIMAL(10,2) NOT NULL
);

CREATE TABLE Receteler (
    ReceteID INT PRIMARY KEY AUTO_INCREMENT,
    MuayeneID INT,
    ReceteTarihi DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (MuayeneID) REFERENCES Muayeneler(MuayeneID)
);

CREATE TABLE ReceteDetay (
    DetayID INT PRIMARY KEY AUTO_INCREMENT,
    ReceteID INT,
    IlacID INT,
    Dozaj VARCHAR(50),
    Talimat VARCHAR(200),
    FOREIGN KEY (ReceteID) REFERENCES Receteler(ReceteID),
    FOREIGN KEY (IlacID) REFERENCES Ilaclar(IlacID)
);

CREATE TABLE Faturalar (
    FaturaID INT PRIMARY KEY AUTO_INCREMENT,
    MuayeneID INT,
    ToplamTutar DECIMAL(10,2) NOT NULL,
    OdemeDurumu ENUM('Odendi', 'Bekliyor') DEFAULT 'Bekliyor',
    OdemeYontemi ENUM('Nakit', 'Kredi Kartı', 'Havale'),
    FaturaTarihi DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (MuayeneID) REFERENCES Muayeneler(MuayeneID)
);

CREATE TABLE IslemLoglari (
    LogID INT PRIMARY KEY AUTO_INCREMENT,
    IslemTipi VARCHAR(50),
    Aciklama TEXT,
    IslemTarihi DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ==========================================================
-- 2. STORED PROCEDURES 
-- ==========================================================

DELIMITER //

CREATE PROCEDURE sp_RandevuOlustur(IN p_HastaID INT, IN p_DoktorID INT, IN p_Tarih DATE, IN p_Saat TIME)
BEGIN
    IF EXISTS (SELECT 1 FROM Randevular WHERE DoktorID = p_DoktorID AND RandevuTarihi = p_Tarih AND RandevuSaati = p_Saat AND Durum != 'İptal') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Hata: Doktorun bu saatte baska bir randevusu var!';
    ELSE
        INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati) VALUES (p_HastaID, p_DoktorID, p_Tarih, p_Saat);
    END IF;
END //

CREATE PROCEDURE sp_MuayeneTamamla(IN p_RandevuID INT, IN p_Sikayet TEXT, IN p_Teshis TEXT, IN p_TedaviNotu TEXT)
BEGIN
    UPDATE Randevular SET Durum = 'Tamamlandı' WHERE RandevuID = p_RandevuID;
    INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (p_RandevuID, p_Sikayet, p_Teshis, p_TedaviNotu);
END //

CREATE PROCEDURE sp_ReceteOlustur(IN p_MuayeneID INT, IN p_IlacID INT, IN p_Dozaj VARCHAR(50), IN p_Talimat VARCHAR(200))
BEGIN
    DECLARE v_Alerji TEXT;
    DECLARE v_Etken VARCHAR(100);
    DECLARE v_ReceteID INT;
    SELECT h.Alerjiler, i.EtkenMadde INTO v_Alerji, v_Etken 
    FROM Muayeneler m JOIN Randevular r ON m.RandevuID = r.RandevuID JOIN Hastalar h ON r.HastaID = h.HastaID
    JOIN Ilaclar i ON i.IlacID = p_IlacID WHERE m.MuayeneID = p_MuayeneID;

    IF v_Alerji LIKE CONCAT('%', v_Etken, '%') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ALERJI UYARISI: Hasta bu ilaci kullanamaz!';
    ELSE
        SELECT ReceteID INTO v_ReceteID FROM Receteler WHERE MuayeneID = p_MuayeneID LIMIT 1;
        IF v_ReceteID IS NULL THEN
            INSERT INTO Receteler (MuayeneID) VALUES (p_MuayeneID);
            SET v_ReceteID = LAST_INSERT_ID();
        END IF;
        INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (v_ReceteID, p_IlacID, p_Dozaj, p_Talimat);
    END IF;
END //

CREATE PROCEDURE sp_HastaGecmisi(IN p_HastaID INT)
BEGIN
    SELECT r.RandevuTarihi, d.Ad AS DoktorAdi, b.BolumAdi, m.Teshis, m.TedaviNotu
    FROM Randevular r LEFT JOIN Muayeneler m ON r.RandevuID = m.RandevuID
    JOIN Doktorlar d ON r.DoktorID = d.DoktorID JOIN Bolumler b ON d.BolumID = b.BolumID
    WHERE r.HastaID = p_HastaID ORDER BY r.RandevuTarihi DESC;
END //

CREATE PROCEDURE sp_GunlukRapor(IN p_Tarih DATE)
BEGIN
    SELECT COUNT(*) AS ToplamRandevu, SUM(CASE WHEN Durum = 'Tamamlandı' THEN 1 ELSE 0 END) AS TamamlananMuayene,
    SUM(CASE WHEN Durum = 'İptal' THEN 1 ELSE 0 END) AS IptalSayisi,
    (SELECT COALESCE(SUM(ToplamTutar), 0) FROM Faturalar f JOIN Muayeneler m ON f.MuayeneID = m.MuayeneID 
     JOIN Randevular r ON m.RandevuID = r.RandevuID WHERE r.RandevuTarihi = p_Tarih) AS GunlukCiro
    FROM Randevular WHERE RandevuTarihi = p_Tarih;
END //

CREATE PROCEDURE sp_DoktorRandevulari(IN p_DoktorID INT, IN p_Baslangic DATE, IN p_Bitis DATE)
BEGIN
    SELECT r.RandevuTarihi, r.RandevuSaati, h.Ad AS HastaAdi, h.Soyad AS HastaSoyadi, r.Durum
    FROM Randevular r JOIN Hastalar h ON r.HastaID = h.HastaID
    WHERE r.DoktorID = p_DoktorID AND r.RandevuTarihi BETWEEN p_Baslangic AND p_Bitis
    ORDER BY r.RandevuTarihi, r.RandevuSaati;
END //

DELIMITER ;

-- ==========================================================
-- 3. TRIGGERLAR (TETİKLEYİCİLER)
-- ==========================================================

DELIMITER //

CREATE TRIGGER trg_RandevuCakismaKontrol BEFORE INSERT ON Randevular FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM Randevular WHERE DoktorID = NEW.DoktorID AND RandevuTarihi = NEW.RandevuTarihi AND RandevuSaati = NEW.RandevuSaati AND Durum != 'İptal') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'HATA: Bu saatte doktora ait baska bir randevu mevcut!';
    END IF;
END //

CREATE TRIGGER trg_OtomatikFatura AFTER INSERT ON Muayeneler FOR EACH ROW
BEGIN
    DECLARE v_Ucret DECIMAL(10,2);
    SELECT MuayeneUcreti INTO v_Ucret FROM Doktorlar d JOIN Randevular r ON d.DoktorID = r.DoktorID WHERE r.RandevuID = NEW.RandevuID;
    INSERT INTO Faturalar (MuayeneID, ToplamTutar, OdemeDurumu) VALUES (NEW.MuayeneID, v_Ucret, 'Bekliyor');
END //

CREATE TRIGGER trg_RandevuIptalLog AFTER UPDATE ON Randevular FOR EACH ROW
BEGIN
    IF OLD.Durum != 'İptal' AND NEW.Durum = 'İptal' THEN
        INSERT INTO IslemLoglari (IslemTipi, Aciklama) VALUES ('İPTAL', CONCAT('Randevu ID ', NEW.RandevuID, ' iptal edildi.'));
    END IF;
END //

CREATE TRIGGER trg_HastaSonZiyaret AFTER INSERT ON Muayeneler FOR EACH ROW
BEGIN
    UPDATE Hastalar h JOIN Randevular r ON NEW.RandevuID = r.RandevuID SET h.SonZiyaretTarihi = NOW() WHERE h.HastaID = r.HastaID;
END //

DELIMITER ;

-- ==========================================================
-- 4. VIEWLAR VE İNDEKSLER
-- ==========================================================

CREATE VIEW vw_BugununRandevulari AS
SELECT r.RandevuSaati, h.Ad AS HastaAd, h.Soyad AS HastaSoyad, d.Ad AS DoktorAd, b.BolumAdi, r.Durum 
FROM Randevular r JOIN Hastalar h ON r.HastaID = h.HastaID JOIN Doktorlar d ON r.DoktorID = d.DoktorID
JOIN Bolumler b ON d.BolumID = b.BolumID WHERE r.RandevuTarihi = CURDATE();

CREATE VIEW vw_DoktorMusaitlik AS
SELECT d.Ad AS DoktorAdi, d.Soyad AS DoktorSoyadi, r.RandevuSaati, 'DOLU' AS Durum
FROM Randevular r JOIN Doktorlar d ON r.DoktorID = d.DoktorID WHERE r.RandevuTarihi = CURDATE() AND r.Durum != 'İptal';

CREATE VIEW vw_HastaMuayeneOzeti AS
SELECT h.Ad, h.Soyad, COUNT(m.MuayeneID) AS ToplamMuayene, MAX(m.MuayeneTarihi) AS SonMuayeneTarihi
FROM Hastalar h LEFT JOIN Randevular r ON h.HastaID = r.HastaID LEFT JOIN Muayeneler m ON r.RandevuID = m.RandevuID GROUP BY h.HastaID;

CREATE VIEW vw_AylikGelir AS
SELECT b.BolumAdi, SUM(f.ToplamTutar) AS ToplamGelir FROM Faturalar f JOIN Muayeneler m ON f.MuayeneID = m.MuayeneID 
JOIN Randevular r ON m.RandevuID = r.RandevuID JOIN Doktorlar d ON r.DoktorID = d.DoktorID JOIN Bolumler b ON d.BolumID = b.BolumID GROUP BY b.BolumAdi;

CREATE VIEW vw_OdenmemisFaturalar AS
SELECT h.Ad AS HastaAdi, h.Soyad AS HastaSoyadi, f.ToplamTutar, f.FaturaTarihi
FROM Faturalar f JOIN Muayeneler m ON f.MuayeneID = m.MuayeneID JOIN Randevular r ON m.RandevuID = r.RandevuID
JOIN Hastalar h ON r.HastaID = h.HastaID WHERE f.OdemeDurumu = 'Bekliyor';

CREATE INDEX idx_HastaTC ON Hastalar(TCNo);
CREATE INDEX idx_RandevuTarih ON Randevular(RandevuTarihi);

-- ==========================================================
-- 5. TEST VERİLERİ
-- ==========================================================

-- 1. BÖLÜMLER
INSERT INTO Bolumler (BolumAdi, BulunduguKat, CalismaSaatleri) VALUES 
('Dahiliye', 1, '09:00-17:00');
INSERT INTO Bolumler (BolumAdi, BulunduguKat, CalismaSaatleri) VALUES 
('Kardiyoloji', 2, '09:00-17:00');
INSERT INTO Bolumler (BolumAdi, BulunduguKat, CalismaSaatleri) VALUES 
('Ortopedi', 1, '09:00-16:00');
INSERT INTO Bolumler (BolumAdi, BulunduguKat, CalismaSaatleri) VALUES 
('Dermatoloji', 3, '10:00-18:00');
INSERT INTO Bolumler (BolumAdi, BulunduguKat, CalismaSaatleri) VALUES 
('Göz', 2, '09:00-17:00');
INSERT INTO Bolumler (BolumAdi, BulunduguKat, CalismaSaatleri) VALUES 
('KBB', 3, '09:00-17:00');

-- 2. DOKTORLAR
INSERT INTO Doktorlar (SicilNo, Ad, Soyad, BolumID, MuayeneUcreti) VALUES ('DR001', 'Mehmet', 'Demir', 2, 500.00);
INSERT INTO Doktorlar (SicilNo, Ad, Soyad, BolumID, MuayeneUcreti) VALUES ('DR002', 'Zeynep', 'Kara', 1, 400.00);
INSERT INTO Doktorlar (SicilNo, Ad, Soyad, BolumID, MuayeneUcreti) VALUES ('DR003', 'Ali', 'Veli', 3, 600.00);
INSERT INTO Doktorlar (SicilNo, Ad, Soyad, BolumID, MuayeneUcreti) VALUES ('DR004', 'Ayşe', 'Can', 4, 450.00);
INSERT INTO Doktorlar (SicilNo, Ad, Soyad, BolumID, MuayeneUcreti) VALUES ('DR005', 'Fatma', 'Şen', 5, 500.00);
INSERT INTO Doktorlar (SicilNo, Ad, Soyad, BolumID, MuayeneUcreti) VALUES ('DR006', 'Mustafa', 'Koç', 6, 550.00);
INSERT INTO Doktorlar (SicilNo, Ad, Soyad, BolumID, MuayeneUcreti) VALUES ('DR007', 'Burak', 'Yılmaz', 1, 400.00);
INSERT INTO Doktorlar (SicilNo, Ad, Soyad, BolumID, MuayeneUcreti) VALUES ('DR008', 'Selin', 'Demir', 2, 500.00);
INSERT INTO Doktorlar (SicilNo, Ad, Soyad, BolumID, MuayeneUcreti) VALUES ('DR009', 'Cem', 'Uzan', 3, 600.00);
INSERT INTO Doktorlar (SicilNo, Ad, Soyad, BolumID, MuayeneUcreti) VALUES ('DR010', 'Deniz', 'Gezmiş', 4, 450.00);

-- 3. HASTALAR
INSERT INTO Hastalar (TCNo, Ad, Soyad, DogumTarihi, Cinsiyet, Alerjiler) VALUES ('10000000001', 'Ahmet', 'Yılmaz', '1980-01-01', 'E', 'Yok');
INSERT INTO Hastalar (TCNo, Ad, Soyad, DogumTarihi, Cinsiyet, Alerjiler) VALUES ('10000000002', 'Mehmet', 'Kaya', '1985-02-02', 'E', 'Penisilin');
INSERT INTO Hastalar (TCNo, Ad, Soyad, DogumTarihi, Cinsiyet, Alerjiler) VALUES ('10000000003', 'Ayşe', 'Demir', '1990-03-03', 'K', 'Yok');
INSERT INTO Hastalar (TCNo, Ad, Soyad, DogumTarihi, Cinsiyet, Alerjiler) VALUES ('10000000004', 'Fatma', 'Çelik', '1995-04-04', 'K', 'Toz');
INSERT INTO Hastalar (TCNo, Ad, Soyad, DogumTarihi, Cinsiyet, Alerjiler) VALUES ('10000000005', 'Ali', 'Can', '2000-05-05', 'E', 'Yok');
INSERT INTO Hastalar (TCNo, Ad, Soyad, DogumTarihi, Cinsiyet, Alerjiler) VALUES ('10000000006', 'Veli', 'Sönmez', '1982-06-06', 'E', 'Aspirin');
INSERT INTO Hastalar (TCNo, Ad, Soyad, DogumTarihi, Cinsiyet, Alerjiler) VALUES ('10000000007', 'Zeynep', 'Kurt', '1988-07-07', 'K', 'Yok');
INSERT INTO Hastalar (TCNo, Ad, Soyad, DogumTarihi, Cinsiyet, Alerjiler) VALUES ('10000000008', 'Elif', 'Koç', '1992-08-08', 'K', 'Polen');
INSERT INTO Hastalar (TCNo, Ad, Soyad, DogumTarihi, Cinsiyet, Alerjiler) VALUES ('10000000009', 'Hakan', 'Şahin', '1975-09-09', 'E', 'Yok');
INSERT INTO Hastalar (TCNo, Ad, Soyad, DogumTarihi, Cinsiyet, Alerjiler) VALUES ('10000000010', 'Deniz', 'Arslan', '1999-10-10', 'K', 'Yok');
INSERT INTO Hastalar (TCNo, Ad, Soyad, DogumTarihi, Cinsiyet, Alerjiler) VALUES ('10000000011', 'Cemal', 'Gür', '1983-11-11', 'E', 'Yok');
INSERT INTO Hastalar (TCNo, Ad, Soyad, DogumTarihi, Cinsiyet, Alerjiler) VALUES ('10000000012', 'Selin', 'Tepe', '1994-12-12', 'K', 'Yok');
INSERT INTO Hastalar (TCNo, Ad, Soyad, DogumTarihi, Cinsiyet, Alerjiler) VALUES ('10000000013', 'Murat', 'Dağ', '1986-01-13', 'E', 'Yok');
INSERT INTO Hastalar (TCNo, Ad, Soyad, DogumTarihi, Cinsiyet, Alerjiler) VALUES ('10000000014', 'Buse', 'Nehir', '1991-02-14', 'K', 'Lateks');
INSERT INTO Hastalar (TCNo, Ad, Soyad, DogumTarihi, Cinsiyet, Alerjiler) VALUES ('10000000015', 'Can', 'Irmak', '1989-03-15', 'E', 'Yok');
INSERT INTO Hastalar (TCNo, Ad, Soyad, DogumTarihi, Cinsiyet, Alerjiler) VALUES ('10000000016', 'Derya', 'Su', '1996-04-16', 'K', 'Yok');
INSERT INTO Hastalar (TCNo, Ad, Soyad, DogumTarihi, Cinsiyet, Alerjiler) VALUES ('10000000017', 'Emre', 'Toprak', '1981-05-17', 'E', 'Yok');
INSERT INTO Hastalar (TCNo, Ad, Soyad, DogumTarihi, Cinsiyet, Alerjiler) VALUES ('10000000018', 'Gamze', 'Ateş', '1993-06-18', 'K', 'Yok');
INSERT INTO Hastalar (TCNo, Ad, Soyad, DogumTarihi, Cinsiyet, Alerjiler) VALUES ('10000000019', 'Oğuz', 'Hava', '1987-07-19', 'E', 'Yok');
INSERT INTO Hastalar (TCNo, Ad, Soyad, DogumTarihi, Cinsiyet, Alerjiler) VALUES ('10000000020', 'Pınar', 'Yel', '1998-08-20', 'K', 'Yok');

-- 4. İLAÇLAR 
INSERT INTO Ilaclar (IlacAdi, EtkenMadde, Fiyat) VALUES ('Parol', 'Parasetamol', 15.00);
INSERT INTO Ilaclar (IlacAdi, EtkenMadde, Fiyat) VALUES ('Aspirin', 'Asetilsalisilik Asit', 20.00);
INSERT INTO Ilaclar (IlacAdi, EtkenMadde, Fiyat) VALUES ('Majezik', 'Flurbiprofen', 45.00);
INSERT INTO Ilaclar (IlacAdi, EtkenMadde, Fiyat) VALUES ('Arveles', 'Deksketoprofen', 50.00);
INSERT INTO Ilaclar (IlacAdi, EtkenMadde, Fiyat) VALUES ('Apranax', 'Naproksen', 60.00);
INSERT INTO Ilaclar (IlacAdi, EtkenMadde, Fiyat) VALUES ('Dolorex', 'Diklofenak', 55.00);
INSERT INTO Ilaclar (IlacAdi, EtkenMadde, Fiyat) VALUES ('Augmentin', 'Amoksisilin', 85.00);
INSERT INTO Ilaclar (IlacAdi, EtkenMadde, Fiyat) VALUES ('Klamoks', 'Amoksisilin', 80.00);
INSERT INTO Ilaclar (IlacAdi, EtkenMadde, Fiyat) VALUES ('Largopen', 'Amoksisilin', 75.00);
INSERT INTO Ilaclar (IlacAdi, EtkenMadde, Fiyat) VALUES ('Cipro', 'Siprofloksasin', 90.00);
INSERT INTO Ilaclar (IlacAdi, EtkenMadde, Fiyat) VALUES ('Zitrotek', 'Azitromisin', 120.00);
INSERT INTO Ilaclar (IlacAdi, EtkenMadde, Fiyat) VALUES ('Monodoks', 'Doksisiklin', 65.00);
INSERT INTO Ilaclar (IlacAdi, EtkenMadde, Fiyat) VALUES ('Tylolhot', 'Parasetamol', 100.00);
INSERT INTO Ilaclar (IlacAdi, EtkenMadde, Fiyat) VALUES ('Nurofen', 'İbuprofen', 70.00);
INSERT INTO Ilaclar (IlacAdi, EtkenMadde, Fiyat) VALUES ('Gaviscon', 'Sodyum Aljinat', 110.00);
INSERT INTO Ilaclar (IlacAdi, EtkenMadde, Fiyat) VALUES ('Rennie', 'Kalsiyum Karbonat', 50.00);
INSERT INTO Ilaclar (IlacAdi, EtkenMadde, Fiyat) VALUES ('Talcid', 'Hidrotalsit', 45.00);
INSERT INTO Ilaclar (IlacAdi, EtkenMadde, Fiyat) VALUES ('Nexium', 'Esomeprazol', 150.00);
INSERT INTO Ilaclar (IlacAdi, EtkenMadde, Fiyat) VALUES ('Lansor', 'Lansoprazol', 140.00);
INSERT INTO Ilaclar (IlacAdi, EtkenMadde, Fiyat) VALUES ('Pulcet', 'Pantoprazol', 130.00);
INSERT INTO Ilaclar (IlacAdi, EtkenMadde, Fiyat) VALUES ('Crebros', 'Levosetirizin', 60.00);
INSERT INTO Ilaclar (IlacAdi, EtkenMadde, Fiyat) VALUES ('Aerius', 'Desloratadin', 70.00);
INSERT INTO Ilaclar (IlacAdi, EtkenMadde, Fiyat) VALUES ('Zyrtec', 'Setirizin', 55.00);
INSERT INTO Ilaclar (IlacAdi, EtkenMadde, Fiyat) VALUES ('Xyzal', 'Levosetirizin', 65.00);
INSERT INTO Ilaclar (IlacAdi, EtkenMadde, Fiyat) VALUES ('Ventolin', 'Salbutamol', 80.00);
INSERT INTO Ilaclar (IlacAdi, EtkenMadde, Fiyat) VALUES ('Symbicort', 'Budesonid', 250.00);
INSERT INTO Ilaclar (IlacAdi, EtkenMadde, Fiyat) VALUES ('Seretide', 'Flutikazon', 300.00);
INSERT INTO Ilaclar (IlacAdi, EtkenMadde, Fiyat) VALUES ('Singulair', 'Montelukast', 180.00);
INSERT INTO Ilaclar (IlacAdi, EtkenMadde, Fiyat) VALUES ('Airfix', 'Montelukast', 170.00);
INSERT INTO Ilaclar (IlacAdi, EtkenMadde, Fiyat) VALUES ('Notuss', 'Butamirat', 40.00);

-- 5. RANDEVULAR
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (1, 1, '2026-01-12', '09:00', 'Tamamlandı');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (2, 2, '2026-01-12', '09:30', 'Tamamlandı');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (3, 3, '2026-01-12', '10:00', 'Tamamlandı');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (4, 4, '2026-01-12', '10:30', 'Tamamlandı');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (5, 5, '2026-01-12', '11:00', 'Tamamlandı');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (6, 6, '2026-01-12', '11:30', 'Tamamlandı');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (7, 7, '2026-01-12', '13:00', 'Tamamlandı');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (8, 8, '2026-01-12', '13:30', 'Tamamlandı');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (9, 9, '2026-01-12', '14:00', 'Tamamlandı');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (10, 10, '2026-01-12', '14:30', 'Tamamlandı');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (11, 1, '2026-01-13', '09:00', 'Tamamlandı');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (12, 2, '2026-01-13', '09:30', 'Tamamlandı');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (13, 3, '2026-01-13', '10:00', 'Tamamlandı');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (14, 4, '2026-01-13', '10:30', 'Tamamlandı');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (15, 5, '2026-01-13', '11:00', 'Tamamlandı');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (16, 6, '2026-01-13', '11:30', 'Tamamlandı');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (17, 7, '2026-01-13', '13:00', 'Tamamlandı');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (18, 8, '2026-01-13', '13:30', 'Tamamlandı');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (19, 9, '2026-01-13', '14:00', 'Tamamlandı');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (20, 10, '2026-01-13', '14:30', 'Tamamlandı');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (1, 2, '2026-01-14', '09:00', 'Tamamlandı');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (2, 3, '2026-01-14', '09:30', 'Tamamlandı');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (3, 4, '2026-01-14', '10:00', 'Tamamlandı');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (4, 5, '2026-01-14', '10:30', 'Tamamlandı');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (5, 6, '2026-01-14', '11:00', 'Tamamlandı');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (6, 7, '2026-01-14', '11:30', 'Tamamlandı');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (7, 8, '2026-01-14', '13:00', 'Tamamlandı');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (8, 9, '2026-01-14', '13:30', 'Tamamlandı');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (9, 10, '2026-01-14', '14:00', 'Tamamlandı');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (10, 1, '2026-01-14', '14:30', 'Tamamlandı');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (11, 2, '2026-01-15', '09:00', 'Tamamlandı');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (12, 3, '2026-01-15', '09:30', 'Tamamlandı');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (13, 4, '2026-01-15', '10:00', 'Tamamlandı');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (14, 5, '2026-01-15', '10:30', 'Tamamlandı');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (15, 6, '2026-01-15', '11:00', 'Tamamlandı');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (16, 7, '2026-01-15', '11:30', 'Tamamlandı');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (17, 8, '2026-01-15', '13:00', 'Tamamlandı');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (18, 9, '2026-01-15', '13:30', 'Tamamlandı');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (19, 10, '2026-01-15', '14:00', 'Tamamlandı');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (20, 1, '2026-01-15', '14:30', 'Tamamlandı');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (1, 3, '2026-01-16', '09:00', 'Bekliyor');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (2, 4, '2026-01-16', '09:30', 'Bekliyor');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (3, 5, '2026-01-16', '10:00', 'Bekliyor');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (4, 6, '2026-01-16', '10:30', 'Bekliyor');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (5, 7, '2026-01-16', '11:00', 'Bekliyor');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (6, 8, '2026-01-16', '11:30', 'Bekliyor');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (7, 9, '2026-01-16', '13:00', 'Bekliyor');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (8, 10, '2026-01-16', '13:30', 'Bekliyor');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (9, 1, '2026-01-16', '14:00', 'Bekliyor');
INSERT INTO Randevular (HastaID, DoktorID, RandevuTarihi, RandevuSaati, Durum) VALUES (10, 2, '2026-01-16', '14:30', 'Bekliyor');

-- 6. MUAYENELER 
INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (1, 'Baş ağrısı', 'Migren', 'İlaç tedavisi');
INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (2, 'Karın ağrısı', 'Gastrit', 'Diyet');
INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (3, 'Öksürük', 'Bronşit', 'Antibiyotik');
INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (4, 'Döküntü', 'Egzama', 'Krem');
INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (5, 'Görme kaybı', 'Miyop', 'Gözlük');
INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (6, 'Duyma kaybı', 'Enfeksiyon', 'İlaç');
INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (7, 'Halsizlik', 'Anemi', 'Vitamin');
INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (8, 'Çarpıntı', 'Taşikardi', 'Takip');
INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (9, 'Burun akıntısı', 'Grip', 'İstirahat');
INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (10, 'Kaşıntı', 'Alerji', 'Merhem');
INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (11, 'Mide yanması', 'Reflü', 'Diyet');
INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (12, 'Sırt ağrısı', 'Kas spazmı', 'Krem');
INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (13, 'Boğaz ağrısı', 'Farenjit', 'İlaç');
INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (14, 'Nefes darlığı', 'Astım', 'İnhaler');
INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (15, 'Baş dönmesi', 'Vertigo', 'İlaç');
INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (16, 'Kulak çınlaması', 'Tinnitus', 'Takip');
INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (17, 'Eklem ağrısı', 'Romatizma', 'İlaç');
INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (18, 'Göz sulanması', 'Konjonktivit', 'Damla');
INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (19, 'Sivilce', 'Akne', 'Krem');
INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (20, 'Ayak ağrısı', 'Düz taban', 'Tabanlık');
INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (21, 'Genel kontrol', 'Sağlıklı', 'Yok');
INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (22, 'Vitamin eksikliği', 'B12 eksikliği', 'İğne');
INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (23, 'Kilo sorunu', 'Obezite', 'Diyet');
INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (24, 'Tansiyon', 'Hipertansiyon', 'İlaç');
INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (25, 'Şeker', 'Diyabet', 'İnsülin');
INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (26, 'Kolesterol', 'Hiperlipidemi', 'Diyet');
INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (27, 'Tırnak batması', 'Enfeksiyon', 'Krem');
INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (28, 'Saç dökülmesi', 'Genetik', 'Şampuan');
INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (29, 'Göz kuruluğu', 'Kuruluk', 'Damla');
INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (30, 'Burun tıkanıklığı', 'Deviasyon', 'Ameliyat önerisi');
INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (31, 'Öksürük', 'Soğuk algınlığı', 'İlaç');
INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (32, 'Ateş', 'Enfeksiyon', 'İlaç');
INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (33, 'Bulantı', 'Zehirlenme', 'Serum');
INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (34, 'İshal', 'Gastroenterit', 'Diyet');
INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (35, 'Kabızlık', 'Beslenme', 'Diyet');
INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (36, 'Uykusuzluk', 'Stres', 'Öneri');
INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (37, 'Sinirlilik', 'Anksiyete', 'Psikiyatri yönlendirme');
INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (38, 'Unutkanlık', 'B12', 'Takviye');
INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (39, 'Titreme', 'Parkinson şüphesi', 'Nöroloji');
INSERT INTO Muayeneler (RandevuID, Sikayet, Teshis, TedaviNotu) VALUES (40, 'Uyuşma', 'Sinir sıkışması', 'Fizik tedavi');

-- 7. REÇETELER VE DETAYLARI 
INSERT INTO Receteler (MuayeneID) VALUES (1);
INSERT INTO Receteler (MuayeneID) VALUES (2);
INSERT INTO Receteler (MuayeneID) VALUES (3);
INSERT INTO Receteler (MuayeneID) VALUES (4);
INSERT INTO Receteler (MuayeneID) VALUES (5);
INSERT INTO Receteler (MuayeneID) VALUES (6);
INSERT INTO Receteler (MuayeneID) VALUES (7);
INSERT INTO Receteler (MuayeneID) VALUES (8);
INSERT INTO Receteler (MuayeneID) VALUES (9);
INSERT INTO Receteler (MuayeneID) VALUES (10);
INSERT INTO Receteler (MuayeneID) VALUES (11);
INSERT INTO Receteler (MuayeneID) VALUES (12);
INSERT INTO Receteler (MuayeneID) VALUES (13);
INSERT INTO Receteler (MuayeneID) VALUES (14);
INSERT INTO Receteler (MuayeneID) VALUES (15);
INSERT INTO Receteler (MuayeneID) VALUES (16);
INSERT INTO Receteler (MuayeneID) VALUES (17);
INSERT INTO Receteler (MuayeneID) VALUES (18);
INSERT INTO Receteler (MuayeneID) VALUES (19);
INSERT INTO Receteler (MuayeneID) VALUES (20);
INSERT INTO Receteler (MuayeneID) VALUES (21);
INSERT INTO Receteler (MuayeneID) VALUES (22);
INSERT INTO Receteler (MuayeneID) VALUES (23);
INSERT INTO Receteler (MuayeneID) VALUES (24);
INSERT INTO Receteler (MuayeneID) VALUES (25);
INSERT INTO Receteler (MuayeneID) VALUES (26);
INSERT INTO Receteler (MuayeneID) VALUES (27);
INSERT INTO Receteler (MuayeneID) VALUES (28);
INSERT INTO Receteler (MuayeneID) VALUES (29);
INSERT INTO Receteler (MuayeneID) VALUES (30);

-- Reçete Detayları (Her reçeteye 2 ilaç ekledim)
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (1, 1, '2x1', 'Tok');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (1, 2, '1x1', 'Aç');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (2, 3, '1x1', 'Tok');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (2, 4, '2x1', 'Tok');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (3, 7, '2x1', '12 saatte bir');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (3, 1, '1x1', 'Ateş olursa');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (4, 10, '2x1', 'Sür');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (4, 11, '1x1', 'Gece');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (5, 5, '1x1', 'Gerektiğinde');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (5, 6, '1x1', 'Tok');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (6, 7, '2x1', 'Tok');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (6, 8, '1x1', 'Sabah');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (7, 13, '3x1', 'Sıcak suyla');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (7, 14, '1x1', 'Ağrı olursa');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (8, 2, '1x1', 'Tok');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (8, 1, '1x1', 'Tok');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (9, 13, '2x1', 'Sabah akşam');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (9, 30, '3x1', 'Tok');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (10, 21, '1x1', 'Gece');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (10, 22, '1x1', 'Sabah');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (11, 15, '4x1', 'Yemek sonrası');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (11, 16, '2x1', 'Çiğneme');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (12, 14, '1x1', 'Tok');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (12, 3, '1x1', 'Tok');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (13, 7, '2x1', 'Tok');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (13, 1, '1x1', 'Tok');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (14, 25, 'Gerektiğinde', 'İnhaler');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (14, 26, '2x1', 'Sabah akşam');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (15, 1, '1x1', 'Tok');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (15, 5, '1x1', 'Baş dönmesi için');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (16, 2, '1x1', 'Tok');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (16, 4, '1x1', 'Tok');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (17, 3, '1x1', 'Tok');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (17, 5, '1x1', 'Tok');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (18, 10, '3x1', 'Damla');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (18, 11, '1x1', 'Gece');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (19, 20, '1x1', 'Sür');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (19, 21, '1x1', 'Tok');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (20, 1, '1x1', 'Ağrı için');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (20, 2, '1x1', 'Tok');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (21, 1, '1x1', 'Tok');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (21, 12, '1x1', 'Tok');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (22, 1, '1x1', 'Haftada bir');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (22, 13, '1x1', 'Tok');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (23, 15, '1x1', 'Tok');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (23, 16, '1x1', 'Tok');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (24, 2, '1x1', 'Sabah');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (24, 1, '1x1', 'Akşam');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (25, 1, '1x1', 'Tok');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (25, 5, '1x1', 'Tok');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (26, 2, '1x1', 'Gece');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (26, 3, '1x1', 'Tok');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (27, 8, '2x1', 'Sür');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (27, 9, '1x1', 'Tok');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (28, 1, '1x1', 'Tok');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (28, 5, '1x1', 'Tok');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (29, 10, '3x1', 'Damla');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (29, 11, '1x1', 'Gece');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (30, 1, '1x1', 'Tok');
INSERT INTO ReceteDetay (ReceteID, IlacID, Dozaj, Talimat) VALUES (30, 2, '1x1', 'Tok');