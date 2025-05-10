pyinstaller --clean launcher.py --hidden-import "clr" --onefile --noconsole --icon=static/favicon.ico --add-data "static;static" --distpath ..  --upx-dir=./bin/upx
