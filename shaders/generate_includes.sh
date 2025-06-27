#!/bin/bash

# Create include files for SPIR-V shaders
for shader in 4d_tensor_operations_float.comp 4d_tensor_operations_int.comp 4d_tensor_operations_uint.comp; do
    # Convert shader to C array
    xxd -i ${shader}.spv > ${shader}.spv.inc
    
    # Fix array name to match our C code
    sed -i 's/unsigned char .*_spv\[\]/const unsigned char '${shader}'_data[] = {/' ${shader}.spv.inc
    echo "};" >> ${shader}.spv.inc
done
