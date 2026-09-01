@echo off
set TEMP=D:\tmp
set TMP=D:\tmp
set GRADLE_USER_HOME=D:\gradle_user_home
set PUB_CACHE=D:\pub_cache
set ANDROID_USER_HOME=D:\android_user_home
set JAVA_TOOL_OPTIONS=-Djava.io.tmpdir=D:\tmp
set DART_VM_OPTIONS=--max-old-space-size=2048
set PATH=D:\flutter\bin;%PATH%

cd /d D:\odat123\Flowa
echo Starting Flutter Web on Chrome port 5000...
flutter run -d chrome --web-port=5000
pause
