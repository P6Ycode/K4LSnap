include $(THEOS)/makefiles/common.mk

TOOL_NAME = k4lsnapd
k4lsnapd_FILES = main.m \
    ../Maintenance/K4LMaintenance.m \
    ../System/K4LSystemProtocol.m \
    ../System/K4LContainerLocator.m \
    ../System/K4LBackupManager.m \
    ../System/K4LAccountCategoryStore.m
k4lsnapd_CFLAGS = -fobjc-arc -I$(THEOS_PROJECT_DIR)/Maintenance -I$(THEOS_PROJECT_DIR)/System
k4lsnapd_FRAMEWORKS = Foundation AVFoundation ImageIO CoreGraphics
k4lsnapd_LIBRARIES = sqlite3
k4lsnapd_INSTALL_PATH = /usr/libexec

include $(THEOS_MAKE_PATH)/tool.mk
