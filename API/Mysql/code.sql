-- MySQL dump 10.13  Distrib 8.0.46, for Win64 (x86_64)
--
-- Host: localhost    Database: reservation_system
-- ------------------------------------------------------
-- Server version	8.0.46

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `accountinfo`
--

DROP TABLE IF EXISTS `accountinfo`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `accountinfo` (
  `AccountID` int NOT NULL AUTO_INCREMENT,
  `FirstName` varchar(50) NOT NULL,
  `LastName` varchar(50) NOT NULL,
  `PhoneNum` varchar(20) NOT NULL,
  `Email` varchar(255) NOT NULL,
  `StatusID` int NOT NULL,
  `PasswordEnc` varchar(255) NOT NULL,
  PRIMARY KEY (`AccountID`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `accountinfo`
--

LOCK TABLES `accountinfo` WRITE;
/*!40000 ALTER TABLE `accountinfo` DISABLE KEYS */;
INSERT INTO `accountinfo` VALUES (2,'sunny','duangdala','02055083766','sunny.duangdal@gmail.com',3,'$2b$10$OrFkNcCUw1gOS77xKmESpeqnNcoZD2QA8NSwbSFkpcNZD99N9LsuS'),(4,'Steven','Universe','0256565646','Steven.Universe@gmail.com',1,'$2b$10$Umx2CuBxNzKryEk6ZJllnuI.NoaqaTrJ6m7tZNvVZrR7oqBL85leq'),(5,'thanongsai','duangdala','02054654654','thanongsai.duangdala@gmail.com',1,'$2b$10$o4UVMZIKfU2j2mU9f.XdYer0vT.LeaFsKRRJXBVJanxXgw2v3p9Zq');
/*!40000 ALTER TABLE `accountinfo` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `accountstatusinfo`
--

DROP TABLE IF EXISTS `accountstatusinfo`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `accountstatusinfo` (
  `StatusID` int NOT NULL AUTO_INCREMENT,
  `StatusType` varchar(45) NOT NULL,
  PRIMARY KEY (`StatusID`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `accountstatusinfo`
--

LOCK TABLES `accountstatusinfo` WRITE;
/*!40000 ALTER TABLE `accountstatusinfo` DISABLE KEYS */;
INSERT INTO `accountstatusinfo` VALUES (1,'Customer'),(2,'Organizer'),(3,'Developer'),(4,'Not in use'),(5,'Ban');
/*!40000 ALTER TABLE `accountstatusinfo` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `attendeeresponse`
--

DROP TABLE IF EXISTS `attendeeresponse`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `attendeeresponse` (
  `ResponseID` int NOT NULL AUTO_INCREMENT,
  `EventQuestionID` int NOT NULL,
  `attendeeID` int NOT NULL,
  `attendeeAnswer` varchar(255) NOT NULL,
  PRIMARY KEY (`ResponseID`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `attendeeresponse`
--

LOCK TABLES `attendeeresponse` WRITE;
/*!40000 ALTER TABLE `attendeeresponse` DISABLE KEYS */;
INSERT INTO `attendeeresponse` VALUES (1,1,1,'1'),(2,2,1,'2'),(3,3,1,'1');
/*!40000 ALTER TABLE `attendeeresponse` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `categoryinfo`
--

DROP TABLE IF EXISTS `categoryinfo`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `categoryinfo` (
  `CategoryID` int NOT NULL AUTO_INCREMENT,
  `CategoryName` varchar(50) NOT NULL,
  `CategoryIconPath` varchar(255) NOT NULL,
  PRIMARY KEY (`CategoryID`)
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `categoryinfo`
--

LOCK TABLES `categoryinfo` WRITE;
/*!40000 ALTER TABLE `categoryinfo` DISABLE KEYS */;
INSERT INTO `categoryinfo` VALUES (3,'Food','logo/food.ico'),(4,'Sports+','ico/sport.ico'),(5,'Pilot','logo/Pilot.ico'),(6,'Running','running'),(7,'Sports','sports'),(8,'Fitness','fitness');
/*!40000 ALTER TABLE `categoryinfo` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `eventcategoryinfo`
--

DROP TABLE IF EXISTS `eventcategoryinfo`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `eventcategoryinfo` (
  `EventCategoryID` int NOT NULL AUTO_INCREMENT,
  `EventID` int NOT NULL,
  `CategoryID` int NOT NULL,
  PRIMARY KEY (`EventCategoryID`)
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `eventcategoryinfo`
--

LOCK TABLES `eventcategoryinfo` WRITE;
/*!40000 ALTER TABLE `eventcategoryinfo` DISABLE KEYS */;
INSERT INTO `eventcategoryinfo` VALUES (6,1,6),(7,1,7),(8,1,8);
/*!40000 ALTER TABLE `eventcategoryinfo` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `eventimageinfo`
--

DROP TABLE IF EXISTS `eventimageinfo`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `eventimageinfo` (
  `ImageID` int NOT NULL AUTO_INCREMENT,
  `EventID` int NOT NULL,
  `ImageName` varchar(50) NOT NULL,
  `ImagePath` varchar(255) NOT NULL,
  `IsThumbnail` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`ImageID`)
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `eventimageinfo`
--

LOCK TABLES `eventimageinfo` WRITE;
/*!40000 ALTER TABLE `eventimageinfo` DISABLE KEYS */;
INSERT INTO `eventimageinfo` VALUES (7,1,'Main Img','/static/event_images/1/a24fb93c27a449d08a620c4f20dc11f3.jpg',1);
/*!40000 ALTER TABLE `eventimageinfo` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `eventinfo`
--

DROP TABLE IF EXISTS `eventinfo`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `eventinfo` (
  `EventID` int NOT NULL AUTO_INCREMENT,
  `EventName` varchar(100) NOT NULL,
  `EventStartingYMDT` datetime NOT NULL,
  `EventEndingYMDT` datetime NOT NULL,
  `EventAddress` varchar(255) NOT NULL,
  `Latitude` decimal(9,6) NOT NULL,
  `Longitude` decimal(9,6) NOT NULL,
  `EventDescription` text NOT NULL,
  `EventOrganizerID` int NOT NULL,
  PRIMARY KEY (`EventID`)
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `eventinfo`
--

LOCK TABLES `eventinfo` WRITE;
/*!40000 ALTER TABLE `eventinfo` DISABLE KEYS */;
INSERT INTO `eventinfo` VALUES (1,'That Luang to Mekong Marathon','2026-10-01 06:00:00','2026-10-01 13:00:00','That Luang',17.975649,102.633682,'Marathon from That Luang to Mekong and back. They is 10km and 21km',1),(4,'Pilot Training part 1','2026-05-12 09:00:00','2026-05-12 18:00:00','Wattay International Airport',17.973483,102.568088,'Try become a cadet for one day.',2),(5,'Pilot Training part 2','2026-11-12 06:00:00','2026-11-12 18:00:00','Wattay International Airport',17.973483,102.568088,'Try become a cadet for one day.',2),(6,'Marathon','2026-08-15 04:20:00','2026-08-16 22:20:00','ThatLuangpart1',17.976542,102.635899,'Marathon from Mekong to ThatLuang and back that is 10 km  or 21km.',1),(8,'MarathonPart2','2026-08-20 06:00:00','2026-08-06 16:00:00','ThatLuang',17.975707,102.633619,'Marathon from Thatluang to Mekong and back. For those who want to do either 10km or 21km.',1),(9,'PilotTrainingPart3','2026-08-15 10:00:00','2026-08-08 20:00:00','Wattay Airport',17.973006,102.567955,'sdkjaslkdjlksada',2);
/*!40000 ALTER TABLE `eventinfo` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `eventorganizerinfo`
--

DROP TABLE IF EXISTS `eventorganizerinfo`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `eventorganizerinfo` (
  `EventOrganizerID` int NOT NULL AUTO_INCREMENT,
  `EventOrganizerName` varchar(255) NOT NULL,
  `EventOrganizerLogoPath` varchar(255) NOT NULL,
  `CreatedByAccountID` int NOT NULL,
  `EventOrganizerDiscription` text NOT NULL,
  PRIMARY KEY (`EventOrganizerID`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `eventorganizerinfo`
--

LOCK TABLES `eventorganizerinfo` WRITE;
/*!40000 ALTER TABLE `eventorganizerinfo` DISABLE KEYS */;
INSERT INTO `eventorganizerinfo` VALUES (1,'LaoMarathon','organizer_logos/aa19a3ef0ef1410fb9d54b6b819913d5.jpg',4,'We love Marathon in Lao'),(2,'Lao Aviation Center','organizer_logos/f6ccf6ce24884b579db9167851e133a1.avif',4,'Located at Wattay internation airport, come and join whenever you want.');
/*!40000 ALTER TABLE `eventorganizerinfo` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `eventquestioninfo`
--

DROP TABLE IF EXISTS `eventquestioninfo`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `eventquestioninfo` (
  `EventQuestionID` int NOT NULL AUTO_INCREMENT,
  `EventID` int NOT NULL,
  `EventQuestion` varchar(255) NOT NULL,
  `EventQuestionTypeID` int NOT NULL,
  `IsRequire` tinyint NOT NULL,
  `SortOrder` int NOT NULL,
  `Options` json DEFAULT NULL,
  PRIMARY KEY (`EventQuestionID`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `eventquestioninfo`
--

LOCK TABLES `eventquestioninfo` WRITE;
/*!40000 ALTER TABLE `eventquestioninfo` DISABLE KEYS */;
INSERT INTO `eventquestioninfo` VALUES (1,1,'Gender',3,1,1,'[\"male\", \"female\", \"others\"]'),(4,2,'Gender',3,1,1,'[\"Male\", \"Female\", \"others\"]'),(5,1,'What food do you want?',3,1,2,'[\"Fried Rice Chicken\", \"Fried Rice Pork\", \"Fried Rice Vegan\", \"Fried Rice Hala\"]');
/*!40000 ALTER TABLE `eventquestioninfo` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `eventquestiontype`
--

DROP TABLE IF EXISTS `eventquestiontype`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `eventquestiontype` (
  `EventQuestionTypeID` int NOT NULL AUTO_INCREMENT,
  `EventQuestionType` varchar(50) NOT NULL,
  PRIMARY KEY (`EventQuestionTypeID`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `eventquestiontype`
--

LOCK TABLES `eventquestiontype` WRITE;
/*!40000 ALTER TABLE `eventquestiontype` DISABLE KEYS */;
INSERT INTO `eventquestiontype` VALUES (1,'Text'),(2,'Checkbox'),(3,'Radio box'),(4,'Text save as encrypted'),(5,'Yes or No');
/*!40000 ALTER TABLE `eventquestiontype` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `eventrole`
--

DROP TABLE IF EXISTS `eventrole`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `eventrole` (
  `EventRoleID` int NOT NULL AUTO_INCREMENT,
  `RoleName` varchar(50) NOT NULL,
  PRIMARY KEY (`EventRoleID`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `eventrole`
--

LOCK TABLES `eventrole` WRITE;
/*!40000 ALTER TABLE `eventrole` DISABLE KEYS */;
INSERT INTO `eventrole` VALUES (1,'Editor'),(2,'Viewer2');
/*!40000 ALTER TABLE `eventrole` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `eventsponserinfo`
--

DROP TABLE IF EXISTS `eventsponserinfo`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `eventsponserinfo` (
  `EventSponserID` int NOT NULL AUTO_INCREMENT,
  `EventID` int NOT NULL,
  `SponserID` int NOT NULL,
  PRIMARY KEY (`EventSponserID`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `eventsponserinfo`
--

LOCK TABLES `eventsponserinfo` WRITE;
/*!40000 ALTER TABLE `eventsponserinfo` DISABLE KEYS */;
INSERT INTO `eventsponserinfo` VALUES (3,1,3),(5,1,4),(6,1,1);
/*!40000 ALTER TABLE `eventsponserinfo` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `eventstaff`
--

DROP TABLE IF EXISTS `eventstaff`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `eventstaff` (
  `AssigmentID` int NOT NULL AUTO_INCREMENT,
  `EventID` int NOT NULL,
  `MemberID` int NOT NULL,
  `EventRoleID` int NOT NULL,
  `AssignedAtYMDT` datetime NOT NULL,
  PRIMARY KEY (`AssigmentID`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `eventstaff`
--

LOCK TABLES `eventstaff` WRITE;
/*!40000 ALTER TABLE `eventstaff` DISABLE KEYS */;
INSERT INTO `eventstaff` VALUES (4,1,5,1,'2026-08-18 08:30:00'),(6,1,4,1,'2026-08-18 08:38:00');
/*!40000 ALTER TABLE `eventstaff` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `identityverification`
--

DROP TABLE IF EXISTS `identityverification`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `identityverification` (
  `VerificationID` int NOT NULL AUTO_INCREMENT,
  `AccountID` int NOT NULL,
  `VerificationTypeID` int NOT NULL,
  `IDNumberEncrypted` varchar(255) NOT NULL,
  `FullNameOnID` varchar(255) NOT NULL,
  `DateOfBirth` date NOT NULL,
  `DocumentImageRedPath` varchar(255) NOT NULL,
  `VerificationStatusID` int NOT NULL,
  `ReviewedByAccountID` int NOT NULL,
  `SubmittedAtYMDT` datetime NOT NULL,
  `ReviewedAtYMDT` datetime NOT NULL,
  PRIMARY KEY (`VerificationID`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `identityverification`
--

LOCK TABLES `identityverification` WRITE;
/*!40000 ALTER TABLE `identityverification` DISABLE KEYS */;
INSERT INTO `identityverification` VALUES (1,2,1,'3eqwf434f332f2','sdasdsadsasada','2026-10-06','DocIMG/sdaksjdasdl.png',2,1,'2026-08-05 08:38:27','2026-08-05 08:38:27'),(4,4,1,'3eqwf434f332f2','sdasdsadsasada','2026-10-06','DocIMG/sdaksjdasdl.png',2,1,'2026-08-05 08:38:27','2026-08-05 08:38:27');
/*!40000 ALTER TABLE `identityverification` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `ordersinfo`
--

DROP TABLE IF EXISTS `ordersinfo`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ordersinfo` (
  `OrderID` int NOT NULL AUTO_INCREMENT,
  `AccountID` int NOT NULL,
  `PaymentTypeID` int NOT NULL,
  `PaymentDateYMDT` datetime NOT NULL,
  `ProveOfPayment` varchar(255) NOT NULL,
  PRIMARY KEY (`OrderID`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `ordersinfo`
--

LOCK TABLES `ordersinfo` WRITE;
/*!40000 ALTER TABLE `ordersinfo` DISABLE KEYS */;
INSERT INTO `ordersinfo` VALUES (1,1,1,'2026-08-05 03:33:23','BCELID:23124234455464'),(2,2,1,'2026-08-05 03:36:09','12321443534');
/*!40000 ALTER TABLE `ordersinfo` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `organizermember`
--

DROP TABLE IF EXISTS `organizermember`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `organizermember` (
  `MemberID` int NOT NULL AUTO_INCREMENT,
  `AccountID` int NOT NULL,
  `EventOrganizerID` int NOT NULL,
  `TeamRoleID` int NOT NULL,
  PRIMARY KEY (`MemberID`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `organizermember`
--

LOCK TABLES `organizermember` WRITE;
/*!40000 ALTER TABLE `organizermember` DISABLE KEYS */;
INSERT INTO `organizermember` VALUES (4,4,1,3),(6,2,2,3);
/*!40000 ALTER TABLE `organizermember` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `paymenttypeinfo`
--

DROP TABLE IF EXISTS `paymenttypeinfo`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `paymenttypeinfo` (
  `PaymentTypeID` int NOT NULL AUTO_INCREMENT,
  `PaymentTypeName` varchar(50) NOT NULL,
  PRIMARY KEY (`PaymentTypeID`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `paymenttypeinfo`
--

LOCK TABLES `paymenttypeinfo` WRITE;
/*!40000 ALTER TABLE `paymenttypeinfo` DISABLE KEYS */;
INSERT INTO `paymenttypeinfo` VALUES (1,'BCEL'),(2,'APB'),(3,'LDB');
/*!40000 ALTER TABLE `paymenttypeinfo` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `sponserinfo`
--

DROP TABLE IF EXISTS `sponserinfo`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sponserinfo` (
  `SponserID` int NOT NULL AUTO_INCREMENT,
  `SponserName` varchar(50) NOT NULL,
  `SponserLogoPath` varchar(255) NOT NULL,
  PRIMARY KEY (`SponserID`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `sponserinfo`
--

LOCK TABLES `sponserinfo` WRITE;
/*!40000 ALTER TABLE `sponserinfo` DISABLE KEYS */;
INSERT INTO `sponserinfo` VALUES (1,'Beer lao','sponsor_logos/88745a25b3c64281a57e3ac0a83b7ed3.png'),(3,'TigerHead','sponsor_logos/571fc7568f12414abe5c2b04294dff81.jpg'),(4,'Pepsi','sponsor_logos/2e7d26feb1cf4c9e9737cb588e1cdf5c.webp');
/*!40000 ALTER TABLE `sponserinfo` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `teamrole`
--

DROP TABLE IF EXISTS `teamrole`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `teamrole` (
  `TeamRoleID` int NOT NULL AUTO_INCREMENT,
  `TeamRoleName` varchar(50) NOT NULL,
  PRIMARY KEY (`TeamRoleID`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `teamrole`
--

LOCK TABLES `teamrole` WRITE;
/*!40000 ALTER TABLE `teamrole` DISABLE KEYS */;
INSERT INTO `teamrole` VALUES (3,'Developer'),(4,'Manager');
/*!40000 ALTER TABLE `teamrole` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `ticketattendence`
--

DROP TABLE IF EXISTS `ticketattendence`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ticketattendence` (
  `attendeeID` int NOT NULL AUTO_INCREMENT,
  `TicketTypeID` int NOT NULL,
  `OrderID` int NOT NULL,
  `FirstName` varchar(50) NOT NULL,
  `LastName` varchar(50) NOT NULL,
  `PhoneNum` varchar(20) NOT NULL,
  `Email` varchar(255) NOT NULL,
  PRIMARY KEY (`attendeeID`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `ticketattendence`
--

LOCK TABLES `ticketattendence` WRITE;
/*!40000 ALTER TABLE `ticketattendence` DISABLE KEYS */;
INSERT INTO `ticketattendence` VALUES (1,1,1,'Steve','Universe','020565654','steve@gmail.com');
/*!40000 ALTER TABLE `ticketattendence` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `tickettype`
--

DROP TABLE IF EXISTS `tickettype`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tickettype` (
  `TicketTypeID` int NOT NULL AUTO_INCREMENT,
  `EventID` int NOT NULL,
  `TypeName` varchar(45) NOT NULL,
  `PriceInKIP` int NOT NULL,
  `Capacity` int NOT NULL,
  `SaleStartYMDT` datetime NOT NULL,
  `SaleEndYMDT` datetime NOT NULL,
  PRIMARY KEY (`TicketTypeID`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `tickettype`
--

LOCK TABLES `tickettype` WRITE;
/*!40000 ALTER TABLE `tickettype` DISABLE KEYS */;
INSERT INTO `tickettype` VALUES (1,1,'10km',350000,250,'2016-09-01 00:00:00','2016-09-25 00:00:00'),(2,1,'21km',400000,250,'2016-09-01 00:00:00','2016-09-25 00:00:00'),(3,2,'21km',400000,250,'2016-10-01 00:00:00','2016-10-25 00:00:00'),(4,2,'20km',350000,250,'2016-10-01 00:00:00','2016-10-25 00:00:00'),(6,1,'Normal',250000,250,'2026-10-06 00:00:00','2026-10-20 20:00:00');
/*!40000 ALTER TABLE `tickettype` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `verificationstatusinfo`
--

DROP TABLE IF EXISTS `verificationstatusinfo`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `verificationstatusinfo` (
  `VerificationStatusID` int NOT NULL AUTO_INCREMENT,
  `StatusName` varchar(20) NOT NULL,
  PRIMARY KEY (`VerificationStatusID`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `verificationstatusinfo`
--

LOCK TABLES `verificationstatusinfo` WRITE;
/*!40000 ALTER TABLE `verificationstatusinfo` DISABLE KEYS */;
INSERT INTO `verificationstatusinfo` VALUES (1,'Pending'),(2,'Approved'),(3,'Denied');
/*!40000 ALTER TABLE `verificationstatusinfo` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `verificationtypeinfo`
--

DROP TABLE IF EXISTS `verificationtypeinfo`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `verificationtypeinfo` (
  `VerificationTypeID` int NOT NULL AUTO_INCREMENT,
  `IDType` varchar(50) NOT NULL,
  PRIMARY KEY (`VerificationTypeID`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `verificationtypeinfo`
--

LOCK TABLES `verificationtypeinfo` WRITE;
/*!40000 ALTER TABLE `verificationtypeinfo` DISABLE KEYS */;
INSERT INTO `verificationtypeinfo` VALUES (1,'Password'),(2,'Personal Residency Card ID'),(5,'My Number Card');
/*!40000 ALTER TABLE `verificationtypeinfo` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-08-18 22:59:47
