::@echo off
::chcp 1251 >nul

::cd D:\Godot\ec-project
cd /d "%~dp0"

cmd /k "git am -3 %1"


:: ==patch===
:: git am -3 %1


::git am --continue
:: git am --abort


:: ===diff===
:: git am < %1
:: проверка диф
:: git apply --check %1
:: git am --show-current-patch=diff
::git rebase --abort

pause
::TIMEOUT /T 4
