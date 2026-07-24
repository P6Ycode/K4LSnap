ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = Snapchat

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = K4LSnap
K4LSnap_FILES = Tweak.xm \
    Sources/K4LSystem.m \
    Sources/K4LPreferences.m \
    Sources/K4LVaultStore.m \
    Sources/K4LFeaturePolicy.m \
    Sources/K4LGalleryUploadCoordinator.m \
    Sources/K4LSnapVersionAdapter.m \
    Sources/K4LLauncher.m \
    Sources/K4LVaultViewController.m \
    Sources/K4LMediaPreviewController.m \
    Sources/K4LSettingsViewController.m
K4LSnap_CFLAGS = -fobjc-arc -I$(THEOS_PROJECT_DIR)/Headers
K4LSnap_FRAMEWORKS = UIKit Photos PhotosUI AVFoundation AVKit UniformTypeIdentifiers
K4LSnap_LIBRARIES = sqlite3

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
