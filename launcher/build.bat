pyinstaller --clean launcher.py --hidden-import "clr" --onefile --noconsole --icon=static/favicon.ico --add-data "static;static" --distpath .. --runtime-hook=check_win_ver.py --splash splash.jpg
