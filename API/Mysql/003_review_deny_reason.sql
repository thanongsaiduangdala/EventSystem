-- Reviewer comment shown to the organizer when an event / organization is
-- denied. Cleared again when the item is approved or resubmitted.
-- (Run once. MySQL has no ADD COLUMN IF NOT EXISTS; if the column is
-- already there you will get "Duplicate column name" and can ignore it.)
ALTER TABLE eventinfo ADD COLUMN DenyReason TEXT NULL;
ALTER TABLE eventorganizerinfo ADD COLUMN DenyReason TEXT NULL;
