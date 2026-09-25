-- Migration: add organizer-controlled visibility to events.
--
-- Approval (EventStatusID) answers "is this content OK" and is admin-only.
-- EventVisible answers "should it be listed right now" (sold out, postponed,
-- etc.) and organizers control it directly, independent of approval status.
--
-- The public listing (GET /event/all) now requires EventStatusID = Approved
-- AND EventVisible = 1. Existing events default to visible so nothing
-- currently public disappears when this migration runs.

ALTER TABLE `eventinfo`
  ADD COLUMN `EventVisible` tinyint(1) NOT NULL DEFAULT 1 AFTER `EventStatusID`;
