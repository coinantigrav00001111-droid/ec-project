::@echo off
::chcp 1251 >nul

::cd D:\Godot\ec-project
git am -3 %1

:: git am -3 observe-s7-fast.patch
  
TIMEOUT /T 4
