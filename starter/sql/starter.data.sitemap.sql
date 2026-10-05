-- The Google sitemap page (/google-sitemap/) of the default site, for the empty-site install.
-- The demo content creates the same page; both statements are idempotent.
SET @root := (SELECT smap_id FROM `share_sitemap` WHERE `smap_pid` IS NULL LIMIT 1);
SET @site := (SELECT site_id FROM `share_sites` WHERE `site_is_default` = 1 LIMIT 1);

-- Google sitemap
INSERT INTO `share_sitemap` (`site_id`, `smap_layout`, `smap_content`, `smap_pid`, `smap_segment`, `smap_order_num`)
  SELECT @site, 'default.layout.xml', 'google_sitemap.content.xml', @root, 'google-sitemap',
         COALESCE((SELECT MAX(s.`smap_order_num`) FROM `share_sitemap` s WHERE s.`smap_pid` = @root), 0) + 1
    FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `share_sitemap` x WHERE x.`smap_pid` = @root AND x.`smap_segment` = 'google-sitemap');
SET @p_google_sitemap := (SELECT smap_id FROM `share_sitemap` WHERE `smap_pid` = @root AND `smap_segment` = 'google-sitemap');
INSERT INTO `share_sitemap_translation` (`smap_id`, `lang_id`, `smap_name`, `smap_is_disabled`)
  SELECT @p_google_sitemap, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Google sitemap', 'Google sitemap'), 0
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `smap_name` = VALUES(`smap_name`);
INSERT IGNORE INTO `share_access_level` (`smap_id`, `group_id`, `right_id`)
  SELECT @p_google_sitemap, g.`group_id`, IF(g.`group_id` = 1, 3, 1) FROM `user_groups` g;

