# Energine Simple

Форк [Energine](https://github.com/energine-cmf/energine) для сайтов-визиток. В нём есть
текстовые страницы, права, многоязычность, регистрация и личный кабинет, обратная связь,
галерея вложений и новости, и больше ничего.

Сейчас **этап 5а**: вырезаны модули shop, blog, comments, calendar, forms, ads и рассылки,
из apps остались новости и обратная связь, из share ушли теги, виджеты и редактор блоков,
нелокальные хранилища, водяные знаки, видео и Flash, Lookup и select2. Меню сайта строится
по флагу страницы. Визуальный редактор — Jodit (MIT), загрузка файлов — `fetch`. Остаются
модули share, user, apps и seo. Дальше — SMTP, тема, установщик (этап 5), мультисайт (этап 6).

Безопасность (этап 5а):
- каждый POST сайта и админки несёт токен посетителя (`Csrf`), форма с чужого сайта
  отклоняется кодом 422; удаление, порядок, включение и очистка выполняются только POST-ом —
  ссылка с чужого сайта ничего не меняет;
- после 5 неудачных входов на один логин с одного IP или 20 с одного IP вход с этого IP
  закрыт на 15 минут (владелец со своего IP входит); заблокированный пользователь не входит;
- пароль восстанавливается по одноразовой ссылке со сроком в час, в базе хранится только
  хэш токена, ответ на запрос не выдаёт, зарегистрирован ли адрес;
- регистрация и обратная связь отклоняют ботов: поле-ловушка и минимальное время заполнения;
- гриды админки, дерево страниц и формы просмотра выводят данные текстом, разметка из них
  не исполняется;
- регистрация и профиль сохраняют только поля своей формы; пароль в профиле меняется только
  с верным текущим паролем;
- cookie — SameSite=Lax, на HTTPS — Secure, сессия и токен — HttpOnly;
- возврат после входа — только на свой сайт.

- Спецификация: `docs/superpowers/specs/2026-09-26-energine-simple-design.md`
- Установка: `docs/INSTALL.md`
- Тесты: `tests/README.md`

---

Исходный README Energine:

energine - mod
========

Energine is a content management framework which allows to support web-applications/websites of any level of complexity.
Energine is component oriented system based on MVC pattern where all internal data is stored in XML format and View layer is implemented through XSLT transformations .

Main features of Energine are:

* Multi-language support. Energine supports unbounded quantity of languages with ability to translate not only content of a site, but buttons, emails, captions too.
* User's access delimitation. User's access control system allows to edit user's rights to access and edit different parts of a website.
* Visual text editor. A built in WYSIWYG (what you see is what you get) editor is a handy tool to edit web site's content and preview it.
* Files. Common file storage allows to use one method to work with files in forms and with a help of text editor.
* Structure site management. Web site's structure represented as a tree. User can add, edit and delete it's nodes to modify parts of a site.
* Shop module. Additional module which allows to create and use eShop.


