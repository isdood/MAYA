declare module 'dat.gui' {
    export class GUI {
        constructor(options?: {
            autoPlace?: boolean;
            width?: number;
            name?: string;
            closed?: boolean;
            closeOnTop?: boolean;
            load?: any;
            preset?: string;
            hideable?: boolean;
        });
        
        add(object: any, property: string, min?: any, max?: any, step?: any): GUI;
        add(object: any, property: string, status: boolean): GUI;
        add(object: any, property: string, items: string[]): GUI;
        add(object: any, property: string, items: number[]): GUI;
        add(object: any, property: string, items: Object): GUI;
        addColor(object: any, property: string): GUI;
        addColor(object: any, property: string, color: string | number): GUI;
        addColor(object: any, property: string, rgba: number[]): GUI;
        
        addFolder(property: string): GUI;
        removeFolder(property: string): void;
        remove(controller: any): void;
        destroy(): void;
        remember(target: any, ...additionalTargets: any[]): void;
        getRoot(): GUI;
        getSaveObject(): any;
        save(): void;
        saveAs(presetName: string): void;
        revert(gui: GUI): void;
        listen(controller: any): void;
        updateDisplay(): void;
        open(): void;
        close(): void;
        show(): void;
        hide(): void;
        name(newName: string): GUI;
        
        domElement: HTMLElement;
        parent: GUI;
        scrollable: boolean;
        autoPlace: boolean;
        preset: string;
        width: number;
        name: string;
        closed: boolean;
        load: any;
        useLocalStorage: boolean;
        
        // Event handlers
        onChange: (value: any) => void;
        onFinishChange: (value: any) => void;
        onOpen: () => void;
        onClose: () => void;
    }
    
    export default GUI;
}
