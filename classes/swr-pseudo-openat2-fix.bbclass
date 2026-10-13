# =============================================================================
# swr-pseudo-openat2-fix.bbclass — pseudo openat2() Workaround (global)
# =============================================================================
#
# ■ 핵심 원인
# ─────────────────────────────────────────────────────────────────────────────
# 호스트 커널 6.8.0 + GNU tar 1.34 조합에서 tar가 디렉터리 탐색 시
# openat2() (syscall 437, Linux 5.6 신규)를 사용한다.
# 그런데 현재 poky 브랜치의 pseudo (SRCREV: 28dcefb...)는 syscall 437을
# 인터셉트 테이블에 등록하지 않아, openat2()가 pseudo를 우회하여 커널에 직접 전달된다.
#
# pseudo는 fd 추적 방식으로 동작하므로:
#   1. pseudo 외부에서 openat2()로 디렉터리를 열어 fd를 얻음
#   2. 이후 fstatat(fd, "상대경로")처럼 그 fd를 기반으로 파일을 접근
#   3. pseudo는 fd 정보가 없으므로 EFAULT("Bad address") 반환 → tar 실패
#
# 에러 패턴:
#   got *at() syscall for unknown directory, fd N
#   tar: ./usr/lib/...: Cannot stat: Bad address
#   tar: Exiting with failure status due to previous errors
#
# 원래 recipes-qt/qt6/qtserialbus_%.bbappend 에만 국한된 워크어라운드였으나,
# do_package(perform_packagecopy)를 실제로 실행하는 모든 레시피(sstate 미스 시)에서
# 동일하게 재현됨을 확인 (예: swr-network-config). 호스트 환경 자체의 버그이므로
# 레이어 전역(classes/) 으로 옮기고 layer.conf에서 INHERIT 시킨다.
#
# ■ 발생 지점 (2곳)
# ─────────────────────────────────────────────────────────────────────────────
# [1] do_package → perform_packagecopy (package.bbclass)
#     패키지 파일을 PKGD로 복사할 때 tar 파이프 사용:
#       tar --exclude=./sysroot-only -cf - -C ${D} -p -S . | tar -xf - -C ${PKGD}
#     → tar가 openat2()로 ${D} 디렉터리 fd를 얻고, pseudo가 추적 실패
#
# [2] do_package_write_deb → dpkg-deb (package_deb.bbclass)
#     dpkg-deb -b <pkg_dir> <out.deb> 내부에서 data.tar.xz를 생성할 때
#     GNU tar를 서브프로세스로 호출 → 동일한 openat2() 문제 발생
#
# ■ 상류(upstream) 수정 현황 (2026-09-02 확인)
# ─────────────────────────────────────────────────────────────────────────────
# 아직 공식 수정되지 않음. 실제 openat2() 인터셉트 wrapper 구현 패치
# (Mark Hatle, 2026-01-15, "[pseudo,4/4] openat2: Implement openat2 wrapper")는
# 아직 pseudo 프로젝트에 머지되지 않은 "State: New" 상태.
#   https://patchwork.yoctoproject.org/project/yocto/patch/1768439403-23665-5-git-send-email-mark.hatle@kernel.crashing.org/
# Richard Purdie의 2026-02-13 패치는 SYS_openat2 매크로 정의 누락만 고치는
# 컴파일 레벨 수정이며, 실제 인터셉트 로직과 무관.
# 2026-09-01자 Yocto 5.3.1 릴리즈 노트에도 "이번 안정 릴리즈에는 미포함,
# 다음 릴리즈 목표"라고 명시되어 있음.
#   https://docs.yoctoproject.org/migration-guides/release-notes-5.3.1.html
#
# ■ 향후 제거 조건
# ─────────────────────────────────────────────────────────────────────────────
# pseudo SRCREV가 openat2() 인터셉트를 포함한 버전으로 업그레이드되면
# 이 클래스의 INHERIT(layer.conf) 한 줄만 제거해도 무방하다.
# 확인 방법: pseudo 소스에서 SYS_openat2 또는 syscall 437 처리 여부 검색,
# 또는 Yocto 릴리즈 노트에서 위 이슈의 해결 여부 확인.
# =============================================================================

# [Fix 2] dpkg-deb를 pseudo 없이 실행 + 소유권 root:root 강제
DPKG_BUILDCMD = "env PSEUDO_UNLOAD=1 dpkg-deb --root-owner-group"

# [Fix 1] tar 파이프 대신 Python shutil로 파일 복사
python perform_packagecopy() {
    import shutil
    import os

    dest = d.getVar('D')
    dvar = d.getVar('PKGD')

    if not os.path.exists(dvar):
        os.makedirs(dvar)

    for item in os.listdir(dest):
        if item == 'sysroot-only':
            continue
        src = os.path.join(dest, item)
        dst = os.path.join(dvar, item)
        if os.path.islink(src):
            os.symlink(os.readlink(src), dst)
        elif os.path.isdir(src):
            shutil.copytree(src, dst, symlinks=True)
        else:
            shutil.copy2(src, dst)
}
