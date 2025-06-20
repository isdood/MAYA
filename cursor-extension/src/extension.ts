@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-16 08:36:04",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./cursor-extension/src/extension.ts",
    "type": "ts",
    "hash": "cfa17216f2e4547fa973a10aa83c3ee21379fa63"
  }
}
@pattern_meta@

import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs';

export class MayaExtension {
    private context: vscode.ExtensionContext;
    private isRecording: boolean = false;
    private analysisInterval: NodeJS.Timeout | undefined;
    private mayaModule: WebAssembly.Instance | null = null;

    constructor(context: vscode.ExtensionContext) {
        this.context = context;
        this.initializeMaya();
    }

    private async initializeMaya() {
        try {
            const wasmPath = path.join(this.context.extensionPath, 'maya.wasm');
            const wasmBuffer = await fs.promises.readFile(wasmPath);
            const wasmModule = await WebAssembly.instantiate(wasmBuffer, {
                env: {
                    // Add any required environment functions here
                }
            });
            this.mayaModule = wasmModule.instance;
        } catch (error) {
            vscode.window.showErrorMessage(`Failed to initialize MAYA: ${error}`);
        }
    }

    public activate() {
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
        const interval = config.get('analysisInterval') as number;
        this.analysisInterval = setInterval(() => {
            if (this.isRecording) {
                this.analyzePatterns();
            }
        }, interval * 1000);

        // Register disposables
        this.context.subscriptions.push(
            startRecording,
            stopRecording,
            analyzePatterns,
            showPatterns
        );
    }

    public deactivate() {
        if (this.analysisInterval) {
            clearInterval(this.analysisInterval);
        }
    }

    private startRecording() {
        this.isRecording = true;
        vscode.window.showInformationMessage('MAYA: Started recording interactions');
    }

    private stopRecording() {
        this.isRecording = false;
        vscode.window.showInformationMessage('MAYA: Stopped recording interactions');
    }

    private async handleTextChange(event: vscode.TextDocumentChangeEvent) {
        if (!this.isRecording || !this.mayaModule) return;

        const document = event.document;
        const content = document.getText();
        const filePath = document.uri.fsPath;

        // Record the interaction using WebAssembly
        try {
            const recordInteraction = this.mayaModule.exports.record_interaction as Function;
            recordInteraction(filePath, 'code_change', content);
        } catch (error) {
            vscode.window.showErrorMessage(`Failed to record interaction: ${error}`);
        }
    }

    private async handleEditorChange(editor: vscode.TextEditor | undefined) {
        if (!this.isRecording || !this.mayaModule || !editor) return;

        const document = editor.document;
        const filePath = document.uri.fsPath;

        // Record the navigation using WebAssembly
        try {
            const recordInteraction = this.mayaModule.exports.record_interaction as Function;
            recordInteraction(filePath, 'navigation', '');
        } catch (error) {
            vscode.window.showErrorMessage(`Failed to record navigation: ${error}`);
        }
    }

    private analyzePatterns() {
        if (!this.mayaModule) return;

        try {
            const analyzePatterns = this.mayaModule.exports.analyze_patterns as Function;
            const getPatternCount = this.mayaModule.exports.get_pattern_count as Function;
            const patterns = analyzePatterns();
            const count = getPatternCount(patterns);

            if (count > 0) {
                vscode.window.showInformationMessage(`MAYA: Detected ${count} patterns`);
            }
        } catch (error) {
            vscode.window.showErrorMessage(`Failed to analyze patterns: ${error}`);
        }
    }

    private showPatterns() {
        if (!this.mayaModule) return;

        try {
            const analyzePatterns = this.mayaModule.exports.analyze_patterns as Function;
            const getPatternCount = this.mayaModule.exports.get_pattern_count as Function;
            const getPattern = this.mayaModule.exports.get_pattern as Function;
            const getPatternDescription = this.mayaModule.exports.get_pattern_description as Function;

            const patterns = analyzePatterns();
            const count = getPatternCount(patterns);

            if (count === 0) {
                vscode.window.showInformationMessage('MAYA: No patterns detected');
                return;
            }

            // Create and show a webview panel with the patterns
            const panel = vscode.window.createWebviewPanel(
                'mayaPatterns',
                'MAYA Detected Patterns',
                vscode.ViewColumn.One,
                {
                    enableScripts: true
                }
            );

            let html = '<html><body><h1>Detected Patterns</h1><ul>';
            for (let i = 0; i < count; i++) {
                const pattern = getPattern(patterns, i);
                const description = getPatternDescription(pattern);
                html += `<li>${description}</li>`;
            }
            html += '</ul></body></html>';

            panel.webview.html = html;
        } catch (error) {
            vscode.window.showErrorMessage(`Failed to show patterns: ${error}`);
        }
    }
}

export function activate(context: vscode.ExtensionContext) {
    const extension = new MayaExtension(context);
    extension.activate();
    return extension;
}

export function deactivate(extension: MayaExtension) {
    extension.deactivate();
} 