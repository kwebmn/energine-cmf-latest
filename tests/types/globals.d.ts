// Глобальные имена и свойства, которые скрипты админки вешают на window и document (tests/jscheck.sh, jsconfig.json).
// Свойства, которые код вешает на отдельные элементы (запись строки грида, узел дерева, окно ModalBox), описаны
// @typedef-ами в самих скриптах — здесь только то, что видно из любого файла.

interface Window {
    /** Общий объект Energine страницы (Energine.js: window.Energine = Energine). */
    Energine: typeof import('Energine').Energine;
    /** Очередь окон админки верхнего окна (ModalBox.js: окна внутри окна работают с window.top.ModalBox). */
    ModalBox: any;
}

interface Document {
    /** Единственный на странице репозиторий файлов (FileRepository.js) — его зовут действия окон. */
    FileRepository?: import('FileRepository').FileRepository;
}
