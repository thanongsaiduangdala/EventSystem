-- Adds the 'Draft' event status used by server-side saved drafts.
INSERT INTO eventstatusinfo (EventStatusID, StatusName) VALUES (4, 'Draft')
ON DUPLICATE KEY UPDATE StatusName = VALUES(StatusName);
