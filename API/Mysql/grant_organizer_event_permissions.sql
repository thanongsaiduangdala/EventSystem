-- ---------------------------------------------------------------------------
-- Let ORGANIZER accounts (accountstatusinfo.StatusID = 2) fully set up their
-- own events from the app's event form: photos, categories, ticket types and
-- event questions. (Creating/editing/deleting the event itself and viewing
-- events use create_event / update_event / delete_event / view_events, which
-- the Organizer role already needs for the dashboard to work today.)
--
-- The backend checks these permission names (see auth/dependencies.py ->
-- require_permission). If the Organizer role doesn't have them, the event
-- itself saves but those sections come back with a 403
-- "Permission '<name>' required".
--
-- Safe to run more than once: it only inserts links that don't exist yet.
-- ---------------------------------------------------------------------------

-- 1) See what the Organizer role can do right now (optional):
SELECT p.PermissionName
FROM rolepermissioninfo rp
JOIN permissioninfo p ON p.PermissionID = rp.PermissionID
WHERE rp.StatusID = 2
ORDER BY p.PermissionName;

-- 2) Grant the missing ones:
INSERT INTO rolepermissioninfo (StatusID, PermissionID)
SELECT 2, p.PermissionID
FROM permissioninfo p
WHERE p.PermissionName IN (
        'manage_event_images',
        'manage_categories',
        'manage_ticket_types',
        'manage_event_questions'
      )
  AND NOT EXISTS (
        SELECT 1
        FROM rolepermissioninfo rp
        WHERE rp.StatusID = 2
          AND rp.PermissionID = p.PermissionID
      );

-- 3) Confirm (the four manage_* names above should now be listed):
SELECT p.PermissionName
FROM rolepermissioninfo rp
JOIN permissioninfo p ON p.PermissionID = rp.PermissionID
WHERE rp.StatusID = 2
ORDER BY p.PermissionName;

-- Note: if step 2 inserts 0 rows for a name, that permission row doesn't exist
-- in permissioninfo yet. Create it first, e.g.:
--   INSERT INTO permissioninfo (PermissionName) VALUES ('manage_ticket_types');
-- (add any other required columns your permissioninfo table has), then re-run.
