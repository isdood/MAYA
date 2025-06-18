#!/bin/bash
sed -i 's/ImGuiTextFilter::ImGuiTextRange/ImGuiTextFilterRange/g' vendor/cimgui/cimgui.h
sed -i 's/ImStb::STB_TexteditState/ImStbTextEditState/g' vendor/cimgui/cimgui.h
sed -i 's/ImChunkStream<.*>/ImChunkStream_Generic/g' vendor/cimgui/cimgui.h
sed -i 's/ImPool<.*>/ImPool_Generic/g' vendor/cimgui/cimgui.h
sed -i 's/ImSpan<.*>/ImSpan_Generic/g' vendor/cimgui/cimgui.h
