# MAYA Quantum 3D Visualization

Interactive 3D visualization of quantum states using Three.js and TypeScript.

## Features

- Real-time 3D Bloch sphere visualization
- Support for multiple qubits
- Interactive controls (rotate, zoom, pan)
- Apply quantum gates (X, H, etc.)
- Visualize state vectors
- Responsive design

## Getting Started

### Prerequisites

- Node.js (v16 or later)
- npm (v8 or later)

### Installation

1. Install dependencies:
   ```bash
   npm install
   ```

2. Start the development server:
   ```bash
   npm run dev
   ```

3. Open your browser to `http://localhost:3000`

## Usage

### Controls

- **Left Click + Drag**: Rotate view
- **Right Click + Drag**: Pan
- **Scroll**: Zoom in/out
- **GUI Controls**: Top-right panel for adding qubits and applying gates

### Available Commands

- `npm run dev`: Start development server
- `npm run build`: Build for production
- `npm run start`: Start production server

## Project Structure

```
src/
  main.ts           # Main application entry point
  components/        # Reusable components
  utils/            # Utility functions
public/
  index.html       # Main HTML template
  assets/           # Static assets (images, models, etc.)
dist/              # Production build output
```

## Development

### Adding New Gates

1. Add the gate logic in `main.ts` in the `applyGate` method
2. Update the GUI controls in `setupGUI`
3. Add any necessary visualization components

### Styling

Styles are defined in `public/index.html` and can be extended as needed.

## License

MIT License - See [LICENSE](LICENSE) for details.

## Acknowledgments

- Three.js for 3D rendering
- dat.GUI for the control panel
- Quantum Computing community for inspiration
