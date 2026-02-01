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
-- Table structure for table `change_log`
--

DROP TABLE IF EXISTS `change_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `change_log` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `table_name` varchar(100) DEFAULT NULL,
  `operation` varchar(10) DEFAULT NULL,
  `old_data` json DEFAULT NULL,
  `new_data` json DEFAULT NULL,
  `changed_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `change_log`
--

LOCK TABLES `change_log` WRITE;
/*!40000 ALTER TABLE `change_log` DISABLE KEYS */;
INSERT INTO `change_log` VALUES (1,'users','UPDATE','{\"id\": 1, \"name\": \"Rahul\", \"email\": \"rahul@mail.com\"}','{\"id\": 1, \"name\": \"Rahul\", \"email\": \"rahul.new@mail.com\"}','2026-02-01 19:32:27'),(2,'users','UPDATE','{\"id\": 1, \"name\": \"Rahul\", \"email\": \"rahul.new@mail.com\"}','{\"id\": 1, \"name\": \"Rahul\", \"email\": \"rahul@mail.com\"}','2026-02-01 19:43:20'),(3,'users','UPDATE','{\"id\": 1, \"name\": \"Rahul\", \"email\": \"rahul@mail.com\"}','{\"id\": 1, \"name\": \"Rahul\", \"email\": \"rahul.new@mail.com\"}','2026-02-01 19:43:58'),(4,'users','UPDATE','{\"id\": 1, \"name\": \"Rahul\", \"email\": \"rahul.new@mail.com\"}','{\"id\": 1, \"name\": \"Rahul\", \"email\": \"rahul@mail.com\"}','2026-02-01 19:45:06'),(5,'users','UPDATE','{\"id\": 1, \"name\": \"Rahul\", \"email\": \"rahul@mail.com\"}','{\"id\": 1, \"name\": \"Rahul\", \"email\": \"rahul.new@mail.com\"}','2026-02-01 19:45:26'),(6,'users','DELETE','{\"id\": 1, \"name\": \"Rahul\", \"email\": \"rahul.new@mail.com\"}',NULL,'2026-02-01 19:46:01'),(7,'users','UPDATE','{\"id\": 1, \"name\": \"Rahul\", \"email\": \"rahul@mail.com\"}',NULL,'2026-02-01 19:56:49'),(8,'users','DELETE','{\"id\": 1, \"name\": \"Rahul\", \"email\": \"rahul.new@mail.com\"}',NULL,'2026-02-01 19:57:12'),(9,'users','DELETE','{\"id\": 1, \"name\": \"Rahul\", \"email\": \"rahul.new@mail.com\"}',NULL,'2026-02-01 20:05:25'),(10,'users','DELETE','{\"id\": 1, \"name\": \"Rahul\", \"email\": \"rahul@mail.com\"}',NULL,'2026-02-01 20:07:26');
/*!40000 ALTER TABLE `change_log` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-02-02  1:41:10
