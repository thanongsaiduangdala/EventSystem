-- Migration: employee/volunteer invite flow for organizer teams.
--
-- Changes:
--   1. organizermember gains a MemberStatusID so an invite is tracked as
--      Pending -> Active, Declined or Removed instead of being an implicit
--      "always active" row.
--   2. A small memberstatusinfo reference table backs those states.
--   3. notificationinfo gains a Link column so a notification can deep-link
--      into a screen (e.g. "org_invite:<MemberID>" opens the join page).

USE reservation_system;

-- Backfill: every row that existed before this migration is already an
-- active team member, so existing rows get MemberStatusID = 2 (Active).
-- New rows are always inserted with an explicit status.
ALTER TABLE organizermember
    ADD COLUMN MemberStatusID INT NOT NULL DEFAULT 2 AFTER TeamRoleID;

CREATE TABLE IF NOT EXISTS memberstatusinfo (
    MemberStatusID INT NOT NULL PRIMARY KEY,
    StatusName VARCHAR(30) NOT NULL
);

INSERT INTO memberstatusinfo (MemberStatusID, StatusName) VALUES
(1, 'Pending'),
(2, 'Active'),
(3, 'Declined'),
(4, 'Removed')
ON DUPLICATE KEY UPDATE StatusName = VALUES(StatusName);

ALTER TABLE notificationinfo
    ADD COLUMN Link VARCHAR(255) NULL AFTER Body;