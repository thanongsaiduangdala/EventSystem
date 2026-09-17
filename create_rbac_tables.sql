-- RBAC: role & permission tables for the reservation_system database
-- Roles are driven by accountstatusinfo.StatusID:
--   1 = CUSTOMER, 2 = ORGANIZER, 3 = SUPERADMIN

USE reservation_system;

CREATE TABLE IF NOT EXISTS permissioninfo (
    PermissionID INT AUTO_INCREMENT PRIMARY KEY,
    PermissionName VARCHAR(100) NOT NULL UNIQUE,
    PermissionDescription VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS rolepermissioninfo (
    RolePermissionID INT AUTO_INCREMENT PRIMARY KEY,
    StatusID INT NOT NULL,
    PermissionID INT NOT NULL,
    UNIQUE KEY uq_status_permission (StatusID, PermissionID),
    CONSTRAINT fk_rp_status FOREIGN KEY (StatusID)
        REFERENCES accountstatusinfo (StatusID) ON DELETE CASCADE,
    CONSTRAINT fk_rp_permission FOREIGN KEY (PermissionID)
        REFERENCES permissioninfo (PermissionID) ON DELETE CASCADE
);

-- Update status labels to the canonical RBAC role names
UPDATE accountstatusinfo SET StatusType = 'CUSTOMER'   WHERE StatusID = 1;
UPDATE accountstatusinfo SET StatusType = 'ORGANIZER'  WHERE StatusID = 2;
UPDATE accountstatusinfo SET StatusType = 'SUPERADMIN' WHERE StatusID = 3;

-- ---------------------------------------------------------------------------
-- Seed permissions (idempotent)
-- ---------------------------------------------------------------------------
INSERT INTO permissioninfo (PermissionName, PermissionDescription) VALUES
('view_events',              'View events list and details'),
('create_event',             'Create new events'),
('update_event',             'Update existing events'),
('delete_event',             'Delete events'),
('manage_event_organizer',   'Create/update/delete event organizers'),
('manage_event_members',     'Create/update/delete organizer members'),
('manage_categories',        'Create/update/delete categories and event-category links'),
('manage_event_images',      'Upload/replace/delete event images'),
('manage_ticket_types',      'Create/update/delete ticket types'),
('manage_event_questions',   'Create/update/delete event questions'),
('manage_accounts',          'Create/update/delete accounts'),
('manage_orders',            'View/manage orders'),
('manage_wishlist',          'Add/remove wishlist items')
ON DUPLICATE KEY UPDATE PermissionDescription = VALUES(PermissionDescription);

-- ---------------------------------------------------------------------------
-- Role -> permission map
-- ---------------------------------------------------------------------------
INSERT IGNORE INTO rolepermissioninfo (StatusID, PermissionID)
SELECT 1, p.PermissionID FROM permissioninfo p WHERE p.PermissionName IN
('view_events', 'manage_wishlist');

INSERT IGNORE INTO rolepermissioninfo (StatusID, PermissionID)
SELECT 2, p.PermissionID FROM permissioninfo p WHERE p.PermissionName IN
('view_events', 'create_event', 'update_event', 'manage_event_organizer',
 'manage_event_members', 'manage_event_images', 'manage_ticket_types',
 'manage_event_questions', 'manage_orders', 'manage_wishlist');

INSERT IGNORE INTO rolepermissioninfo (StatusID, PermissionID)
SELECT 3, p.PermissionID FROM permissioninfo p;