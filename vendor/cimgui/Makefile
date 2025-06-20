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
    "path": "./vendor/cimgui/Makefile",
    "type": "/vendor/cimgui/Makefile",
    "hash": "b5d68940018d7aca77ebb569463495db39b56c8f"
  }
}
@pattern_meta@

#
# Cross Platform Makefile
# Compatible with Ubuntu 14.04.1 and macOS

OBJS = cimgui.o
OBJS += ./imgui/imgui.o
OBJS += ./imgui/imgui_draw.o
OBJS += ./imgui/imgui_demo.o
OBJS += ./imgui/imgui_tables.o
OBJS += ./imgui/imgui_widgets.o

CXXFLAGS=-O2 -fno-exceptions -fno-rtti

UNAME_S := $(shell uname -s)

AR := ar -rc

ifeq ($(UNAME_S), Linux) #LINUX
	ECHO_MESSAGE = "Linux"

	OUTPUTNAME = cimgui.so
	CXXFLAGS += -I./imgui/
	CXXFLAGS += -Wall
	CXXFLAGS += -shared -fPIC
	CFLAGS = $(CXXFLAGS)
endif

ifeq ($(UNAME_S), Darwin) #APPLE
	ECHO_MESSAGE = "macOS"

	OUTPUTNAME = cimgui.dylib
	CXXFLAGS += -I/usr/local/include
	CXXFLAGS += -Wall
	LINKFLAGS = -dynamiclib
	CFLAGS = $(CXXFLAGS)
endif

ifeq ($(OS), Windows_NT)
	ECHO_MESSAGE = "Windows"

	OUTPUTNAME = cimgui.dll
	CXXFLAGS += -I./imgui/
	CXXFLAGS += -Wall
	CXXFLAGS += -shared
	LINKFLAGS = -limm32
	CFLAGS = $(CXXFLAGS)
endif

.cpp.o:
	$(CXX) $(CXXFLAGS) -c -o $@ $<

all:$(OUTPUTNAME)
	@echo Build complete for $(ECHO_MESSAGE)

static:$(OBJS)
	$(AR) libcimgui.a $(OBJS)

$(OUTPUTNAME):$(OBJS)
	$(CXX) -o $(OUTPUTNAME) $(OBJS) $(CXXFLAGS) $(LINKFLAGS)

clean:
ifeq ($(OS),Windows_NT)
	del /q $(subst /,\,$(OBJS))
else
	rm -f $(OBJS)
endif

fclean: clean
ifeq ($(OS),Windows_NT)
	del /q $(subst /,\,$(OUTPUTNAME))
else
	rm -f $(OUTPUTNAME)
endif

re: fclean all

.PHONY: all clean fclean re static
