::@echo off
::chcp 1251 >nul

::cd D:\Godot\ec-project


::git diff core/globals.gd

:: git add core/globals.gd
::git am --continue
:: git am --abort
:: git am -3 %1
git apply --check %1


pause
::TIMEOUT /T 4
