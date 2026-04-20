-- Add is_vanilla_mode to couples table
ALTER TABLE couples ADD COLUMN is_vanilla_mode BOOLEAN NOT NULL DEFAULT FALSE;
