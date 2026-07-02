ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = dsgames

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DarkCheatKeyGate
DarkCheatKeyGate_FILES = Tweak.xm
DarkCheatKeyGate_CFLAGS = -fobjc-arc
DarkCheatKeyGate_FRAMEWORKS = UIKit Foundation QuartzCore

include $(THEOS_MAKE_PATH)/tweak.mk
