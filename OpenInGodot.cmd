@echo off
rem Open the Woolly Road project in the Godot 4.7.2 editor
start "" "%LOCALAPPDATA%\Programs\Godot\Godot_v4.7.2-stable_win64.exe" --path "%~dp0." -e
