@echo off
setlocal
rem Resolve the built binary through cabal so a GHC or version bump cannot
rem leave this launcher pointing at a stale dist-newstyle path.
pushd "%~dp0"
for /f "delims=" %%I in ('cabal list-bin exe:leant 2^>nul') do set "EXE=%%I"
if not exist "%EXE%" (
  echo Building leant...
  cabal build exe:leant
  for /f "delims=" %%I in ('cabal list-bin exe:leant 2^>nul') do set "EXE=%%I"
)
popd
"%EXE%" %*
if not "%errorlevel%"=="0" pause
