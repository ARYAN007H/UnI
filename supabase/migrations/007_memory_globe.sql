-- Migration 007: Add location coordinates to messages for the 3D Memory Globe

ALTER TABLE public.messages
ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
