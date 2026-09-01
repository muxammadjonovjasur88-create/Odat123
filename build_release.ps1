$env:TEMP = "D:\tmp"
$env:TMP = "D:\tmp"
$env:GRADLE_USER_HOME = "D:\gradle_user_home"
$env:PUB_CACHE = "D:\pub_cache"
$env:ANDROID_USER_HOME = "D:\android_user_home"
$env:JAVA_TOOL_OPTIONS = "-Djava.io.tmpdir=D:\tmp"
$env:DART_VM_OPTIONS = "--max-old-space-size=2048"

Set-Location -Path "D:\odat123\Flowa"
& "D:\flutter\bin\flutter.bat" build appbundle --release
