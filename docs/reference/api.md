@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-18 13:51:27",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./docs/reference/api.md",
    "type": "md",
    "hash": "3eadb4694fdfe1a29dde8593ce01c8410085962d"
  }
}
@pattern_meta@

# MAYA API Reference

This document provides a comprehensive reference for MAYA's programming interfaces.

## Storage API

### SledStore

```rust
/// Opens or creates a new Sled database at the specified path
pub fn open<P: AsRef<Path>>(path: P) -> Result<Self>

/// Gets a value by key, deserializing it into the requested type
pub fn get<T: DeserializeOwned>(&self, key: &[u8]) -> Result<Option<T>>

/// Stores a value, serializing it to bytes
pub fn put<T: Serialize>(&self, key: &[u8], value: &T) -> Result<()>

/// Deletes a key-value pair
pub fn delete(&self, key: &[u8]) -> Result<()>

/// Creates a new write batch
pub fn batch(&self) -> SledWriteBatch

/// Iterates over key-value pairs with the given prefix
pub fn iter_prefix(&self, prefix: &[u8]) -> impl Iterator<Item = (Vec<u8>, Vec<u8>)>
```

### SledWriteBatch

```rust
/// Adds a put operation to the batch
pub fn put_serialized(&mut self, key: &[u8], value: &[u8]) -> Result<()>

/// Adds a delete operation to the batch
pub fn delete(&mut self, key: &[u8]) -> Result<()>
/// Commits all operations in the batch
pub fn commit(self) -> Result<()>
```

## Knowledge Graph API

### Node Operations

```rust
/// Creates a new node with the given label
pub fn create_node(&self, label: &str) -> Result<Node>

/// Retrieves a node by ID
pub fn get_node(&self, id: Uuid) -> Result<Option<Node>>
/// Updates an existing node
pub fn update_node(&self, node: &Node) -> Result<()>
/// Deletes a node and its relationships
pub fn delete_node(&self, id: Uuid) -> Result<()>
```

### Edge Operations

```rust
/// Creates a relationship between two nodes
pub fn create_edge(
    &self,
    label: &str,
    from: Uuid,
    to: Uuid,
    properties: HashMap<String, PropertyValue>,
) -> Result<Edge>

/// Retrieves an edge by ID
pub fn get_edge(&self, id: Uuid) -> Result<Option<Edge>>
/// Updates an existing edge
pub fn update_edge(&self, edge: &Edge) -> Result<()>
/// Deletes an edge
pub fn delete_edge(&self, id: Uuid) -> Result<()>
```

### Query API

```rust
/// Creates a new query builder
pub fn query(&self) -> QueryBuilder

/// Example usage:
/// ```
/// let results = graph.query()
///     .with_label("Person")
///     .with_property("age", PropertyValue::Number(30.into()))
///     .limit(10)
///     .execute()?;
/// ```
```

## Performance Considerations

### Batch Operations

For better performance, use batch operations when making multiple writes:

```rust
let batch = graph.storage.batch();
for item in items {
    batch.put_serialized(&item.key, &serialize(&item.value)?)?;
}
batch.commit()?;
```

### Indexing

Create indexes for frequently queried properties:

```rust
// Create an index on the 'email' property of 'User' nodes
graph.create_index("User", "email")?;
```

## Error Handling

All API methods return `Result<T, KnowledgeGraphError>` where `KnowledgeGraphError` can be one of:

- `StorageError`: Underlying storage issues
- `SerializationError`: Data serialization/deserialization errors
- `NotFound`: Requested resource doesn't exist
- `ValidationError`: Invalid input data
- `TransactionError`: Transaction-related errors

## Configuration

Storage behavior can be configured via `config/storage.toml`:

```toml
[storage]
engine = "sled"
path = "/var/lib/maya/knowledge_graph"

[storage.sled]
cache_capacity = 1073741824  # 1GB
compression = true
use_compression = ["lz4"]
```

## Versioning

API versioning follows Semantic Versioning (SemVer). Breaking changes will result in a major version bump.

## Deprecation Policy

- Deprecated APIs will be marked with `#[deprecated]`
- Deprecated APIs will be removed in the next major version
- A migration path will always be provided

## Examples

See the `examples/` directory for complete usage examples.

## Support

For API-related questions or issues, please open an issue in our GitHub repository.

## Vulkan & UI Components

### Vulkan Renderer

The Vulkan renderer is implemented in `src/renderer/vulkan.zig`. It provides a low-level interface for Vulkan operations, including:

- Instance, device, swapchain, and surface creation.
- Image, framebuffer, and render pass setup.
- Shader module creation and graphics pipeline setup.
- Frame rendering, synchronization, and command buffer recording.

#### Shader Management

Shaders are loaded from SPIR-V binaries located in the `shaders/` directory. The renderer uses `vkCreateShaderModule` to create shader modules for vertex and fragment shaders.

### ImGui UI Renderer

The ImGui UI renderer is implemented in `src/renderer/imgui.zig`. It integrates ImGui with Vulkan for UI rendering, including:

- Descriptor pool and render pass setup for ImGui.
- Rendering ImGui UI elements using Vulkan.

### High-Level Renderer Interface

The high-level renderer interface is defined in `src/renderer/renderer.zig`. It wraps the Vulkan renderer and provides a simplified API for rendering operations.
