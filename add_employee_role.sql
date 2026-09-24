-- Migration: add the EMPLOYEE role (StatusID 4) and the identity-review
-- permission used by the new Employee Dashboard (SUPERADMIN + EMPLOYEE).

USE reservation_system;

-- StatusID 4 was seeded as "Not in use". Repurpose it as the EMPLOYEE role.
INSERT INTO accountstatusinfo (StatusID, StatusType)
VALUES (4, 'EMPLOYEE')
ON DUPLICATE KEY UPDATE StatusType = 'EMPLOYEE';

-- Permission used by the Employee Dashboard to review identity requests.
INSERT IGNORE INTO permissioninfo (PermissionName, PermissionDescription) VALUES
('manage_identity_verifications', 'Approve/deny identity verification and grant organizer access');

-- Grant to SUPERADMIN (3) and EMPLOYEE (4).
INSERT IGNORE INTO rolepermissioninfo (StatusID, PermissionID)
SELECT 3, p.PermissionID FROM permissioninfo p WHERE p.PermissionName = 'manage_identity_verifications';

INSERT IGNORE INTO rolepermissioninfo (StatusID, PermissionID)
SELECT 4, p.PermissionID FROM permissioninfo p WHERE p.PermissionName = 'manage_identity_verifications';