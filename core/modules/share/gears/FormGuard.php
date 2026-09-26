<?php
/**
 * @file
 * FormGuard.
 *
 * It contains the definition to:
 * @code
trait FormGuard;
 * @endcode
 *
 * @copyright Energine 2026
 *
 * @version 1.0.0
 */
namespace Energine\share\gears;

/**
 * Защита гостевых форм от ботов без капчи: поле-ловушка и минимальное время заполнения.
 *
 * Компонент формы при показе ставит атрибут antispam со временем показа (guardForm); form.xslt выводит
 * по нему скрытое от человека поле hp_url и скрытое form_ts. При отправке (checkForm) отказ, если ловушка
 * заполнена, времени показа нет или с него прошло меньше MIN_SECONDS: так отправляют формы боты.
 *
 * @code
trait FormGuard;
 * @endcode
 */
trait FormGuard {
    /**
     * Сколько секунд человеку нужно хотя бы, чтобы заполнить форму.
     * @var int
     */
    protected static $formGuardMinSeconds = 3;

    /**
     * Отметить форму: время показа — атрибут компонента antispam.
     */
    protected function guardForm() {
        $this->setProperty('antispam', time());
    }

    /**
     * Проверить отправку формы.
     *
     * @throws SystemException ERR_FORM_SPAM — ловушка заполнена, нет времени показа или отправлено слишком быстро
     */
    protected function checkForm() {
        $trap = $_POST['hp_url'] ?? '';
        $shown = $_POST['form_ts'] ?? '';
        if ($trap !== '' || !is_string($shown) || !ctype_digit($shown)
            || time() - (int)$shown < static::$formGuardMinSeconds
        ) {
            throw new SystemException('ERR_FORM_SPAM', SystemException::ERR_WARNING);
        }
    }
}
