@echo off
rem Play Woolly Road (Horus SDK runs in simulator mode: fake ads and test purchases)
start "" "%LOCALAPPDATA%\Programs\Godot\Godot_v4.7.2-stable_win64.exe" --path "%~dp0."
