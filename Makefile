TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = SpringBoard
export THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = A11ZeroAuto

# Ensure this matches the new filename!
A11ZeroAuto_FILES = Tweak.xm
# This line is mandatory for the code above to work!
A11ZeroAuto_FRAMEWORKS = IOKit Foundation
A11ZeroAuto_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

A11ZeroAuto_CODESIGN_FLAGS = -Sentitlements.plist
