TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = SpringBoard
export THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = A11ZeroAuto
A11ZeroAuto_FILES = Tweak.xm
A11ZeroAuto_FRAMEWORKS = IOKit UIKit
A11ZeroAuto_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
