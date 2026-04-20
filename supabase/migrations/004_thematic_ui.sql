-- Add theme_color_hex to couples table
ALTER TABLE couples ADD COLUMN theme_color_hex VARCHAR(7) NOT NULL DEFAULT '#FFFF6B6B';
