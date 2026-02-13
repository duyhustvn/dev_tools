program=DevToolsPromax

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
	sudo cp icons/icon.png /opt/$(program)/icons/icon.png
	cp dev_tools_pro_max.desktop ~/.local/share/applications/dev_tools_pro_max.desktop
