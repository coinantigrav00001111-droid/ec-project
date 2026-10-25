::@echo off
::chcp 1251 >nul

::cd D:\Godot\ec-project


:: ==patch===
 git am -3 %1

::git am --continue
::git am --abort


:: ===diff===
:: git am < %1
:: проверка диф
::git apply --check %1


pause
::TIMEOUT /T 4
