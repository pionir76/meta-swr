# SmartRoute 앱이 QSqlDatabase(QSQLITE)를 쓰므로 Qt SQL sqlite 드라이버 필요.
# (예전에는 build 디렉토리 local.conf의 PACKAGECONFIG:append:pn-qtbase에 있었음 -
# 빌드 디렉토리를 새로 만들면 빠지는 문제가 있어 레이어로 옮김.)
PACKAGECONFIG:append = " sql-sqlite"

# meta-freescale의 qtbase bbappend가 i.MX6ULL(imxpxp 오버라이드)에 gles2를 강제로
# 넣어 DISTRO_FEATURES에서 opengl을 빼도 mesa(소프트웨어 GLES)가 같이 빌드/설치된다.
# 헤드리스 보드에서 SmartRoute는 QCoreApplication만 쓰므로 GL이 전혀 필요 없다 -
# gles2를 빼서 mesa 의존과 빌드 시간을 줄인다 (no-opengl + linuxfb만 남음).
PACKAGECONFIG:remove = "gles2"
