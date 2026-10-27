::@echo off
::chcp 1251 >nul

::cd D:\Godot\ec-project


git rebase --abort
:: ==patch===
git am -3 %1

::git am --continue
:: git am --abort


:: ===diff===
:: git am < %1
:: проверка диф
:: git apply --check %1
:: git am --show-current-patch=diff


pause
::TIMEOUT /T 4
