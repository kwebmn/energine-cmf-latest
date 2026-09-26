<?php
/**
 * @file
 * GoogleSitemap
 *
 * It contains the definition to:
 * @code
class GoogleSitemap;
 * @endcode
 *
 * @author d.pavka
 * @copyright d.pavka@gmail.com
 *
 * @version 1.0.0
 */
namespace Energine\seo\components;

use Energine\share\components\SitemapTree, Energine\share\gears\SimpleBuilder, Energine\share\gears\FieldDescription, Energine\share\gears\DataDescription, Energine\share\gears\TreeBuilder;
use Energine\share\gears\Data;
use Energine\share\gears\SystemException;

/**
 * Component for generation Google Sitemap and Google Sitemap Index.
 *
 * @code
class GoogleSitemap;
 * @endcode
 *
 *
 * @note It should be held in empty layout.
 *
 * @see http://www.sitemaps.org/protocol.php
 * @see http://www.google.com/support/webmasters/bin/answer.py?answer=80472
 */
class GoogleSitemap extends SitemapTree {

    /**
     * @copydoc SitemapTree::__construct
     */
    public function __construct($name, ?array $params = NULL) {
        parent::__construct($name, $params);
        E()->getResponse()->setHeader('Content-Type', 'text/xml; charset=utf-8');
    }

    protected function defineParams() {
        return array_merge(
            parent::defineParams(),
            [
                'index.xslt' => CORE_REL_DIR . '/modules/seo/transformers/google_sitemap_index.xslt',
                'map.xslt' => CORE_REL_DIR . '/modules/seo/transformers/google_sitemap.xslt'
            ]
        );
    }


    /**
     * @copydoc SitemapTree::main
     */
    // Генерирует google sitemap index
    protected function main() {
        E()->getController()->getTransformer()->setFileName($this->getParam('index.xslt'), true);
        $dd = new DataDescription();
        $dd->addFieldDescription(new FieldDescription('path'));
        $this->setDataDescription($dd);
        $d = new Data();
        $sitemaps = [];
        $siteinfo = E()->getSiteManager()->getCurrentSite();
        if (!$siteinfo->isIndexed) throw new SystemException('ERR_404', SystemException::ERR_404);

        $sitePath = $siteinfo->base;
        $fullPath = $this->request->getPath(1, true);
        array_push($sitemaps, ['path' => $sitePath . $fullPath . 'map']);

        $d->load($sitemaps);
        $this->setData($d);
        $this->setBuilder(new SimpleBuilder());
    }

    /**
     * Generate Google Sitemap
     */
    protected function map() {

        E()->getController()->getTransformer()->setFileName($this->getParam('map.xslt'), true);
        $dd = new DataDescription();
        foreach (['Id' => FieldDescription::FIELD_TYPE_INT,
                     'Segment' => FieldDescription::FIELD_TYPE_STRING,
                     'LastMod' => FieldDescription::FIELD_TYPE_DATETIME] as $fieldName => $fieldType) {

            $fd = new FieldDescription($fieldName);

            if ($fieldName == 'Id')
                $fd->setType($fieldType)->setProperty('key', 1);
            else
                $fd->setType($fieldType);

            $dd->addFieldDescription($fd);
        }
        $dd->getFieldDescriptionByName('LastMod')->setProperty('outputFormat', '%Y-%m-%d');
        $this->setDataDescription($dd);
        $d = new Data();
        $this->setData($d);

        $sitemap = E()->getMap();
        $res = $sitemap->getInfo();

        // ключа IsIndexed в описании страницы нет (preparePageInfo его не создаёт) - его чтение роняло
        // карту. Признак индексации - отсутствие NOINDEX в meta robots. $result тоже не был объявлен.
        $result = [];
        foreach ($res as $id => $info) {
            if (!in_array('NOINDEX', (array)($info['MetaRobots'] ?? []), true)) {
                $result [] = [
                    'Id' => $id,
                    'Name' => $info['Name'],
                    'LastMod' => $info['LastMod'],
                    'Segment' => $sitemap->getURLByID($id)
                ];
            }
        }
        $this->getData()->load($result);
        $this->setBuilder(new SimpleBuilder());
    }
}
