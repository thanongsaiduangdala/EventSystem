-- Migration: team member dashboard + role-based access.
--
-- Goal: let people invited into an organizer team open a "Team Member
-- Dashboard" (button in the app settings) whose capabilities depend on their
-- team role:
--
--   TeamRoleID  1 = Staff / Employee
--   TeamRoleID  2 = Volunteer
--   TeamRoleID  3 = Page Designer
--   TeamRoleID  4 = Org Admin
--   TeamRoleID  5 = Org Owner
--
-- Changes:
--   1. Reseed teamrole to exactly the 5 supported roles (old "Developer" /
--      "Manager" rows are relabelled to the new canonical roles).
--   2. Every organization creator becomes an explicit Org Owner member, so the
--      "one owner per org" rule is enforced with a normal membership row.
--   3. ticketcheckin records who checked in which attendee at which event
--      (one attendee can be checked in exactly once per event).
--   4. ticketattendence gains IsValid so Staff/Admins can decline/revoke a
--      ticket at the door (checking in a revoked ticket is blocked).

USE reservation_system;

-- ---------------------------------------------------------------------------
-- 1. Canonical team roles (idempotent)
-- ---------------------------------------------------------------------------
INSERT INTO teamrole (TeamRoleID, TeamRoleName) VALUES
(1, 'Staff / Employee'),
(2, 'Volunteer'),
(3, 'Page Designer'),
(4, 'Org Admin'),
(5, 'Org Owner')
ON DUPLICATE KEY UPDATE TeamRoleName = VALUES(TeamRoleName);

-- ---------------------------------------------------------------------------
-- 2. Backfill: every organization gets its creator as an Org Owner member.
--    Only added when the creator isn't already part of that org, so an
--    existing team is never disturbed.
-- ---------------------------------------------------------------------------
INSERT IGNORE INTO organizermember
    (AccountID, EventOrganizerID, TeamRoleID, MemberStatusID)
SELECT eo.CreatedByAccountID, eo.EventOrganizerID, 5, 2
FROM eventorganizerinfo eo
WHERE NOT EXISTS (
    SELECT 1
    FROM organizermember om
    WHERE om.EventOrganizerID = eo.EventOrganizerID
      AND om.AccountID = eo.CreatedByAccountID
);

-- ---------------------------------------------------------------------------
-- 3. Check-in records
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ticketcheckin (
    CheckInID INT AUTO_INCREMENT PRIMARY KEY,
    attendeeID INT NOT NULL,
    EventID INT NOT NULL,
    CheckedInByMemberID INT NOT NULL,
    CheckedInAtYMDT DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_attendee_event (attendeeID, EventID),
    KEY idx_checkin_event (EventID),
    KEY idx_checkin_member (CheckedInByMemberID),
    CONSTRAINT fk_checkin_attendee FOREIGN KEY (attendeeID)
        REFERENCES ticketattendence (attendeeID) ON DELETE CASCADE,
    CONSTRAINT fk_checkin_event FOREIGN KEY (EventID)
        REFERENCES eventinfo (EventID) ON DELETE CASCADE,
    CONSTRAINT fk_checkin_member FOREIGN KEY (CheckedInByMemberID)
        REFERENCES organizermember (MemberID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ---------------------------------------------------------------------------
-- 4. Ticket revocation flag (Staff/Admins can refuse entry)
-- ---------------------------------------------------------------------------
ALTER TABLE ticketattendence
    ADD COLUMN IsValid TINYINT(1) NOT NULL DEFAULT 1 AFTER NationalID;