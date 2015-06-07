-- Creazione database
CREATE DATABASE `bibfvg`
    CHARACTER SET utf8 -- Usiamo UTF-8 come codifica
    COLLATE utf8_general_ci;

-- Definizione database predefinito
USE `bibfvg`;

-- Usiamo InnoDB (che supporta le FK) come default engine
-- per la creazione di tabelle nella sessione corrente
SET default_storage_engine=InnoDB;

-- Creazione tabella ‘provincia‘
CREATE TABLE `provincia` (
    -- La sigla e‘ sempre lunga 2
    `sigla` CHAR(2) NOT NULL,
    `nome` VARCHAR(40) NOT NULL,

    PRIMARY KEY (`sigla`)
);

-- Creazione tabella ‘comune‘
CREATE TABLE `comune` (
    -- Il cod. cat. e‘ sempre lungo 4
    `codice_catastale` CHAR(4) NOT NULL,
    `nome` VARCHAR(40) NOT NULL,
    `sigla_prov` CHAR(2) NOT NULL,

    PRIMARY KEY (`codice_catastale`),
    -- Indice necessario per FK

    FOREIGN KEY (`sigla_prov`)
        REFERENCES `provincia`(`sigla`)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

-- Creazione tabella ‘indirizzo‘
CREATE TABLE `indirizzo` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `codice_catastale_com` CHAR(4) NOT NULL,
    -- N. civico e interno possono
    -- contenere lettere
    `nome_via` VARCHAR(40) NOT NULL,
    `ncivico` VARCHAR(5) NOT NULL,
    `interno` VARCHAR(5) DEFAULT NULL,

    PRIMARY KEY (`id`),
    -- Indice necessario per FK

    FOREIGN KEY (`codice_catastale_com`)
        REFERENCES `comune`(`codice_catastale`)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

-- Creazione tabella ‘membro‘
CREATE TABLE `membro` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `id_indirizzo` INT NOT NULL,
    `nome` VARCHAR(40) NOT NULL,
    `cognome` VARCHAR(40) NOT NULL,
    `data_di_nascita` DATE NOT NULL,
    -- Lo stato puo‘ assumere solo 2 valori
    `stato_iscrizione` ENUM('attiva', 'sospesa'),
    `ammonizioni` INT NOT NULL,

    PRIMARY KEY (`id`),
    -- Indice necessario per FK

    FOREIGN KEY (`id_indirizzo`)
        REFERENCES `indirizzo`(`id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

-- Creazione tabella ‘gruppo‘
CREATE TABLE `gruppo` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `nome` VARCHAR(40) NOT NULL,

    PRIMARY KEY (`id`)
);

-- Creazione tabella ‘biblioteca‘
CREATE TABLE `biblioteca` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `id_indirizzo` INT NOT NULL,
    `nome` VARCHAR(40) NOT NULL,

    PRIMARY KEY (`id`),
    -- Indice necessario per FK

    FOREIGN KEY (`id_indirizzo`)
        REFERENCES `indirizzo`(`id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

-- Creazione tabella ‘biblioteca_gruppo‘
CREATE TABLE `biblioteca_gruppo` (
    `id_biblioteca` INT NOT NULL,
    `id_gruppo` INT NOT NULL,

    PRIMARY KEY (`id_biblioteca`, `id_gruppo`),
    -- Indici necessari per FKs
    
    FOREIGN KEY (`id_biblioteca`)
        REFERENCES `biblioteca`(`id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    FOREIGN KEY (`id_gruppo`)
        REFERENCES `gruppo`(`id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

-- Creazione tabella ‘libro‘
CREATE TABLE `libro` (
    -- Usiamo l’ISBN13 che e‘ sempre lungo 13
    `isbn` CHAR(13) NOT NULL,
    `nome` VARCHAR(80) NOT NULL,
    `anno` YEAR(4) NOT NULL,

    PRIMARY KEY (`isbn`),
    FULLTEXT (`nome`),
    INDEX (`anno`)
);

-- Creazione tabella ‘autore‘
CREATE TABLE `autore` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `nome` VARCHAR(40) NOT NULL,
    `cognome` VARCHAR(40) NOT NULL,

    PRIMARY KEY (`id`)
);

-- Creazione tabella ‘categoria‘
CREATE TABLE `categoria` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `nome` VARCHAR(40),

    PRIMARY KEY (`id`)
);

-- Creazione tabella ‘libro_autore‘
CREATE TABLE `libro_autore` (
    `isbn_libro` CHAR(13) NOT NULL,
    `id_autore` INT NOT NULL,

    PRIMARY KEY (`isbn_libro`, `id_autore`),
    -- Indici necessari per FKs
    
    FOREIGN KEY (`isbn_libro`)
        REFERENCES `libro`(`isbn`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    FOREIGN KEY (`id_autore`)
        REFERENCES `gruppo`(`id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

-- Creazione tabella ‘libro_categoria‘
CREATE TABLE `libro_categoria` (
    `isbn_libro` CHAR(13) NOT NULL,
    `id_categoria` INT NOT NULL,

    PRIMARY KEY (`isbn_libro`, `id_categoria`),
    -- Indici necessari per FKs
    
    FOREIGN KEY (`isbn_libro`)
        REFERENCES `libro`(`isbn`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    FOREIGN KEY (`id_categoria`)
        REFERENCES `gruppo`(`id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

-- Creazione tabella ‘copia_libro‘
CREATE TABLE `copia_libro` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `isbn_libro` CHAR(13) NOT NULL,
    `id_biblioteca` INT NOT NULL,

    PRIMARY KEY (`id`, `isbn_libro`, `id_biblioteca`),
    -- Indici necessari per FKs

    FOREIGN KEY (`isbn_libro`)
        REFERENCES `libro`(`isbn`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    FOREIGN KEY (`id_biblioteca`)
        REFERENCES `biblioteca`(`id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

-- Creazione tabella ‘prestito‘
CREATE TABLE `prestito` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `id_copia` INT NOT NULL,
    `id_membro` INT NOT NULL,
    `data_inizio` DATE NOT NULL,
    `data_fine` DATE DEFAULT NULL,
    `data_restituzione` DATE DEFAULT NULL,

    PRIMARY KEY (`id`),
    -- Indici necessari per FKs

    FOREIGN KEY (`id_copia`)
        REFERENCES `copia_libro`(`id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    FOREIGN KEY (`id_membro`)
        REFERENCES `membro`(`id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);


DELIMITER //
-- Trigger per la verifica della possibilità di richiedere un prestito
CREATE TRIGGER check_prestito BEFORE INSERT ON `prestito`
    FOR EACH ROW
    BEGIN
        DECLARE NUMPRESTITI INT;
        DECLARE STATOISCRIZIONE VARCHAR(7);

        SET STATOISCRIZIONE = (SELECT `stato_iscrizione`
                               FROM `membro`
                               WHERE `id` = NEW.id_membro);

        IF STATOISCRIZIONE = 'Sospesa' THEN
            -- Se l'iscrizione è sospesa
            IF (SELECT TIMESTAMPDIFF(DAY, `data_restituzione`, CURDATE())
                FROM `prestito`
                WHERE `id` = NEW.id_membro
                ORDER BY `data_restituzione` DESC
                LIMIT 1) > 30 THEN
                -- Se sono passati >30gg dall'ultima restituzione,
                -- riattivo l'iscrizione
                UPDATE `membro`
                SET `stato_iscrizione` = 'Attiva';
            ELSE
                -- Altrimenti impedisco l'operazione
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "L'iscrizione e` sospesa";
            END IF;
        END IF;
        
        SET NUMPRESTITI = (SELECT COUNT(*)
                           FROM `prestito`
                           WHERE `id_membro` = NEW.id_membro
                           AND `data_fine` IS NULL);
        IF NUMPRESTITI > 4 THEN
            -- Se il membro ha già preso in prestito 5 libri, impedisco l'operazione
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Si possono prendere in prestito'
                                                       ' al massimo 5 libri alla volta';
        END IF;
    END //
DELIMITER ;

DELIMITER //
-- Trigger per la segnalazione di ritardi/ammonizioni
CREATE TRIGGER check_ritardo_restituzione BEFORE UPDATE ON `prestito`
    FOR EACH ROW
    BEGIN
        -- Se la restituzione è in ritardo
        IF NEW.data_restituzione > OLD.data_fine THEN
            IF (SELECT `ammonizioni`
                FROM `membro`
                WHERE `id_membro` = NEW.id_membro) > 2 THEN
                -- Se il membro ha già almeno 3 ammonizioni
                -- sospendo l'iscrizione, azzerandole
                UPDATE `membro`
                SET `ammonizioni` = 0, `stato_iscrizione` = 'Sospesa'
                WHERE id = NEW.id_membro;
            ELSE
                -- Altrimenti incremento il numero di ammonizioni
                UPDATE `membro`
                SET `ammonizioni` = `ammonizioni` + 1
                WHERE id = NEW.id_membro;
            END IF;
        END IF;
    END //
DELIMITER ;

DELIMITER //
-- Trigger per permettere solo ai maggiorenni di iscriversi
CREATE TRIGGER check_maggiorenne BEFORE INSERT ON `membro`
    FOR EACH ROW
    BEGIN
        IF TIMESTAMPDIFF(YEAR, NEW.data_di_nascita, CURDATE()) < 18 THEN
            -- Se il membro non è maggiorenne, impedisco l'iscrizione
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'I membri devono essere maggiorenni';
        END IF;
    END //
DELIMITER ;

-- Creiamo la vista contenente i 10 libri più noleggiati
CREATE VIEW `top10_libri` AS
    SELECT `l`.`nome` AS `nome_libro`,
           `l`.`isbn` AS `isbn`,
           COUNT(*) AS `numero_prestiti`
    FROM `prestito` AS `p`
        INNER JOIN `copia_libro` AS `c` ON `p`.`id_copia` = `c`.`id` 
        INNER JOIN `libro` AS `l` ON `c`.`isbn_libro` = `l`.`isbn`
    WHERE `data_restituzione` IS NOT NULL
    GROUP BY `isbn`
    ORDER BY `numero_prestiti` DESC
    LIMIT 10;

DELIMITER //
-- Funzione per la conversione dell’ISBN10 a ISBN13
CREATE FUNCTION ISBN10TO13 (ISBN10 CHAR(10))
RETURNS CHAR(13)
DETERMINISTIC
BEGIN
    DECLARE ISBN13 CHAR(13);
    DECLARE CHECKSUM, I INT;

    SET ISBN13  = CONCAT('978' , LEFT(ISBN10, 9));

    SET I = 1; -- In MySQL gli indici delle stringhe partono da 1
    SET CHECKSUM = 0;
    WHILE I < 12 DO
        -- Sommo al checksum le cifre dispari, e quelle pari moltiplicate per 3
        SET CHECKSUM = CHECKSUM
                       + SUBSTRING(ISBN13, I, 1)
                       + SUBSTRING(ISBN13, I+1, 1) * 3;
        SET I = I + 2;
    END WHILE;

    SET CHECKSUM = (10 - (CHECKSUM % 10)) % 10;

    -- ISBN13 = ’978’ + prime 9 cifre dell’ISBN10 + checksum digit
    RETURN CONCAT(ISBN13, CONVERT(CHECKSUM, CHAR(1)));
END //
DELIMITER ;

DELIMITER //
-- Funzione per la conversione dell’ISBN13 a ISBN10
CREATE FUNCTION ISBN13TO10 (ISBN13 CHAR(13))
RETURNS CHAR(10)
DETERMINISTIC
BEGIN
    DECLARE ISBN10 CHAR(10);
    DECLARE CHECKSUM, I INT;

    -- Ha senso convertire solo gli ISBN13 che iniziano con '978'
    IF LEFT(ISBN13, 3) <> '978' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ISBN13 non convertibile';
        RETURN '';
    END IF;

    SET ISBN10  = SUBSTRING(ISBN13, 4, 9);

    SET I = 1, CHECKSUM = 0;
    WHILE I < 10 DO
        -- Sommo al checksum le cifre dispari, e quelle pari moltiplicate per 3
        SET CHECKSUM = CHECKSUM + SUBSTRING(ISBN10, I, 1) * (11-I);
        SET I = I + 1;
    END WHILE;

    SET CHECKSUM = (11 - (CHECKSUM % 11)) % 11;

    IF CHECKSUM = 10 THEN
        SET CHECKSUM = 'X';
    ELSE
        SET CHECKSUM = CONVERT(CHECKSUM, CHAR(1));
    END IF;

    -- ISBN10 = ISBN13 senza le prime 3 e l'ultima cifra + checksum digit
    RETURN CONCAT(ISBN10, CHECKSUM);
END //
DELIMITER ;