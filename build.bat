pyinstaller --onefile --noconsole --name kamiwaza_installer windows_installer.py
candle installer.wxs
light -ext WixUIExtension installer.wixobj