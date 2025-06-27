#ifndef SHADERS_H
#define SHADERS_H

#include <stdint.h>

// 4D tensor operations (float)
extern const uint8_t shader_float[];
extern const size_t shader_float_size;

// 4D tensor operations (int)
extern const uint8_t shader_int[];
extern const size_t shader_int_size;

// 4D tensor operations (uint)
extern const uint8_t shader_uint[];
extern const size_t shader_uint_size;

#endif // SHADERS_H
