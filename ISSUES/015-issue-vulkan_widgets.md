# Issue 015: Vulkan Widget Architecture & Compilation Errors

## Summary

The current Zig Vulkan/ImGui widget system is experiencing persistent compilation errors, primarily:
- Unused function parameter errors in widget render functions
- Function pointer signature mismatches between widget render functions and the expected type in the core Widget struct
- C import errors due to an invalid or C++-style `cimgui.h` header

These issues are blocking successful builds and further development.

---

## Details

### 1. Unused Parameter Errors in Widget Render Functions

Widget render functions (e.g., for Button, Slider, etc.) are defined as:
```zig
fn render(widget: *Widget) !void { ... }
```
But the parameter is sometimes not used, or is only used to get the parent struct, leading to Zig's unused parameter error.

### 2. Function Pointer Signature Mismatch

The core `Widget` struct (in `imgui.zig`) expects:
```zig
render_fn: *const fn (*Self) anyerror!void,
```
But widget types (Button, Slider, etc.) define their own `Self` and their render functions take `*Button`, `*Slider`, etc., not `*imgui.Widget`.

This means the function pointer type does not match, so Zig will not call the render function, and the parameter is unused.

#### Example:
```zig
// In imgui.zig
pub const Widget = struct {
    ...
    render_fn: *const fn (*Self) anyerror!void,
    ...
};

// In widgets.zig
fn render(widget: *Widget) !void { ... } // Signature mismatch!
```

### 3. C Import Error: cimgui.h

The current `/usr/include/cimgui.h` is not a valid C header (contains C++ constructs like `::` and templates). This causes Zig's `@cImport` to fail.

---

## Root Causes
- **Signature mismatch** between widget render functions and the expected function pointer type in the Widget struct.
- **Incorrect cimgui.h**: Using a C++ header or a broken generator output instead of the pure C wrapper header from the cimgui project.

---

## Solution Plan

### A. Widget Render Function Trampolines
- For each widget type, create a trampoline function that matches the expected signature:
  ```zig
  fn button_render_trampoline(widget: *imgui.Widget) anyerror!void {
      const self = @fieldParentPtr(Button, "widget", widget);
      try self.render();
  }
  ```
- Pass the trampoline to `Widget.init`:
  ```zig
  .widget = Widget.init(id, position, size, button_render_trampoline),
  ```
- Update all widget render functions to use `self: *Self` as the parameter.

### B. Fix cimgui.h
- Download/build cimgui from https://github.com/cimgui/cimgui
- Use the generated `cimgui.h` and `cimgui.so` from the cimgui build output (not from ImGui or any other source).
- Ensure the header contains only C-style declarations (no `::`, no templates).
- Copy the correct files to `/usr/include` and `/usr/lib` as needed.

---

## Checklist for Future Resolution
- [ ] Refactor all widget render functions to use trampolines matching the Widget struct's expected signature
- [ ] Update all Widget.init calls to use the correct trampoline
- [ ] Replace cimgui.h and cimgui.so with the correct C wrapper versions
- [ ] Rebuild and verify that all unused parameter and C import errors are resolved

---

## References
- [cimgui project](https://github.com/cimgui/cimgui)
- Zig documentation on function pointers and @fieldParentPtr
- ImGui/Zig integration patterns

---

*Created automatically to document the current Vulkan widget architecture issues and provide a clear path to resolution.* 