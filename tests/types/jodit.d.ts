// Заглушка типов Jodit для tests/jscheck.sh: сам jodit.min.js в проверку не входит (чужой минифицированный код),
// редактор используется через глобальный класс Jodit с небольшим набором полей — остальное any.
declare module 'jodit/jodit.min' {}

declare class Jodit {
    static make(element: HTMLElement | string, options?: Record<string, unknown>): Jodit;
    static defaultOptions: Record<string, unknown>;
    static modules: Record<string, any>;
    static plugins: { add(name: string, plugin: any): void; remove(name: string): void };
    constructor(element: HTMLElement | string, options?: Record<string, unknown>);
    value: string;
    element: HTMLElement;
    container: HTMLElement;
    editor: HTMLElement;
    events: { on(event: string, handler: (...args: any[]) => any): void; off(event: string, handler?: (...args: any[]) => any): void; fire(event: string, ...args: any[]): any };
    e: Jodit['events'];
    s: { insertHTML(html: string): void; focus(): void; current(): Node | false; save(): any; restore(markers?: any): void; select(node: Node, inward?: boolean): void; range: Range };
    selection: Jodit['s'];
    destruct(): void;
    isDestructed: boolean;
    setEditorValue(value?: string): void;
    getEditorValue(): string;
    getElementValue(): string;
    synchronizeValues(): void;
    toggleFullSize(isFull?: boolean): void;
    [key: string]: any;
}
