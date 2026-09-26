<?php

/**
 * Конфигурация проекта на базе системы управления сайтами Energine
 *
 * @copyright 2013 Energine
 */
return array(

    // название проекта
    'project' => 'Energine 2.12.85.06',

    // путь к директории setup; ядро лежит в том же репозитории, что и проект
    'setup_dir' => ($energine_release = ROOT_DIR) . '/setup',

    // список подключенных модулей ядра в конкретном проекте
    // ключи массива - названия модулей, значения - абсолютные пути к месторасположению
    'modules' => array(
        'share'     => $energine_release . '/core/modules/share',
        'user'      => $energine_release . '/core/modules/user',
        'apps'      => $energine_release . '/core/modules/apps',
        'seo'       => $energine_release . '/core/modules/seo',
    ),

    // настройки подключения к mysql
    'database' => array(
        'host' => 'DB HOST NAME',
        'port' => '3306',
        'db' => 'DB NAME',
        'username' => 'DB LOGIN',
        'password' => 'DB PASSWORD'
    ),

    // настройки сайта
    'site' => array(
        // имя домена
        'domain' => 'PROJECT DOMAIN NAME',
        // корень проекта
        'root' => '/',
        // отладочный режим: 1 - включено, 0 - выключено
        'debug' => 1,
        // делать ли замеры времени рендеринга страниц и выводить их в header X-Timer
        'useTimer' => 1,
        // выводить для отладки сразу в XML
        'asXML' => 0,
        // использовать Tidy для очистки кода текстового блока от лишних тегов (если модяль Tidy не подключен  - работать не будет )
        'aggressive_cleanup' => 1,
        // перечень глобальных переменных, которые будут доступны в XML документе на всех страницах
        /*
        'vars' => array(
            'SOME_GLOBAL_XML_VARIABLE' => 'some constant value',
            'ANOTHER_GLOBAL_XML_VARIABLE' => 'another value',
        ),
        */
        // журнал действий в админке: пишет share_action_log, страница /admin/action-log/
        'action_log' => 'Energine\\share\\components\\ActionLog',
        /*'js-lib' => [
            'jquery' => 'https://ajax.googleapis.com/ajax/libs/jquery/2.1.4/jquery.min.js',
            'mootools' => /*$staticURL*//*'scripts/mootools.min.js'
        ]*/
    ),
    // настройки документа
    'document' => array(
        // основная точка входа в xslt преобразователь
        'transformer' => 'main.xslt',
        // насткойка кеширования xslt (при использовании XSLTCache)
        'xslcache' => 0,
    ),

    // перечень дополнительнх полей с превьюшками в виде отдельной вкладки в файловом менеджере
    'thumbnails' => array(
        'auxmiddle' => array(
            'width' => 190,
            'height' => 132,
        ),
        'middle' => array(
            'width' => 184,
            'height' => 138,
        ),
        'anchormiddle' => array(
            'width' => 190,
            'height' => 192,
        ),
        'anchorxsmall' => array(
            'width' => 48,
            'height' => 48,
        ),
        'small' => array(
            'width' => 140,
            'height' => 107,
        ),
        'xsmall' => array(
            'width' => 75,
            'height' => 56,
        ),
        'xxsmall' => array(
            'width' => 60,
            'height' => 45,
        ),
        'big' => array(
            'width' => 650,
            'height' => 367,
        ),
    ),
    // натройка сессий
    'session' => array(
        'timeout' => 6000,
        'lifespan' => 108000,
    ),

    // настройка почтовых уведомлений
    'mail' => array(
        // адрес отправителя почтовой корреспонденции
        'from' => 'noreply@energine.org',
        // отправка через SMTP-сервер; без host (или без блока) письма уходят через mail()
        /*
        'smtp' => array(
            'host' => 'smtp.example.org',
            'port' => 587,
            // tls (или starttls) — STARTTLS (порт 587 или 25), ssl — TLS сразу (порт 465), '' — без шифрования;
            // другое значение — письмо не уходит; без шифрования пароль AUTH идёт открытым текстом
            'encryption' => 'tls',
            'username' => 'noreply@example.org',
            'password' => 'SMTP PASSWORD',
            // свой центр сертификации, если сертификат сервера выпущен не общедоступным
            // 'cafile' => '/path/to/ca.pem',
            'timeout' => 15,
        ),
        */
    ),

    // настройки файловых репозитариев
    'repositories' => array(
        // маппинг типов репозитариев (share_uploads.upl_mime_type) с реализациями интерфейса IFileRepository
        'mapping' => array(
            'repo/local' => 'FileRepositoryLocal',
        ),
        // папка по-умолчанию для быстрой загрузки файлов
        'quick_upload_path' => 'uploads/public',
    ),

    // настройка SEO модуля
    'seo' => array(
        'sitemapSegment' => 'google-sitemap',
        'sitemapTemplate' => 'google_sitemap'
    ),


);

