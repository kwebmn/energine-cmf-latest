<?php
/**
 * Created by PhpStorm.
 * User: pavka
 * Date: 10/6/15
 * Time: 2:10 PM
 */

namespace Energine\share\components;


use Energine\share\gears\FieldDescription;
use Energine\share\gears\SimplestBuilder;
use Energine\share\gears\SystemException;

class ErrorComponent extends DataSet {
    /**
     * @var \Exception $e
     */
    private $exception;
    /**
     * @var string
     */
    private $title;



    public function setError(\Exception $e) {
        $this->exception = $e;

        switch ($e->getCode()) {
            case SystemException::ERR_404:
                $statusCode = 404;
                break;
            case SystemException::ERR_403:
                $statusCode = 403;
                break;
            default:
                $statusCode = 500;
        }
        // особая причина отказа (например, ERR_CSRF, ответ 422) — без кода: «Ошибка 403» посетителя только запутала бы
        $this->title = E()->Utils->translate('TXT_ERROR') . ($this->specialReason() ? '' : ' ' . $statusCode);
        // ссылка «на главную» в шаблоне error.xslt
        $this->addTranslation('TXT_ERROR_GO_HOME');
        // иначе в <title> остаётся имя страницы, найденной до ошибки (для неизвестного адреса - главной)
        $this->document->setProperty('title', $this->title);
        E()->getResponse()->setStatus($statusCode);

    }

    protected function createBuilder(){
        return new SimplestBuilder();
    }

    protected function createDataDescription() {

        $result = parent::createDataDescription();
        if ($result->isEmpty()) {
            $result->load(
                [
                    'title' => [
                        'type' => FieldDescription::FIELD_TYPE_STRING
                    ],
                    'message' => [
                        'type' => FieldDescription::FIELD_TYPE_STRING
                    ],
                    "hint" =>[
                        'type' => FieldDescription::FIELD_TYPE_TEXT
                    ]
                ]
            );
        }
        return $result;
    }

    protected function loadData(){

        switch ($this->exception->getCode()) {
            case SystemException::ERR_404:
                $message = E()->Utils->translate("TXT_ERROR_404");
                break;
            case SystemException::ERR_403:
                // особая причина отказа (например, ERR_CSRF) показывается своим текстом, обычный 403 — общим
                $message = $this->specialReason() ? $this->exception->getMessage() : E()->Utils->translate("TXT_ERROR_403");
                break;
            default:
                $message = $this->exception->getMessage();
        }

        // «проверьте адрес» — не о форме, отклонённой по токену: там текст причины уже говорит, что делать
        $txt_error_hint = $this->specialReason() ? ''
            : str_replace('%site_name%', E()->getSiteManager()->getCurrentSite()->name, E()->Utils->translate('TXT_ERROR_HINT'));
        return [
            [
                'title'=>$this->title,
                'message'=>$message,
                'hint'=>$txt_error_hint
            ]
        ];
    }

    /**
     * Отказ 403 с особой причиной (текст исключения — не общий ERR_403), например ERR_CSRF.
     *
     * @return bool
     */
    private function specialReason() {
        return $this->exception->getCode() == SystemException::ERR_403
            && $this->exception->getMessage() !== E()->Utils->translate('ERR_403');
    }

}