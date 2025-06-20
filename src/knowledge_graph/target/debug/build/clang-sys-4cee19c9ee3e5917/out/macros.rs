@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-17 17:41:24",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./src/knowledge_graph/target/debug/build/clang-sys-4cee19c9ee3e5917/out/macros.rs",
    "type": "rs",
    "hash": "259cbc7dc479ef357d2822bbaf04ea391da43d63"
  }
}
@pattern_meta@

// SPDX-License-Identifier: Apache-2.0

macro_rules! test {
    () => (cfg!(test) && ::std::env::var("_CLANG_SYS_TEST").is_ok());
}

macro_rules! target_os {
    ($os:expr) => {
        if cfg!(test) && ::std::env::var("_CLANG_SYS_TEST").is_ok() {
            let var = ::std::env::var("_CLANG_SYS_TEST_OS");
            var.map_or(false, |v| v == $os)
        } else {
            cfg!(target_os = $os)
        }
    };
}

macro_rules! target_arch {
    ($arch:expr) => {
        if cfg!(test) && ::std::env::var("_CLANG_SYS_TEST").is_ok() {
            let var = ::std::env::var("_CLANG_SYS_TEST_ARCH");
            var.map_or(false, |v| v == $arch)
        } else {
            cfg!(target_arch = $arch)
        }
    };
}

macro_rules! target_pointer_width {
    ($pointer_width:expr) => {
        if cfg!(test) && ::std::env::var("_CLANG_SYS_TEST").is_ok() {
            let var = ::std::env::var("_CLANG_SYS_TEST_POINTER_WIDTH");
            var.map_or(false, |v| v == $pointer_width)
        } else {
            cfg!(target_pointer_width = $pointer_width)
        }
    };
}

macro_rules! target_env {
    ($env:expr) => {
        if cfg!(test) && ::std::env::var("_CLANG_SYS_TEST").is_ok() {
            let var = ::std::env::var("_CLANG_SYS_TEST_ENV");
            var.map_or(false, |v| v == $env)
        } else {
            cfg!(target_env = $env)
        }
    };
}
