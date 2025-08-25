APP="build/Debug/Ascent.app"
/usr/bin/xattr -lr "$APP" | awk '/:$/ {p=$0} /com.apple.(ResourceFork|FinderInfo)/ {print p}'