@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-18 16:11:37",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./fix_cimgui.sh",
    "type": "sh",
    "hash": "03a72ea0ef8e0d5017299fab190b0555f511479c"
  }
}
@pattern_meta@

#!/bin/bash
sed -i 's/ImGuiTextFilter::ImGuiTextRange/ImGuiTextFilterRange/g' vendor/cimgui/cimgui.h
sed -i 's/ImStb::STB_TexteditState/ImStbTextEditState/g' vendor/cimgui/cimgui.h
sed -i 's/ImChunkStream<.*>/ImChunkStream_Generic/g' vendor/cimgui/cimgui.h
sed -i 's/ImPool<.*>/ImPool_Generic/g' vendor/cimgui/cimgui.h
sed -i 's/ImSpan<.*>/ImSpan_Generic/g' vendor/cimgui/cimgui.h
