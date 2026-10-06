@echo off
setlocal
rem BOTAO_BUILD=17
title Craque de Botao - Gerar APK Android
cd /d "%~dp0"

echo ============================================================
echo   CRAQUE DE BOTAO - BUILD 15 - ANDROID (TOQUE E MANCHES) - GODOT 3.6
echo   GERA O APK COMPLETO DO JOGO
echo ============================================================
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\gerar_apk\GERAR_APK_COMPLETO.ps1"
if errorlevel 1 (
  echo.
  echo FALHA: o APK nao foi criado. Fotografe esta janela inteira.
  pause
  exit /b 1
)

echo.
echo SUCESSO. APK criado em:
echo %~dp0build\android\CraqueDeBotao.apk
echo.
echo Copie o APK para o pendrive e instale no tablet/totem.
pause
exit /b 0
