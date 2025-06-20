@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-16 08:41:27",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./cursor-extension/out/extension.js",
    "type": "js",
    "hash": "e43760425962234987b255ddb41386d25024852d"
  }
}
@pattern_meta@

"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.deactivate = exports.activate = exports.MayaExtension = void 0;
const vscode = __importStar(require("vscode"));
const path = __importStar(require("path"));
const fs = __importStar(require("fs"));
class MayaExtension {
    constructor(context) {
        this.isRecording = false;
        this.mayaModule = null;
        this.context = context;
        this.initializeMaya();
    }
    async initializeMaya() {
        try {
            const wasmPath = path.join(this.context.extensionPath, 'maya.wasm');
            const wasmBuffer = await fs.promises.readFile(wasmPath);
            const wasmModule = await WebAssembly.instantiate(wasmBuffer, {
                env: {
                // Add any required environment functions here
                }
            });
            this.mayaModule = wasmModule.instance;
        }
        catch (error) {
            vscode.window.showErrorMessage(`Failed to initialize MAYA: ${error}`);
        }
    }
    activate() {
        // Register commands
        let startRecording = vscode.commands.registerCommand('maya.startRecording', () => {
            this.startRecording();
        });
        let stopRecording = vscode.commands.registerCommand('maya.stopRecording', () => {
            this.stopRecording();
        });
        let analyzePatterns = vscode.commands.registerCommand('maya.analyzePatterns', () => {
            this.analyzePatterns();
        });
        let showPatterns = vscode.commands.registerCommand('maya.showPatterns', () => {
            this.showPatterns();
        });
        // Register event handlers
        vscode.workspace.onDidChangeTextDocument(this.handleTextChange, this);
        vscode.window.onDidChangeActiveTextEditor(this.handleEditorChange, this);
        // Start automatic recording if enabled
        const config = vscode.workspace.getConfiguration('maya');
        if (config.get('recordingEnabled')) {
            this.startRecording();
        }
        // Set up periodic pattern analysis
        const interval = config.get('analysisInterval');
        this.analysisInterval = setInterval(() => {
            if (this.isRecording) {
                this.analyzePatterns();
            }
        }, interval * 1000);
        // Register disposables
        this.context.subscriptions.push(startRecording, stopRecording, analyzePatterns, showPatterns);
    }
    deactivate() {
        if (this.analysisInterval) {
            clearInterval(this.analysisInterval);
        }
    }
    startRecording() {
        this.isRecording = true;
        vscode.window.showInformationMessage('MAYA: Started recording interactions');
    }
    stopRecording() {
        this.isRecording = false;
        vscode.window.showInformationMessage('MAYA: Stopped recording interactions');
    }
    async handleTextChange(event) {
        if (!this.isRecording || !this.mayaModule)
            return;
        const document = event.document;
        const content = document.getText();
        const filePath = document.uri.fsPath;
        // Record the interaction using WebAssembly
        try {
            const recordInteraction = this.mayaModule.exports.record_interaction;
            recordInteraction(filePath, 'code_change', content);
        }
        catch (error) {
            vscode.window.showErrorMessage(`Failed to record interaction: ${error}`);
        }
    }
    async handleEditorChange(editor) {
        if (!this.isRecording || !this.mayaModule || !editor)
            return;
        const document = editor.document;
        const filePath = document.uri.fsPath;
        // Record the navigation using WebAssembly
        try {
            const recordInteraction = this.mayaModule.exports.record_interaction;
            recordInteraction(filePath, 'navigation', '');
        }
        catch (error) {
            vscode.window.showErrorMessage(`Failed to record navigation: ${error}`);
        }
    }
    analyzePatterns() {
        if (!this.mayaModule)
            return;
        try {
            const analyzePatterns = this.mayaModule.exports.analyze_patterns;
            const getPatternCount = this.mayaModule.exports.get_pattern_count;
            const patterns = analyzePatterns();
            const count = getPatternCount(patterns);
            if (count > 0) {
                vscode.window.showInformationMessage(`MAYA: Detected ${count} patterns`);
            }
        }
        catch (error) {
            vscode.window.showErrorMessage(`Failed to analyze patterns: ${error}`);
        }
    }
    showPatterns() {
        if (!this.mayaModule)
            return;
        try {
            const analyzePatterns = this.mayaModule.exports.analyze_patterns;
            const getPatternCount = this.mayaModule.exports.get_pattern_count;
            const getPattern = this.mayaModule.exports.get_pattern;
            const getPatternDescription = this.mayaModule.exports.get_pattern_description;
            const patterns = analyzePatterns();
            const count = getPatternCount(patterns);
            if (count === 0) {
                vscode.window.showInformationMessage('MAYA: No patterns detected');
                return;
            }
            // Create and show a webview panel with the patterns
            const panel = vscode.window.createWebviewPanel('mayaPatterns', 'MAYA Detected Patterns', vscode.ViewColumn.One, {
                enableScripts: true
            });
            let html = '<html><body><h1>Detected Patterns</h1><ul>';
            for (let i = 0; i < count; i++) {
                const pattern = getPattern(patterns, i);
                const description = getPatternDescription(pattern);
                html += `<li>${description}</li>`;
            }
            html += '</ul></body></html>';
            panel.webview.html = html;
        }
        catch (error) {
            vscode.window.showErrorMessage(`Failed to show patterns: ${error}`);
        }
    }
}
exports.MayaExtension = MayaExtension;
function activate(context) {
    const extension = new MayaExtension(context);
    extension.activate();
    return extension;
}
exports.activate = activate;
function deactivate(extension) {
    extension.deactivate();
}
exports.deactivate = deactivate;
//# sourceMappingURL=extension.js.map