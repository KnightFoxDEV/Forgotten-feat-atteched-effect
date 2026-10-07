ALTER TABLE `players`
  ADD COLUMN `lookwing` smallint UNSIGNED NOT NULL DEFAULT '0',
  ADD COLUMN `lookaura` smallint UNSIGNED NOT NULL DEFAULT '0',
  ADD COLUMN `lookshader` smallint UNSIGNED NOT NULL DEFAULT '0',
  ADD COLUMN `currenteffect` smallint UNSIGNED NOT NULL DEFAULT '0';
