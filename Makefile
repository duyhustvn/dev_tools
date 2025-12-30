program=JsonUI

test:
	flutter test

analyze:
	flutter analyze

build-linux:
	flutter build linux --release

run:
	flutter run lib/main.dart

install:
	sudo cp -R build/linux/x64/release/bundle /opt/$(program)
	sudo mkdir -p /opt/$(program)/icons
	sudo cp icons/json.png /opt/$(program)/icons/json.png
	cp json_ui.desktop ~/.local/share/applications/json_ui.desktop
