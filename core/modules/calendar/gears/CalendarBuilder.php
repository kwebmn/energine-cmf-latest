<?php 
/**
 * @file
 * CalendarBuilder
 *
 * It contains the definition to:
 * @code
class CalendarBuilder;
@endcode
 *
 * @author d.pavka
 * @copyright d.pavka@gmail.com
 *
 * @version 1.0.0
 */
namespace Energine\calendar\gears;
use Energine\share\gears\Builder, Energine\share\gears\FieldDescription;
/**
 * Calendar builder.
 *
 * @code
class CalendarBuilder;
@endcode
 */
class CalendarBuilder extends Builder {

    /**
     * @copydoc Builder::createField
     */
    protected function createField($fieldName, FieldDescription $fieldInfo, $fieldValue = false, $fieldProperties = false) {
        $result = $this->document->createElement('field');
        $result->setAttribute('name', $fieldName);

        foreach ($fieldInfo as $propName => $propValue) {
            if (!in_array($propName, array('pattern', 'message', 'sort', 'outputFormat', 'tabName')) && is_scalar($propValue)) {
                $result->setAttribute($propName, (string)$propValue);
            }
        }

        if ($fieldProperties) {
            foreach ($fieldProperties as $propName => $propValue) {
                if (is_scalar($propValue)) {
                    $result->setAttribute($propName, (string)$propValue);
                }
            }
        }

        // a day of the calendar: its number
        if ($fieldValue instanceof CalendarItem) {
            $result->nodeValue = $fieldValue->getTitle();
        } elseif (!empty($fieldValue)) {
            $result->nodeValue = $fieldValue;
        }

        return $result;
    }
}