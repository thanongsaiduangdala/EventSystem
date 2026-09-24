-- Profile picture support: run this once against existing databases.
-- Fresh setups get the column via the CREATE TABLE in Mysql/code.sql.
ALTER TABLE accountinfo ADD COLUMN ProfileImagePath VARCHAR(255) NULL AFTER PhoneNum;

-- Event approval flow: run this once against existing databases.
-- 1 = Pending, 2 = Approved, 3 = Denied. Existing events default to Approved.
ALTER TABLE eventinfo ADD COLUMN EventStatusID INT NOT NULL DEFAULT 2 AFTER OnePerPerson;

-- Organizer applications have no reviewer until an admin/employee approves.
ALTER TABLE identityverification MODIFY ReviewedByAccountID INT NULL,
                                MODIFY ReviewedAtYMDT DATETIME NULL;

CREATE TABLE IF NOT EXISTS accountcategoryinfo (
    AccountCategoryID INT AUTO_INCREMENT PRIMARY KEY,
    AccountID INT NOT NULL,
    CategoryID INT NOT NULL,
    CreatedAtYMDT DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_account_category (AccountID, CategoryID),
    FOREIGN KEY (AccountID) REFERENCES accountinfo(AccountID) ON DELETE CASCADE,
    FOREIGN KEY (CategoryID) REFERENCES categoryinfo(CategoryID) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS wishlistinfo (
    WishID INT AUTO_INCREMENT PRIMARY KEY,
    AccountID INT NOT NULL,
    EventID INT NOT NULL,
    CreatedAtYMDT DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_account_event (AccountID, EventID),
    FOREIGN KEY (AccountID) REFERENCES accountinfo(AccountID) ON DELETE CASCADE,
    FOREIGN KEY (EventID) REFERENCES eventinfo(EventID) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS followinfo (
    FollowID INT AUTO_INCREMENT PRIMARY KEY,
    AccountID INT NOT NULL,
    EventOrganizerID INT NOT NULL,
    CreatedAtYMDT DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_account_organizer (AccountID, EventOrganizerID),
    FOREIGN KEY (AccountID) REFERENCES accountinfo(AccountID) ON DELETE CASCADE,
    FOREIGN KEY (EventOrganizerID) REFERENCES eventorganizerinfo(EventOrganizerID) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS eventviewinfo (
    ViewID INT AUTO_INCREMENT PRIMARY KEY,
    AccountID INT NOT NULL,
    EventID INT NOT NULL,
    ViewedAtYMDT DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (AccountID) REFERENCES accountinfo(AccountID) ON DELETE CASCADE,
    FOREIGN KEY (EventID) REFERENCES eventinfo(EventID) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS notificationinfo (
    NotificationID INT AUTO_INCREMENT PRIMARY KEY,
    AccountID INT NOT NULL,
    NotificationType VARCHAR(30) NOT NULL DEFAULT 'system',
    Title VARCHAR(255) NOT NULL,
    Body TEXT NOT NULL,
    IsRead TINYINT(1) NOT NULL DEFAULT 0,
    CreatedAtYMDT DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (AccountID) REFERENCES accountinfo(AccountID) ON DELETE CASCADE
);

-- Team roles used by the organizer "hire employee/volunteer" feature.
-- Idempotent so it can be run against existing databases.
INSERT IGNORE INTO teamrole (TeamRoleID, TeamRoleName) VALUES
(1, 'Employee'),
(2, 'Volunteer');
