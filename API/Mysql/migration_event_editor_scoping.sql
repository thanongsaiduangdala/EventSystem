-- Migration: event-scoped content editing for Page Designers.
--
-- ensure_event_editor (API/auth/team_access.py) now requires a Page Designer
-- to be assigned to the event via `eventstaff` before editing its content,
-- matching the event-scoping the door roles (Volunteer / Staff) already had.
-- Org Admin and Org Owner remain un-scoped.
--
-- This backfills `eventstaff` rows (EventRoleID 1 = "Editor") for every
-- existing active Page Designer so they keep editing the events of their own
-- organization after the switch. Designers invited in the future are NOT
-- auto-assigned here: they must be assigned explicitly, which is the point of
-- event scoping.

USE reservation_system;

INSERT IGNORE INTO eventstaff (EventID, MemberID, EventRoleID, AssignedAtYMDT)
SELECT e.EventID, om.MemberID, 1, CURRENT_TIMESTAMP
FROM organizermember om
JOIN eventinfo e ON e.EventOrganizerID = om.EventOrganizerID
WHERE om.TeamRoleID = 3
  AND om.MemberStatusID = 2
  AND NOT EXISTS (
      SELECT 1
      FROM eventstaff es
      WHERE es.EventID = e.EventID
        AND es.MemberID = om.MemberID
  );