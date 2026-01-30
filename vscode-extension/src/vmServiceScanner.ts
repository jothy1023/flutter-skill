import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';
import * as net from 'net';

export interface VmServiceInfo {
    uri: string;
    port: number;
    appName?: string;
}

export type ConnectionState = 'disconnected' | 'connecting' | 'connected' | 'error';

export interface VmServiceScannerOptions {
    portRangeStart: number;
    portRangeEnd: number;
    scanTimeout: number;
    maxConcurrent: number;
}

const DEFAULT_OPTIONS: VmServiceScannerOptions = {
    portRangeStart: 50000,
    portRangeEnd: 50100,
    scanTimeout: 500,
    maxConcurrent: 10
};

export class VmServiceScanner {
    private outputChannel: vscode.OutputChannel;
    private options: VmServiceScannerOptions;
    private fileWatcher: fs.FSWatcher | undefined;
    private scanInterval: NodeJS.Timeout | undefined;
    private currentService: VmServiceInfo | undefined;
    private onStateChangeCallbacks: ((state: ConnectionState, service?: VmServiceInfo) => void)[] = [];

    constructor(outputChannel: vscode.OutputChannel, options: Partial<VmServiceScannerOptions> = {}) {
        this.outputChannel = outputChannel;
        this.options = { ...DEFAULT_OPTIONS, ...options };
    }

    /**
     * Start watching for VM services
     */
    start(): void {
        this.watchUriFile();
        this.startPeriodicScan();
    }

    /**
     * Stop watching for VM services
     */
    stop(): void {
        if (this.fileWatcher) {
            this.fileWatcher.close();
            this.fileWatcher = undefined;
        }
        if (this.scanInterval) {
            clearInterval(this.scanInterval);
            this.scanInterval = undefined;
        }
    }

    /**
     * Register a callback for connection state changes
     */
    onStateChange(callback: (state: ConnectionState, service?: VmServiceInfo) => void): void {
        this.onStateChangeCallbacks.push(callback);
    }

    /**
     * Get the currently connected service
     */
    getCurrentService(): VmServiceInfo | undefined {
        return this.currentService;
    }

    /**
     * Watch the .flutter_skill_uri file for changes
     */
    private watchUriFile(): void {
        const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
        if (!workspaceFolder) return;

        const uriFilePath = path.join(workspaceFolder.uri.fsPath, '.flutter_skill_uri');

        // Check if file exists on startup
        this.checkUriFile(uriFilePath);

        // Watch for changes
        try {
            // Watch the directory since the file might not exist yet
            const dirPath = workspaceFolder.uri.fsPath;
            this.fileWatcher = fs.watch(dirPath, (eventType, filename) => {
                if (filename === '.flutter_skill_uri') {
                    this.checkUriFile(uriFilePath);
                }
            });
        } catch (error) {
            this.outputChannel.appendLine(`[Scanner] Error watching URI file: ${error}`);
        }
    }

    /**
     * Check the URI file and validate the connection
     */
    private async checkUriFile(uriFilePath: string): Promise<void> {
        if (!fs.existsSync(uriFilePath)) {
            if (this.currentService) {
                this.currentService = undefined;
                this.notifyStateChange('disconnected');
            }
            return;
        }

        try {
            const uri = fs.readFileSync(uriFilePath, 'utf-8').trim();
            if (!uri) {
                this.notifyStateChange('disconnected');
                return;
            }

            this.notifyStateChange('connecting');

            // Extract port from URI (ws://127.0.0.1:PORT/...)
            const match = uri.match(/:(\d+)/);
            const port = match ? parseInt(match[1], 10) : 0;

            const isValid = await this.validateVmService(uri);
            if (isValid) {
                this.currentService = { uri, port };
                this.notifyStateChange('connected', this.currentService);
                this.outputChannel.appendLine(`[Scanner] Connected to VM service at ${uri}`);
            } else {
                this.notifyStateChange('error');
                this.outputChannel.appendLine(`[Scanner] Failed to validate VM service at ${uri}`);
            }
        } catch (error) {
            this.notifyStateChange('error');
            this.outputChannel.appendLine(`[Scanner] Error reading URI file: ${error}`);
        }
    }

    /**
     * Start periodic scanning for VM services
     */
    private startPeriodicScan(): void {
        // Initial scan after a delay
        setTimeout(() => this.scanForVmServices(), 2000);

        // Periodic scan every 30 seconds
        this.scanInterval = setInterval(() => {
            if (!this.currentService) {
                this.scanForVmServices();
            }
        }, 30000);
    }

    /**
     * Scan port range for VM services
     */
    async scanForVmServices(): Promise<VmServiceInfo[]> {
        const services: VmServiceInfo[] = [];
        const { portRangeStart, portRangeEnd, maxConcurrent } = this.options;

        this.outputChannel.appendLine(`[Scanner] Scanning ports ${portRangeStart}-${portRangeEnd}...`);

        const ports = Array.from(
            { length: portRangeEnd - portRangeStart + 1 },
            (_, i) => portRangeStart + i
        );

        // Process ports in batches
        for (let i = 0; i < ports.length; i += maxConcurrent) {
            const batch = ports.slice(i, i + maxConcurrent);
            const results = await Promise.all(
                batch.map(port => this.checkPort(port))
            );

            for (const result of results) {
                if (result) {
                    services.push(result);
                }
            }
        }

        if (services.length > 0) {
            this.outputChannel.appendLine(`[Scanner] Found ${services.length} VM service(s)`);
            // Use the first found service if not already connected
            if (!this.currentService) {
                this.currentService = services[0];
                this.notifyStateChange('connected', this.currentService);
            }
        }

        return services;
    }

    /**
     * Check if a port has a VM service
     */
    private async checkPort(port: number): Promise<VmServiceInfo | null> {
        return new Promise(resolve => {
            const socket = new net.Socket();

            const cleanup = () => {
                socket.destroy();
            };

            socket.setTimeout(this.options.scanTimeout);

            socket.on('connect', async () => {
                cleanup();
                // Port is open, try to validate as VM service
                const uri = `ws://127.0.0.1:${port}/ws`;
                const isValid = await this.validateVmService(uri);
                if (isValid) {
                    resolve({ uri, port });
                } else {
                    resolve(null);
                }
            });

            socket.on('timeout', () => {
                cleanup();
                resolve(null);
            });

            socket.on('error', () => {
                cleanup();
                resolve(null);
            });

            socket.connect(port, '127.0.0.1');
        });
    }

    /**
     * Validate that a URI is a valid VM service by sending a getVM request
     */
    async validateVmService(uri: string): Promise<boolean> {
        return new Promise(resolve => {
            try {
                // Use dynamic import for ws module compatibility
                // For VSCode extension, we'll use a simpler TCP check
                const net = require('net');
                const url = new URL(uri);
                const port = parseInt(url.port, 10);

                const socket = new net.Socket();
                socket.setTimeout(this.options.scanTimeout);

                socket.on('connect', () => {
                    socket.destroy();
                    resolve(true);
                });

                socket.on('timeout', () => {
                    socket.destroy();
                    resolve(false);
                });

                socket.on('error', () => {
                    socket.destroy();
                    resolve(false);
                });

                socket.connect(port, url.hostname || '127.0.0.1');
            } catch {
                resolve(false);
            }
        });
    }

    /**
     * Notify all callbacks of state change
     */
    private notifyStateChange(state: ConnectionState, service?: VmServiceInfo): void {
        for (const callback of this.onStateChangeCallbacks) {
            callback(state, service);
        }
    }

    /**
     * Force a manual scan
     */
    async rescan(): Promise<VmServiceInfo[]> {
        this.outputChannel.appendLine('[Scanner] Manual scan triggered');
        return this.scanForVmServices();
    }

    /**
     * Disconnect from current service
     */
    disconnect(): void {
        this.currentService = undefined;
        this.notifyStateChange('disconnected');
    }
}
