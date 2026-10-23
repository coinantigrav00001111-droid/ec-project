::@echo off
::chcp 1251 >nul

::cd D:\Godot\ec-project

git am -3 %1
::git diff core/globals.gd

:: git add core/globals.gd
:: git am --continue

:: git am -3 observe-s7-fast.patch

pause
::TIMEOUT /T 4
