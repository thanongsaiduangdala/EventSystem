SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS accountstatusinfo (
  StatusID INT NOT NULL AUTO_INCREMENT,
  StatusType VARCHAR(45) NOT NULL,
  PRIMARY KEY (StatusID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS eventstatusinfo (
  EventStatusID INT NOT NULL,
  StatusName VARCHAR(30) NOT NULL,
  PRIMARY KEY (EventStatusID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS organizerstatusinfo (
  OrganizerStatusID INT NOT NULL,
  StatusName VARCHAR(30) NOT NULL,
  PRIMARY KEY (OrganizerStatusID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS eventquestiontype (
  EventQuestionTypeID INT NOT NULL AUTO_INCREMENT,
  EventQuestionType VARCHAR(50) NOT NULL,
  PRIMARY KEY (EventQuestionTypeID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS eventrole (
  EventRoleID INT NOT NULL AUTO_INCREMENT,
  RoleName VARCHAR(50) NOT NULL,
  PRIMARY KEY (EventRoleID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS teamrole (
  TeamRoleID INT NOT NULL AUTO_INCREMENT,
  TeamRoleName VARCHAR(50) NOT NULL,
  PRIMARY KEY (TeamRoleID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS memberstatusinfo (
  MemberStatusID INT NOT NULL,
  StatusName VARCHAR(30) NOT NULL,
  PRIMARY KEY (MemberStatusID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS paymenttypeinfo (
  PaymentTypeID INT NOT NULL AUTO_INCREMENT,
  PaymentTypeName VARCHAR(50) NOT NULL,
  PRIMARY KEY (PaymentTypeID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS verificationstatusinfo (
  VerificationStatusID INT NOT NULL AUTO_INCREMENT,
  StatusName VARCHAR(20) NOT NULL,
  PRIMARY KEY (VerificationStatusID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS verificationtypeinfo (
  VerificationTypeID INT NOT NULL AUTO_INCREMENT,
  IDType VARCHAR(50) NOT NULL,
  PRIMARY KEY (VerificationTypeID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS permissioninfo (
  PermissionID INT NOT NULL AUTO_INCREMENT,
  PermissionName VARCHAR(100) NOT NULL,
  PermissionDescription VARCHAR(255),
  PRIMARY KEY (PermissionID),
  UNIQUE KEY uq_permissioninfo_permissionname (PermissionName)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS rolepermissioninfo (
  RolePermissionID INT NOT NULL AUTO_INCREMENT,
  StatusID INT NOT NULL,
  PermissionID INT NOT NULL,
  PRIMARY KEY (RolePermissionID),
  UNIQUE KEY uq_status_permission (StatusID, PermissionID),
  CONSTRAINT fk_rolepermissioninfo_1 FOREIGN KEY (StatusID) REFERENCES accountstatusinfo (StatusID) ON DELETE CASCADE,
  CONSTRAINT fk_rolepermissioninfo_2 FOREIGN KEY (PermissionID) REFERENCES permissioninfo (PermissionID) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS accountinfo (
  AccountID INT NOT NULL AUTO_INCREMENT,
  FirstName VARCHAR(50) NOT NULL,
  LastName VARCHAR(50) NOT NULL,
  PhoneNum VARCHAR(20) NOT NULL,
  ProfileImagePath VARCHAR(255),
  Email VARCHAR(255) NOT NULL,
  StatusID INT NOT NULL,
  PasswordEnc VARCHAR(255) NOT NULL,
  PRIMARY KEY (AccountID),
  KEY idx_accountinfo_email (Email),
  CONSTRAINT fk_accountinfo_1 FOREIGN KEY (StatusID) REFERENCES accountstatusinfo (StatusID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS categoryinfo (
  CategoryID INT NOT NULL AUTO_INCREMENT,
  CategoryName VARCHAR(50) NOT NULL,
  CategoryIconPath VARCHAR(255) NOT NULL,
  PRIMARY KEY (CategoryID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS eventorganizerinfo (
  EventOrganizerID INT NOT NULL AUTO_INCREMENT,
  EventOrganizerName VARCHAR(255) NOT NULL,
  EventOrganizerLogoPath VARCHAR(255) NOT NULL,
  CreatedByAccountID INT NOT NULL,
  EventOrganizerDiscription TEXT,
  OrganizerStatusID INT NOT NULL DEFAULT 1,
  DenyReason TEXT NULL,
  PRIMARY KEY (EventOrganizerID),
  CONSTRAINT fk_eventorganizerinfo_1 FOREIGN KEY (CreatedByAccountID) REFERENCES accountinfo (AccountID),
  CONSTRAINT fk_eventorganizerinfo_2 FOREIGN KEY (OrganizerStatusID) REFERENCES organizerstatusinfo (OrganizerStatusID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS eventinfo (
  EventID INT NOT NULL AUTO_INCREMENT,
  EventName VARCHAR(100) NOT NULL,
  EventStartingYMDT DATETIME NOT NULL,
  EventEndingYMDT DATETIME NOT NULL,
  EventAddress VARCHAR(255) NOT NULL,
  Latitude DECIMAL(9,6) NOT NULL,
  Longitude DECIMAL(9,6) NOT NULL,
  EventDescription TEXT NOT NULL,
  EventOrganizerID INT NOT NULL,
  OnePerPerson TINYINT NOT NULL DEFAULT 0 CHECK (OnePerPerson IN (0, 1)),
  EventStatusID INT NOT NULL DEFAULT 2,
  EventVisible TINYINT NOT NULL DEFAULT 1 CHECK (EventVisible IN (0, 1)),
  ScanEnabled TINYINT NOT NULL DEFAULT 0 CHECK (ScanEnabled IN (0, 1)),
  DenyReason TEXT NULL,
  PRIMARY KEY (EventID),
  KEY idx_eventinfo_public (EventStatusID, EventVisible, EventStartingYMDT),
  CONSTRAINT fk_eventinfo_1 FOREIGN KEY (EventOrganizerID) REFERENCES eventorganizerinfo (EventOrganizerID),
  CONSTRAINT fk_eventinfo_2 FOREIGN KEY (EventStatusID) REFERENCES eventstatusinfo (EventStatusID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS organizermember (
  MemberID INT NOT NULL AUTO_INCREMENT,
  AccountID INT NOT NULL,
  EventOrganizerID INT NOT NULL,
  TeamRoleID INT NOT NULL,
  MemberStatusID INT NOT NULL DEFAULT 2,
  ActiveMembershipKey VARCHAR(64) GENERATED ALWAYS AS (IF(MemberStatusID = 4, NULL, CONCAT(AccountID, ':', EventOrganizerID))) VIRTUAL,
  PRIMARY KEY (MemberID),
  UNIQUE KEY uq_organizer_active_member (ActiveMembershipKey),
  CONSTRAINT fk_organizermember_1 FOREIGN KEY (AccountID) REFERENCES accountinfo (AccountID),
  CONSTRAINT fk_organizermember_2 FOREIGN KEY (EventOrganizerID) REFERENCES eventorganizerinfo (EventOrganizerID) ON DELETE CASCADE,
  CONSTRAINT fk_organizermember_3 FOREIGN KEY (TeamRoleID) REFERENCES teamrole (TeamRoleID),
  CONSTRAINT fk_organizermember_4 FOREIGN KEY (MemberStatusID) REFERENCES memberstatusinfo (MemberStatusID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS eventstaff (
  AssigmentID INT NOT NULL AUTO_INCREMENT,
  EventID INT NOT NULL,
  MemberID INT NOT NULL,
  EventRoleID INT NOT NULL,
  AssignedAtYMDT DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CanScan TINYINT NOT NULL DEFAULT 0 CHECK (CanScan IN (0, 1)),
  PRIMARY KEY (AssigmentID),
  UNIQUE KEY uq_event_staff_member (EventID, MemberID),
  CONSTRAINT fk_eventstaff_1 FOREIGN KEY (EventID) REFERENCES eventinfo (EventID) ON DELETE CASCADE,
  CONSTRAINT fk_eventstaff_2 FOREIGN KEY (MemberID) REFERENCES organizermember (MemberID),
  CONSTRAINT fk_eventstaff_3 FOREIGN KEY (EventRoleID) REFERENCES eventrole (EventRoleID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS eventcategoryinfo (
  EventCategoryID INT NOT NULL AUTO_INCREMENT,
  EventID INT NOT NULL,
  CategoryID INT NOT NULL,
  PRIMARY KEY (EventCategoryID),
  CONSTRAINT fk_eventcategoryinfo_1 FOREIGN KEY (EventID) REFERENCES eventinfo (EventID) ON DELETE CASCADE,
  CONSTRAINT fk_eventcategoryinfo_2 FOREIGN KEY (CategoryID) REFERENCES categoryinfo (CategoryID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS eventimageinfo (
  ImageID INT NOT NULL AUTO_INCREMENT,
  EventID INT NOT NULL,
  ImageName VARCHAR(50) NOT NULL,
  ImagePath VARCHAR(255) NOT NULL,
  IsThumbnail TINYINT NOT NULL DEFAULT 0 CHECK (IsThumbnail IN (0, 1)),
  PRIMARY KEY (ImageID),
  CONSTRAINT fk_eventimageinfo_1 FOREIGN KEY (EventID) REFERENCES eventinfo (EventID) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS eventquestioninfo (
  EventQuestionID INT NOT NULL AUTO_INCREMENT,
  EventID INT NOT NULL,
  EventQuestion VARCHAR(255) NOT NULL,
  EventQuestionTypeID INT NOT NULL,
  IsRequire TINYINT(1) NOT NULL,
  SortOrder INT NOT NULL,
  Options TEXT,
  PRIMARY KEY (EventQuestionID),
  CONSTRAINT fk_eventquestioninfo_1 FOREIGN KEY (EventID) REFERENCES eventinfo (EventID) ON DELETE CASCADE,
  CONSTRAINT fk_eventquestioninfo_2 FOREIGN KEY (EventQuestionTypeID) REFERENCES eventquestiontype (EventQuestionTypeID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS sponserinfo (
  SponserID INT NOT NULL AUTO_INCREMENT,
  SponserName VARCHAR(50) NOT NULL,
  SponserLogoPath VARCHAR(255) NOT NULL,
  PRIMARY KEY (SponserID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS eventsponserinfo (
  EventSponserID INT NOT NULL AUTO_INCREMENT,
  EventID INT NOT NULL,
  SponserID INT NOT NULL,
  PRIMARY KEY (EventSponserID),
  CONSTRAINT fk_eventsponserinfo_1 FOREIGN KEY (EventID) REFERENCES eventinfo (EventID) ON DELETE CASCADE,
  CONSTRAINT fk_eventsponserinfo_2 FOREIGN KEY (SponserID) REFERENCES sponserinfo (SponserID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS tickettype (
  TicketTypeID INT NOT NULL AUTO_INCREMENT,
  EventID INT NOT NULL,
  TypeName VARCHAR(45) NOT NULL,
  PriceInKIP INT NOT NULL,
  Capacity INT NOT NULL,
  SaleStartYMDT DATETIME NOT NULL,
  SaleEndYMDT DATETIME NOT NULL,
  PRIMARY KEY (TicketTypeID),
  CONSTRAINT fk_tickettype_1 FOREIGN KEY (EventID) REFERENCES eventinfo (EventID) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS ordersinfo (
  OrderID INT NOT NULL AUTO_INCREMENT,
  AccountID INT NOT NULL,
  PaymentTypeID INT NOT NULL,
  PaymentDateYMDT DATETIME,
  ProveOfPayment VARCHAR(255),
  PRIMARY KEY (OrderID),
  CONSTRAINT fk_ordersinfo_1 FOREIGN KEY (AccountID) REFERENCES accountinfo (AccountID),
  CONSTRAINT fk_ordersinfo_2 FOREIGN KEY (PaymentTypeID) REFERENCES paymenttypeinfo (PaymentTypeID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS ticketattendence (
  attendeeID INT NOT NULL AUTO_INCREMENT,
  TicketTypeID INT NOT NULL,
  OrderID INT NOT NULL,
  FirstName VARCHAR(50) NOT NULL,
  LastName VARCHAR(50) NOT NULL,
  PhoneNum VARCHAR(20) NOT NULL,
  Email VARCHAR(255) NOT NULL,
  NationalID VARCHAR(50),
  IsValid TINYINT NOT NULL DEFAULT 1 CHECK (IsValid IN (0, 1)),
  PRIMARY KEY (attendeeID),
  CONSTRAINT fk_ticketattendence_1 FOREIGN KEY (TicketTypeID) REFERENCES tickettype (TicketTypeID),
  CONSTRAINT fk_ticketattendence_2 FOREIGN KEY (OrderID) REFERENCES ordersinfo (OrderID) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS attendeeresponse (
  ResponseID INT NOT NULL AUTO_INCREMENT,
  EventQuestionID INT NOT NULL,
  attendeeID INT NOT NULL,
  attendeeAnswer VARCHAR(255) NOT NULL,
  PRIMARY KEY (ResponseID),
  CONSTRAINT fk_attendeeresponse_1 FOREIGN KEY (EventQuestionID) REFERENCES eventquestioninfo (EventQuestionID) ON DELETE CASCADE,
  CONSTRAINT fk_attendeeresponse_2 FOREIGN KEY (attendeeID) REFERENCES ticketattendence (attendeeID) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS ticketcheckin (
  CheckInID INT NOT NULL AUTO_INCREMENT,
  attendeeID INT NOT NULL,
  EventID INT NOT NULL,
  CheckedInByMemberID INT NOT NULL,
  CheckedInAtYMDT DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (CheckInID),
  UNIQUE KEY uq_attendee_event (attendeeID, EventID),
  CONSTRAINT fk_ticketcheckin_1 FOREIGN KEY (attendeeID) REFERENCES ticketattendence (attendeeID) ON DELETE CASCADE,
  CONSTRAINT fk_ticketcheckin_2 FOREIGN KEY (EventID) REFERENCES eventinfo (EventID) ON DELETE CASCADE,
  CONSTRAINT fk_ticketcheckin_3 FOREIGN KEY (CheckedInByMemberID) REFERENCES organizermember (MemberID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS identityverification (
  VerificationID INT NOT NULL AUTO_INCREMENT,
  AccountID INT NOT NULL,
  VerificationTypeID INT NOT NULL,
  IDNumberEncrypted VARCHAR(255) NOT NULL,
  FullNameOnID VARCHAR(255) NOT NULL,
  DateOfBirth DATE,
  DocumentImageRedPath VARCHAR(255),
  VerificationStatusID INT NOT NULL,
  ReviewedByAccountID INT NOT NULL,
  SubmittedAtYMDT DATETIME,
  ReviewedAtYMDT DATETIME,
  PRIMARY KEY (VerificationID),
  CONSTRAINT fk_identityverification_1 FOREIGN KEY (AccountID) REFERENCES accountinfo (AccountID),
  CONSTRAINT fk_identityverification_2 FOREIGN KEY (VerificationTypeID) REFERENCES verificationtypeinfo (VerificationTypeID),
  CONSTRAINT fk_identityverification_3 FOREIGN KEY (VerificationStatusID) REFERENCES verificationstatusinfo (VerificationStatusID),
  CONSTRAINT fk_identityverification_4 FOREIGN KEY (ReviewedByAccountID) REFERENCES accountinfo (AccountID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS accountcategoryinfo (
  AccountCategoryID INT NOT NULL AUTO_INCREMENT,
  AccountID INT NOT NULL,
  CategoryID INT NOT NULL,
  CreatedAtYMDT DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (AccountCategoryID),
  UNIQUE KEY uq_account_category (AccountID, CategoryID),
  CONSTRAINT fk_accountcategoryinfo_1 FOREIGN KEY (AccountID) REFERENCES accountinfo (AccountID) ON DELETE CASCADE,
  CONSTRAINT fk_accountcategoryinfo_2 FOREIGN KEY (CategoryID) REFERENCES categoryinfo (CategoryID) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS wishlistinfo (
  WishID INT NOT NULL AUTO_INCREMENT,
  AccountID INT NOT NULL,
  EventID INT NOT NULL,
  CreatedAtYMDT DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (WishID),
  UNIQUE KEY uq_account_event (AccountID, EventID),
  CONSTRAINT fk_wishlistinfo_1 FOREIGN KEY (AccountID) REFERENCES accountinfo (AccountID) ON DELETE CASCADE,
  CONSTRAINT fk_wishlistinfo_2 FOREIGN KEY (EventID) REFERENCES eventinfo (EventID) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS followinfo (
  FollowID INT NOT NULL AUTO_INCREMENT,
  AccountID INT NOT NULL,
  EventOrganizerID INT NOT NULL,
  CreatedAtYMDT DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (FollowID),
  UNIQUE KEY uq_account_organizer (AccountID, EventOrganizerID),
  CONSTRAINT fk_followinfo_1 FOREIGN KEY (AccountID) REFERENCES accountinfo (AccountID) ON DELETE CASCADE,
  CONSTRAINT fk_followinfo_2 FOREIGN KEY (EventOrganizerID) REFERENCES eventorganizerinfo (EventOrganizerID) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS eventviewinfo (
  ViewID INT NOT NULL AUTO_INCREMENT,
  AccountID INT NOT NULL,
  EventID INT NOT NULL,
  ViewedAtYMDT DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (ViewID),
  CONSTRAINT fk_eventviewinfo_1 FOREIGN KEY (AccountID) REFERENCES accountinfo (AccountID) ON DELETE CASCADE,
  CONSTRAINT fk_eventviewinfo_2 FOREIGN KEY (EventID) REFERENCES eventinfo (EventID) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS notificationinfo (
  NotificationID INT NOT NULL AUTO_INCREMENT,
  AccountID INT NOT NULL,
  NotificationType VARCHAR(30) NOT NULL DEFAULT 'system',
  Title VARCHAR(255) NOT NULL,
  Body TEXT NOT NULL,
  Link VARCHAR(255),
  IsRead TINYINT NOT NULL DEFAULT 0 CHECK (IsRead IN (0, 1)),
  CreatedAtYMDT DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (NotificationID),
  KEY idx_notification_account_date (AccountID, CreatedAtYMDT),
  CONSTRAINT fk_notificationinfo_1 FOREIGN KEY (AccountID) REFERENCES accountinfo (AccountID) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


INSERT INTO accountstatusinfo (StatusID, StatusType) VALUES
  (1, 'CUSTOMER'), (2, 'ORGANIZER'), (3, 'SUPERADMIN'), (4, 'EMPLOYEE'), (5, 'Ban')
ON DUPLICATE KEY UPDATE StatusType = VALUES(StatusType);
INSERT INTO eventstatusinfo (EventStatusID, StatusName) VALUES
  (1, 'Pending'), (2, 'Approved'), (3, 'Denied'), (4, 'Draft')
ON DUPLICATE KEY UPDATE StatusName = VALUES(StatusName);
INSERT INTO organizerstatusinfo (OrganizerStatusID, StatusName) VALUES
  (1, 'Pending'), (2, 'Approved'), (3, 'Denied')
ON DUPLICATE KEY UPDATE StatusName = VALUES(StatusName);
INSERT INTO eventquestiontype (EventQuestionTypeID, EventQuestionType) VALUES
  (1, 'Text'), (2, 'Checkbox'), (3, 'Radio box'), (4, 'Text save as encrypted'), (5, 'Yes or No')
ON DUPLICATE KEY UPDATE EventQuestionType = VALUES(EventQuestionType);
INSERT INTO eventrole (EventRoleID, RoleName) VALUES
  (1, 'Editor'), (2, 'Viewer2')
ON DUPLICATE KEY UPDATE RoleName = VALUES(RoleName);
INSERT INTO teamrole (TeamRoleID, TeamRoleName) VALUES
  (1, 'Staff / Employee'), (2, 'Volunteer'), (3, 'Page Designer'), (4, 'Org Admin'), (5, 'Org Owner')
ON DUPLICATE KEY UPDATE TeamRoleName = VALUES(TeamRoleName);
INSERT INTO memberstatusinfo (MemberStatusID, StatusName) VALUES
  (1, 'Pending'), (2, 'Active'), (3, 'Declined'), (4, 'Removed')
ON DUPLICATE KEY UPDATE StatusName = VALUES(StatusName);
INSERT INTO paymenttypeinfo (PaymentTypeID, PaymentTypeName) VALUES
  (1, 'BCEL'), (2, 'APB'), (3, 'LDB')
ON DUPLICATE KEY UPDATE PaymentTypeName = VALUES(PaymentTypeName);
INSERT INTO verificationstatusinfo (VerificationStatusID, StatusName) VALUES
  (1, 'Pending'), (2, 'Approved'), (3, 'Denied')
ON DUPLICATE KEY UPDATE StatusName = VALUES(StatusName);
INSERT INTO verificationtypeinfo (VerificationTypeID, IDType) VALUES
  (1, 'Password'), (2, 'Personal Residency Card ID'), (5, 'My Number Card')
ON DUPLICATE KEY UPDATE IDType = VALUES(IDType);
INSERT INTO permissioninfo (PermissionName, PermissionDescription) VALUES
  ('view_events', 'View events list and details'),
  ('create_event', 'Create new events'),
  ('update_event', 'Update existing events'),
  ('delete_event', 'Delete events'),
  ('manage_event_organizer', 'Create/update/delete event organizers'),
  ('manage_event_members', 'Create/update/delete organizer members'),
  ('manage_categories', 'Create/update/delete categories and event-category links'),
  ('manage_event_images', 'Upload/replace/delete event images'),
  ('manage_ticket_types', 'Create/update/delete ticket types'),
  ('manage_event_questions', 'Create/update/delete event questions'),
  ('manage_accounts', 'Create/update/delete accounts'),
  ('manage_orders', 'View/manage orders'),
  ('manage_wishlist', 'Add/remove wishlist items'),
  ('manage_identity_verifications', 'Approve/deny identity verification and grant organizer access')
ON DUPLICATE KEY UPDATE PermissionDescription = VALUES(PermissionDescription);
INSERT IGNORE INTO rolepermissioninfo (StatusID, PermissionID)
SELECT r.StatusID, p.PermissionID
FROM (
  SELECT 1 AS StatusID, 'view_events' AS PermissionName UNION ALL SELECT 1, 'manage_wishlist'
  UNION ALL SELECT 2, 'view_events' UNION ALL SELECT 2, 'create_event' UNION ALL SELECT 2, 'update_event'
  UNION ALL SELECT 2, 'manage_event_organizer' UNION ALL SELECT 2, 'manage_event_members'
  UNION ALL SELECT 2, 'manage_event_images' UNION ALL SELECT 2, 'manage_categories'
  UNION ALL SELECT 2, 'manage_ticket_types' UNION ALL SELECT 2, 'manage_event_questions'
  UNION ALL SELECT 2, 'manage_orders' UNION ALL SELECT 2, 'manage_wishlist'
  UNION ALL SELECT 4, 'manage_identity_verifications'
) AS r
JOIN permissioninfo p ON p.PermissionName = r.PermissionName;
INSERT IGNORE INTO rolepermissioninfo (StatusID, PermissionID)
SELECT 3, PermissionID FROM permissioninfo;
