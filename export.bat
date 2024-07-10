mkdir temp\export
mkdir temp\export\web
mkdir temp\export\bin
"temp\pico-8\pico8.exe" -root_path . -export defiance.p8.png defiance.p8
"temp\pico-8\pico8.exe" -root_path . -export temp/export/web/defiance.html defiance.p8
"temp\pico-8\pico8.exe" -root_path . -export temp/export/bin/defiance.bin defiance.p8
