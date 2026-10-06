<?php
/**
 * Типы полей форм и гридов (надёжность, этап 4): перечисление с теми же значениями, что константы
 * FieldDescription::FIELD_TYPE_* (они остаются псевдонимами, в XSLT — те же строки в атрибуте type).
 * FieldDescription::setType() принимает FieldType или строку и отвергает неизвестный тип.
 */
namespace Energine\share\gears;

enum FieldType: string {
    case STRING = 'string';
    case TEXT = 'text';
    case CODE = 'code';
    case PWD = 'password';
    case EMAIL = 'email';
    case COLOR = 'color';
    case PHONE = 'phone';
    case INT = 'integer';
    case FLOAT = 'float';
    case MONEY = 'money';
    case FILE = 'file';
    case THUMB = 'thumb';
    case BOOL = 'boolean';
    case HTML_BLOCK = 'htmlblock';
    case SELECT = 'select';
    case MULTI = 'multi';
    case VALUE = 'value';
    case DATETIME = 'datetime';
    case DATE = 'date';
    case TIME = 'time';
    case HIDDEN = 'hidden';
    case INFO = 'info';
    case CUSTOM = 'custom';
    case TAB = 'tab';
    case MEDIA = 'media';
}
