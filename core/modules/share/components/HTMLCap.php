<?php
/**
 * @file
 * HTMLCap
 *
 * Contains the definition to:
 * @code
class HTMLCap;
 * @endcode
 *
 * @author dr.Pavka
 * @copyright Energine 2015
 *
 * @version 1.0.0
 */

namespace Energine\share\components;


use Energine\share\gears\EmptyBuilder;

/**
 * Заготовка без логики: ни шаблона, ни данных, ни конфигурации, и нигде не
 * подключена. Задуманная роль - блок произвольного HTML на странице - закрыта
 * компонентом Energine\apps\components\Ads: тот хранит врезку у раздела,
 * наследует её дочерними страницами и правится вкладкой редактора структуры.
 *
 * Оставлен на месте, чтобы не ломать чужие сборки; в новых не использовать.
 *
 * @deprecated
 */
class HTMLCap extends DataSet
{

    protected function main(){
        $this->setBuilder(new EmptyBuilder());
        $this->js = $this->buildJS();
    }

    protected function defineParams()
    {
        return array_merge(
            parent::defineParams(),
            [
                'active' => false,
            ]
        );
    }

}