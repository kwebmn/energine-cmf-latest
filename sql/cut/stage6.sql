-- Energine Simple, этап 6: мультисайт — одна установка, один сайт (docs/superpowers/specs/2026-09-26-energine-simple-design.md,
-- раздел 6). Переход базы сайта после sql/cut/stage5.sql; каждый раздел можно запускать повторно.
--   mariadb БАЗА < sql/cut/stage6.sql
-- Файлы установки (sql/structure.sql, data.sql, demo.sql) получаются из этого скрипта: tests/tools/regen-sql.sh.

-- 0. До любых изменений: в базе один сайт и одно дерево разделов. Иначе — отказ, база не тронута.
DELIMITER //
BEGIN NOT ATOMIC
    IF (SELECT COUNT(*) FROM `share_sites`) <> 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'stage6.sql: в базе не один сайт. Оставьте один (разделы — под его корень) и запустите снова.';
    END IF;
    IF (SELECT COUNT(*) FROM `share_sitemap` WHERE `smap_pid` IS NULL) <> 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'stage6.sql: в дереве разделов не один корень. Оставьте один и запустите снова.';
    END IF;
END //
DELIMITER ;

-- 1. Адрес сайта — из конфига (site.domain, site.root): записи доменов не читаются и не пишутся.
DELETE FROM `share_domain2site`;
DELETE FROM `share_domains`;
