-- Consolidate all image storage into a single 'media' bucket.
--
-- Folder structure:
--   flyers/{userId}/...          → vendor event flyers
--   clubs/{userId}/...           → vendor club cover images
--   venues/{userId}/...          → vendor venue gallery
--   profiles/users/{userId}/...  → user profile pictures
--   photos/{userId}/...          → user social photos
--   event-photos/{eventId}/...   → user event photos
--   refunds/{userId}/...         → refund proof attachments

-- 1. Create the single media bucket (idempotent)
INSERT INTO storage.buckets (id, name, public)
VALUES ('media', 'media', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 2. Drop any old per-feature bucket policies to avoid conflicts
DROP POLICY IF EXISTS "Vendors can upload event images"      ON storage.objects;
DROP POLICY IF EXISTS "Vendors can update event images"      ON storage.objects;
DROP POLICY IF EXISTS "Vendors can delete event images"      ON storage.objects;
DROP POLICY IF EXISTS "Event images are publicly readable"   ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated uploads"          ON storage.objects;
DROP POLICY IF EXISTS "event-images upload policy"           ON storage.objects;
DROP POLICY IF EXISTS "Media is publicly readable"           ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload media" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own media"     ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own media"     ON storage.objects;

-- 3. Public read — anyone can view images
CREATE POLICY "Media is publicly readable"
ON storage.objects FOR SELECT
USING (bucket_id = 'media');

-- 4. Authenticated users can upload under a path that starts with
--    a known folder and then their own uid. This covers all cases:
--      flyers/{uid}/...
--      clubs/{uid}/...
--      venues/{uid}/...
--      profiles/users/{uid}/...
--      photos/{uid}/...
--      refunds/{uid}/...
--
--    event-photos/{eventId}/... is uploaded by authenticated users
--    and doesn't need uid scoping — covered by the general auth check.
CREATE POLICY "Authenticated users can upload media"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'media'
  AND (
    -- path starts with a folder then uid: flyers/{uid}/..., clubs/{uid}/..., etc.
    (storage.foldername(name))[2] = auth.uid()::text
    -- OR nested uid: profiles/users/{uid}/...
    OR (storage.foldername(name))[3] = auth.uid()::text
    -- OR event-photos (any authenticated user can upload event photos)
    OR (storage.foldername(name))[1] = 'event-photos'
  )
);

-- 5. Users can overwrite/update only their own paths
CREATE POLICY "Users can update their own media"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'media'
  AND (
    (storage.foldername(name))[2] = auth.uid()::text
    OR (storage.foldername(name))[3] = auth.uid()::text
    OR (storage.foldername(name))[1] = 'event-photos'
  )
);

-- 6. Users can delete only their own paths
CREATE POLICY "Users can delete their own media"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'media'
  AND (
    (storage.foldername(name))[2] = auth.uid()::text
    OR (storage.foldername(name))[3] = auth.uid()::text
    OR (storage.foldername(name))[1] = 'event-photos'
  )
);
