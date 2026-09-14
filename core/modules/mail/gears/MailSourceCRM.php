<?php

namespace Energine\mail\gears;

use Energine\share\gears\DBWorker;
use Energine\mail\gears\MailSourceAbstract;
use Energine\mail\gears\IMailSource;

class MailSourceCRM extends MailSourceAbstract
{
    protected $template_name = 'mail_crm';
    protected $template_item_name = 'mail_crm_item';

    public function getItemsSinceDate(\DateTime $date)
    {

        $items = $this->dbh->select(
            'select c.crm_id as id,
                ct.crm_name as title, ct.crm_text_rtf as description,
                c.crm_date as `date`
            from mail_crm c
            left join mail_crm_translation ct on c.crm_id = ct.crm_id and ct.lang_id = %s
            where c.crm_is_active = 1 and crm_date >= %s
            order by c.crm_date desc LIMIT 100',
            $this->lang_id,
            $date->format('Y-m-d H:i:s')
        );

        $map = E()->getMap();

        array_walk($items, function (&$item) use ($map) {
            // plain text: MailTemplate escapes it for the HTML body
            $item['description'] = html_entity_decode(strip_tags((string)$item['description']), ENT_QUOTES | ENT_HTML5, 'UTF-8');
            $d = new \DateTime($item['date']);
            $item['date'] = $d->format('d.m.Y');
        });

        return $items;

    }
}
