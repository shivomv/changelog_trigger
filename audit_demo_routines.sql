-- MySQL dump 10.13  Distrib 8.0.41, for Win64 (x86_64)
--
-- Host: localhost    Database: audit_demo
-- ------------------------------------------------------
-- Server version	8.0.41

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Dumping events for database 'audit_demo'
--

--
-- Dumping routines for database 'audit_demo'
--
/*!50003 DROP PROCEDURE IF EXISTS `generate_audit_triggers_sql` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `generate_audit_triggers_sql`()
BEGIN
    DECLARE old_len BIGINT;

    -- prevent truncation
    SELECT @@SESSION.group_concat_max_len INTO old_len;
    SET SESSION group_concat_max_len = 1000000;

    SELECT
        CONCAT(
'-- ==================================================
-- TABLE: ', t.table_name, '
-- ==================================================

DROP TRIGGER IF EXISTS ', t.table_name, '_after_update;
DROP TRIGGER IF EXISTS ', t.table_name, '_after_delete;

DELIMITER $$

CREATE TRIGGER ', t.table_name, '_after_update
AFTER UPDATE ON ', t.table_name, '
FOR EACH ROW
BEGIN
    INSERT INTO change_log (table_name, operation, old_data, new_data)
    VALUES (
        ''', t.table_name, ''',
        ''UPDATE'',
        JSON_OBJECT(', GROUP_CONCAT(
            CONCAT('''', c.column_name, ''', OLD.', c.column_name)
            ORDER BY c.ordinal_position SEPARATOR ', '
        ), '),
        JSON_OBJECT(', GROUP_CONCAT(
            CONCAT('''', c.column_name, ''', NEW.', c.column_name)
            ORDER BY c.ordinal_position SEPARATOR ', '
        ), ')
    );
END$$

CREATE TRIGGER ', t.table_name, '_after_delete
AFTER DELETE ON ', t.table_name, '
FOR EACH ROW
BEGIN
    INSERT INTO change_log (table_name, operation, old_data, new_data)
    VALUES (
        ''', t.table_name, ''',
        ''DELETE'',
        JSON_OBJECT(', GROUP_CONCAT(
            CONCAT('''', c.column_name, ''', OLD.', c.column_name)
            ORDER BY c.ordinal_position SEPARATOR ', '
        ), '),
        NULL
    );
END$$

DELIMITER ;
'
        ) AS trigger_sql
    FROM information_schema.tables t
    JOIN information_schema.columns c
      ON c.table_schema = t.table_schema
     AND c.table_name = t.table_name
    WHERE t.table_schema = DATABASE()
      AND t.table_name <> 'change_log'
    GROUP BY t.table_name;

    -- restore
    SET SESSION group_concat_max_len = old_len;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `generate_revert_sql` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `generate_revert_sql`(IN p_change_id BIGINT)
BEGIN
    DECLARE v_table VARCHAR(255);
    DECLARE v_op VARCHAR(10);

    -- fetch change info
    SELECT table_name, operation
    INTO v_table, v_op
    FROM change_log
    WHERE id = p_change_id;

    /* =======================
       Change not found
       ======================= */
    IF v_table IS NULL THEN

        SELECT 'ERROR: change_log id not found' AS message;

    /* =======================
       UPDATE → revert to OLD
       ======================= */
    ELSEIF v_op = 'UPDATE' THEN

        SELECT CONCAT(
            'UPDATE ', v_table, '
SET ',
            GROUP_CONCAT(
                CONCAT(
                    c.column_name, ' = ',
                    'JSON_UNQUOTE(JSON_EXTRACT(old_data, ''$.', c.column_name, '''))'
                )
                ORDER BY c.ordinal_position SEPARATOR ', '
            ),
            '
WHERE id = JSON_UNQUOTE(JSON_EXTRACT(old_data, ''$.id''));'
        ) AS revert_sql
        FROM information_schema.columns c
        WHERE c.table_schema = DATABASE()
          AND c.table_name = v_table;

    /* =======================
       DELETE → re-insert OLD
       ======================= */
    ELSEIF v_op = 'DELETE' THEN

        SELECT CONCAT(
            'INSERT INTO ', v_table, ' (',
            GROUP_CONCAT(c.column_name ORDER BY c.ordinal_position),
            ')
VALUES (',
            GROUP_CONCAT(
                CONCAT(
                    'JSON_UNQUOTE(JSON_EXTRACT(old_data, ''$.', c.column_name, '''))'
                )
                ORDER BY c.ordinal_position SEPARATOR ', '
            ),
            ');'
        ) AS revert_sql
        FROM information_schema.columns c
        WHERE c.table_schema = DATABASE()
          AND c.table_name = v_table;

    ELSE
        SELECT 'ERROR: Unsupported operation type' AS message;
    END IF;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `revert_change` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `revert_change`(IN p_change_id BIGINT)
BEGIN
    DECLARE v_table VARCHAR(255);
    DECLARE v_op VARCHAR(10);
    DECLARE v_row_id BIGINT;
    DECLARE v_delete_log_id BIGINT;

    -- Fetch change info + old snapshot
    SELECT
        table_name,
        operation,
        JSON_UNQUOTE(JSON_EXTRACT(old_data, '$.id')),
        old_data
    INTO
        v_table,
        v_op,
        v_row_id,
        @old_json
    FROM change_log
    WHERE id = p_change_id;

    IF v_table IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid change_log id';
    END IF;

    /* =========================
       CASE 1: UPDATE revert
       ========================= */
    IF v_op = 'UPDATE' THEN

       -- Check if row was deleted later (GET LAST DELETE)
		SELECT id
		INTO v_delete_log_id
		FROM change_log
		WHERE table_name = v_table
		  AND operation = 'DELETE'
		  AND JSON_UNQUOTE(JSON_EXTRACT(old_data, '$.id')) = v_row_id
		  AND id > p_change_id
		ORDER BY id DESC
		LIMIT 1;


        IF v_delete_log_id IS NOT NULL THEN
            -- Print message and STOP
            SELECT CONCAT(
                'Cannot revert UPDATE. ',
                'This record was deleted later at change_log id = ',
                v_delete_log_id,
                '. Please restore using that id first.'
            ) AS message;
        ELSE
            -- Prevent audit recursion
            SET @skip_audit = 1;

            -- Generate UPDATE revert
            SELECT CONCAT(
                'UPDATE ', v_table, ' SET ',
                GROUP_CONCAT(
                    CONCAT(
                        c.column_name, ' = ',
                        'JSON_UNQUOTE(JSON_EXTRACT(@old_json, ''$.', c.column_name, '''))'
                    )
                    ORDER BY c.ordinal_position SEPARATOR ', '
                ),
                ' WHERE id = ', v_row_id, ';'
            )
            INTO @sql_text
            FROM information_schema.columns c
            WHERE c.table_schema = DATABASE()
              AND c.table_name = v_table;

            PREPARE stmt FROM @sql_text;
            EXECUTE stmt;
            DEALLOCATE PREPARE stmt;

            SET @skip_audit = NULL;

            SELECT 'UPDATE reverted successfully' AS message;
        END IF;

    /* =========================
       CASE 2: DELETE revert
       ========================= */
    ELSEIF v_op = 'DELETE' THEN

        -- Prevent audit recursion
        SET @skip_audit = 1;

        -- Restore deleted row
        SELECT CONCAT(
            'REPLACE INTO ', v_table, ' (',
            GROUP_CONCAT(c.column_name ORDER BY c.ordinal_position),
            ') VALUES (',
            GROUP_CONCAT(
                CONCAT(
                    'JSON_UNQUOTE(JSON_EXTRACT(@old_json, ''$.', c.column_name, '''))'
                )
                ORDER BY c.ordinal_position SEPARATOR ', '
            ),
            ');'
        )
        INTO @sql_text
        FROM information_schema.columns c
        WHERE c.table_schema = DATABASE()
          AND c.table_name = v_table;

        PREPARE stmt FROM @sql_text;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

        SET @skip_audit = NULL;

        SELECT 'DELETE reverted successfully (row restored)' AS message;

    ELSE
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Unsupported operation type';
    END IF;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-02-02  1:41:11
