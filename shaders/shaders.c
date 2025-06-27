#include "shaders.h"

// 4D tensor operations (float)
#include "4d_tensor_operations_float.comp.spv.inc"
const size_t shader_float_size = sizeof(shader_float_data);
const uint8_t* shader_float = shader_float_data;

// 4D tensor operations (int)
#include "4d_tensor_operations_int.comp.spv.inc"
const size_t shader_int_size = sizeof(shader_int_data);
const uint8_t* shader_int = shader_int_data;

// 4D tensor operations (uint)
#include "4d_tensor_operations_uint.comp.spv.inc"
const size_t shader_uint_size = sizeof(shader_uint_data);
const uint8_t* shader_uint = shader_uint_data;
