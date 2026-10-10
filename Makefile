APP_NAME    := NotchDownloads
BUILD_DIR   := .build
DIST_DIR    := dist
APP_DIR     := $(DIST_DIR)/$(APP_NAME).app
BINARY      := $(BUILD_DIR)/release/$(APP_NAME)

.PHONY: build app run dev install uninstall clean

build:
	swift build -c release

## .app paketini oluşturur ve ad-hoc imzalar
app: build
	@echo "→ $(APP_DIR) oluşturuluyor"
	@rm -rf "$(APP_DIR)"
	@mkdir -p "$(APP_DIR)/Contents/MacOS"
	@cp "$(BINARY)" "$(APP_DIR)/Contents/MacOS/$(APP_NAME)"
	@cp Resources/Info.plist "$(APP_DIR)/Contents/Info.plist"
	@codesign --force --sign - "$(APP_DIR)" 2>/dev/null || true
	@echo "✓ $(APP_DIR) hazır"

## Eski süreci kapatıp uygulamayı yeniden başlatır
run: app
	@killall $(APP_NAME) 2>/dev/null || true
	@open "$(APP_DIR)"

## Geliştirme sırasında: terminalden çalıştırır (TCC izni terminalin izinlerini miras alır,
## her derlemede yeniden izin istemez)
dev: build
	@killall $(APP_NAME) 2>/dev/null || true
	@"$(BINARY)"

## /Applications altına kurar
install: app
	@cp -R "$(APP_DIR)" /Applications/
	@echo "✓ /Applications/$(APP_NAME).app kuruldu"

uninstall:
	@killall $(APP_NAME) 2>/dev/null || true
	@rm -rf "/Applications/$(APP_NAME).app"
	@echo "✓ Kaldırıldı"

clean:
	@rm -rf "$(BUILD_DIR)" "$(DIST_DIR)"
