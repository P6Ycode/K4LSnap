include $(THEOS)/makefiles/common.mk

TOOL_NAME = k4lsnapctl
k4lsnapctl_FILES = main.m ../Maintenance/K4LMaintenance.m
k4lsnapctl_CFLAGS = -fobjc-arc -I$(THEOS_PROJECT_DIR)/Maintenance
k4lsnapctl_FRAMEWORKS = Foundation AVFoundation ImageIO CoreGraphics
k4lsnapctl_LIBRARIES = sqlite3
k4lsnapctl_INSTALL_PATH = /usr/bin

include $(THEOS_MAKE_PATH)/tool.mk
