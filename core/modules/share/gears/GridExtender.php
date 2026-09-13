<?php
/**
 * @file
 * GridExtender
 *
 * Contains the definition to:
 * @code
class GridExtender;
 * @endcode
 *
 * @author    dr.Pavka
 * @copyright Energine 2016
 *
 * @version   1.0.0
 */

namespace Energine\share\gears;

/**
 * Class GridExtender
 * @package Energine\share\gears
 * @todo move into the grid
 */
trait GridExtender {
	protected function createDataDescription(){
		/**
		 * @var $dd DataDescription
		 */
		$dd = parent::createDataDescription();
		if ($fd = $dd->getFieldDescriptionsByType(FieldDescription::FIELD_TYPE_PHONE)){
			// phone format of the country of the default site: share_sites.country_id -> site_country (shop module)
			$countryID = E()->getSiteManager()->getDefaultSite()->countryId;
			$country = ($countryID && E()->getDB()->tableExists('site_country')) ?
				E()->getDB()->getRow('site_country', ['country_tel_format', 'country_tel_code'], ['country_id' => $countryID]) : false;
			if ($country) {
				array_walk($fd, function($fd) use($country) {
					$fd->setProperty('phonePlaceholder', (string)$country['country_tel_format'])
						->setProperty('phoneCode', preg_replace('/\D/', '', (string)$country['country_tel_code']));
				});
			}
		}
		return $dd;
	}
}