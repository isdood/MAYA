import * as THREE from 'three';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls';
import { GUI } from 'dat.gui';

class QuantumVisualizer {
    private scene!: THREE.Scene;
    private camera!: THREE.PerspectiveCamera;
    private renderer!: THREE.WebGLRenderer;
    private controls!: OrbitControls;
    private qubitSpheres: THREE.Mesh[] = [];
    private stateVectors: THREE.ArrowHelper[] = [];
    private blochSphere!: THREE.Mesh;
    private gridHelper!: THREE.GridHelper;
    private qubitStates: { alpha: number, beta: number, beta_imag: number }[] = [];

    constructor() {
        this.initScene();
        this.createLights();
        this.createBlochSphere();
        this.createGrid();
        this.setupGUI();
        this.animate();
        this.setupResizeHandler();
    }

    private initScene(): void {
        // Scene setup
        this.scene = new THREE.Scene();
        this.scene.background = new THREE.Color(0x111122);

        // Camera setup
        this.camera = new THREE.PerspectiveCamera(
            75,
            window.innerWidth / window.innerHeight,
            0.1,
            1000
        );
        this.camera.position.z = 5;

        // Renderer setup
        this.renderer = new THREE.WebGLRenderer({ antialias: true });
        this.renderer.setSize(window.innerWidth, window.innerHeight);
        this.renderer.setPixelRatio(window.devicePixelRatio);
        document.getElementById('container')?.appendChild(this.renderer.domElement);

        // Controls
        this.controls = new OrbitControls(this.camera, this.renderer.domElement);
        this.controls.enableDamping = true;
        this.controls.dampingFactor = 0.05;
    }

    private createLights(): void {
        // Ambient light
        const ambientLight = new THREE.AmbientLight(0x404040);
        this.scene.add(ambientLight);

        // Directional light
        const directionalLight = new THREE.DirectionalLight(0xffffff, 0.8);
        directionalLight.position.set(1, 1, 1);
        this.scene.add(directionalLight);
    }

    private createBlochSphere(): void {
        // Create the sphere
        const geometry = new THREE.SphereGeometry(1, 32, 32);
        const material = new THREE.MeshPhongMaterial({
            color: 0x156289,
            emissive: 0x072534,
            side: THREE.DoubleSide,
            wireframe: false,
            transparent: true,
            opacity: 0.3
        });
        
        this.blochSphere = new THREE.Mesh(geometry, material);
        this.scene.add(this.blochSphere);

        // Add axes
        const axesHelper = new THREE.AxesHelper(1.5);
        this.scene.add(axesHelper);

        // Add labels
        this.addAxisLabels();
    }

    private addAxisLabels(): void {
        const loader = new THREE.TextureLoader();
        const createLabel = (text: string, position: THREE.Vector3) => {
            const canvas = document.createElement('canvas');
            const context = canvas.getContext('2d');
            if (!context) return;
            
            canvas.width = 256;
            canvas.height = 128;
            context.fillStyle = 'rgba(0, 0, 0, 0)'; // Transparent background
            context.fillRect(0, 0, canvas.width, canvas.height);
            context.font = 'Bold 80px Arial';
            context.textAlign = 'center';
            context.fillStyle = 'white';
            context.fillText(text, canvas.width / 2, canvas.height / 2 + 25);

            const texture = new THREE.CanvasTexture(canvas);
            const material = new THREE.SpriteMaterial({ map: texture });
            const sprite = new THREE.Sprite(material);
            sprite.position.copy(position);
            sprite.scale.set(0.5, 0.25, 1);
            this.scene.add(sprite);
        };

        createLabel('|0⟩', new THREE.Vector3(0, 1.2, 0));
        createLabel('|1⟩', new THREE.Vector3(0, -1.2, 0));
        createLabel('|+⟩', new THREE.Vector3(1.2, 0, 0));
        createLabel('|-⟩', new THREE.Vector3(-1.2, 0, 0));
        createLabel('|i+⟩', new THREE.Vector3(0, 0, 1.2));
        createLabel('|i-⟩', new THREE.Vector3(0, 0, -1.2));
    }

    private createGrid(): void {
        this.gridHelper = new THREE.GridHelper(10, 20, 0x444444, 0x222222);
        this.scene.add(this.gridHelper);
    }

    public addQubit(): void {
        const qubitState = {
            alpha: 1,  // |0> state
            beta: 0,   // |1> real
            beta_imag: 0 // |1> imaginary
        };
        this.qubitStates.push(qubitState);
        this.updateVisualization();
    }

    public applyGate(gate: string, qubitIndex: number): void {
        if (qubitIndex < 0 || qubitIndex >= this.qubitStates.length) return;
        
        const state = this.qubitStates[qubitIndex];
        
        // Simple gate operations (simplified for demo)
        switch (gate.toLowerCase()) {
            case 'x':
                [state.alpha, state.beta] = [state.beta, state.alpha];
                break;
            case 'h':
                const h = 1 / Math.sqrt(2);
                const newAlpha = h * (state.alpha + state.beta);
                const newBeta = h * (state.alpha - state.beta);
                state.alpha = newAlpha;
                state.beta = newBeta;
                break;
            case 'z':
                state.beta *= -1;
                state.beta_imag *= -1;
                break;
            // Add more gates as needed
        }
        
        this.updateVisualization();
    }

    private updateVisualization(): void {
        // Clear previous visualizations
        this.qubitSpheres.forEach(sphere => this.scene.remove(sphere));
        this.stateVectors.forEach(vector => this.scene.remove(vector));
        this.qubitSpheres = [];
        this.stateVectors = [];

        // Update visualization for each qubit
        this.qubitStates.forEach((state, index) => {
            // Calculate position on Bloch sphere
            const theta = Math.acos(state.alpha);
            const phi = Math.atan2(state.beta_imag, state.beta);
            
            const x = Math.sin(theta) * Math.cos(phi);
            const y = Math.cos(theta);
            const z = Math.sin(theta) * Math.sin(phi);
            
            // Create qubit sphere
            const geometry = new THREE.SphereGeometry(0.1, 16, 16);
            const material = new THREE.MeshPhongMaterial({
                color: 0xff5555,
                emissive: 0x220000,
                shininess: 100
            });
            const sphere = new THREE.Mesh(geometry, material);
            sphere.position.set(x, y, z);
            this.scene.add(sphere);
            this.qubitSpheres.push(sphere);
            
            // Create state vector
            const dir = new THREE.Vector3(x, y, z);
            const origin = new THREE.Vector3(0, 0, 0);
            const arrowHelper = new THREE.ArrowHelper(
                dir.normalize(),
                origin,
                dir.length(),
                this.getColorForIndex(index),
                0.1,
                0.05
            );
            this.scene.add(arrowHelper);
            this.stateVectors.push(arrowHelper);
            
            // Add qubit label
            this.addQubitLabel(index, x, y, z);
        });
    }

    private getColorForIndex(index: number): number {
        const colors = [
            0xff5555, 0x55ff55, 0x5555ff, 0xffff55,
            0xff55ff, 0x55ffff, 0xffaa55, 0xaa55ff
        ];
        return colors[index % colors.length];
    }

    private addQubitLabel(index: number, x: number, y: number, z: number): void {
        const canvas = document.createElement('canvas');
        const context = canvas.getContext('2d');
        if (!context) return;
        
        canvas.width = 128;
        canvas.height = 64;
        context.fillStyle = 'rgba(0, 0, 0, 0)';
        context.fillRect(0, 0, canvas.width, canvas.height);
        context.font = 'Bold 40px Arial';
        context.textAlign = 'center';
        context.fillStyle = 'white';
        context.fillText(`q${index}`, canvas.width / 2, canvas.height / 2 + 15);

        const texture = new THREE.CanvasTexture(canvas);
        const material = new THREE.SpriteMaterial({ map: texture });
        const sprite = new THREE.Sprite(material);
        sprite.position.set(x * 1.3, y * 1.3, z * 1.3);
        sprite.scale.set(0.2, 0.1, 1);
        this.scene.add(sprite);
    }

    private setupGUI(): void {
        const gui = new GUI();
        
        const controls = {
            addQubit: () => {
                this.addQubit();
                this.updateInfo();
            },
            applyHGate: () => {
                this.qubitStates.forEach((_, i) => this.applyGate('h', i));
                this.updateInfo();
            },
            applyXGate: () => {
                this.qubitStates.forEach((_, i) => this.applyGate('x', i));
                this.updateInfo();
            },
            reset: () => {
                this.qubitStates = [];
                this.updateVisualization();
                this.updateInfo();
            }
        };

        gui.add(controls, 'addQubit').name('Add Qubit');
        gui.add(controls, 'applyHGate').name('Apply H Gate');
        gui.add(controls, 'applyXGate').name('Apply X Gate');
        gui.add(controls, 'reset').name('Reset');
    }

    public updateInfo(): void {
        const infoDiv = document.getElementById('info');
        if (!infoDiv) return;
        
        const states = this.qubitStates.map((state, i) => 
            `Qubit ${i}: |ψ> = ${state.alpha.toFixed(2)}|0> + (${state.beta.toFixed(2)} + ${state.beta_imag.toFixed(2)}i)|1>`
        ).join('<br>');
        
        infoDiv.innerHTML = `MAYA Quantum 3D Visualization | ${this.qubitStates.length} Qubits<br>${states}`;
    }

    private setupResizeHandler(): void {
        window.addEventListener('resize', () => {
            this.camera.aspect = window.innerWidth / window.innerHeight;
            this.camera.updateProjectionMatrix();
            this.renderer.setSize(window.innerWidth, window.innerHeight);
        });
    }

    private animate(): void {
        requestAnimationFrame(() => this.animate());
        this.controls.update();
        this.renderer.render(this.scene, this.camera);
    }
}

// Initialize the visualizer when the page loads
window.addEventListener('DOMContentLoaded', () => {
    const visualizer = new QuantumVisualizer();
    // @ts-ignore - Make visualizer available globally for debugging
    window.visualizer = visualizer;
    
    // Add initial qubit
    visualizer.addQubit();
    visualizer.updateInfo();
});
