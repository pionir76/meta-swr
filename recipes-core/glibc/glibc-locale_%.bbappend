# pseudo openat2() 워크어라운드 확장 (참고: ../../classes/swr-pseudo-openat2-fix.bbclass)
#
# libc-package.bbclass의 do_prep_locale_tree / do_collect_bins_from_locale_tree는
# glibc-locale.inc가 "inherit libc-package"로 레시피 레벨에서 상속하기 때문에,
# USER_CLASSES를 통한 전역 오버라이드(swr-pseudo-openat2-fix.bbclass)보다
# 항상 나중에 파싱되어 그쪽 정의가 이겨버린다. perform_packagecopy와 달리
# 이 두 함수는 python이 아닌 shell 함수이자 do_package 경로 밖에서 자체적으로
# tar 파이프를 쓰기 때문에 별도로, 이 레시피에 직접 bbappend로 오버라이드해야 한다.
#
# tar 파이프를 cp -a 기반 복사로 교체. 원본과 동일한 대상만 복사하도록
# 패턴(l*.so*, libgcc_s.*)과 대상 서브디렉터리(i18n) 선택 로직은 그대로 유지.

do_prep_locale_tree() {
	treedir=${WORKDIR}/locale-tree
	rm -rf $treedir
	mkdir -p $treedir/${base_bindir} $treedir/${base_libdir} $treedir/${datadir} $treedir/${localedir}

	cp -a ${LOCALETREESRC}${datadir}/i18n $treedir/${datadir}/

	# unzip to avoid parsing errors
	for i in $treedir/${datadir}/i18n/charmaps/*gz; do
		gunzip $i
	done

	# The pattern "l*.so*" is carefully selected so that it will
	# match ld*.so and lib*.so*, but not any files in the gconv directory
	# (if it exists). This makes sure we only unpack the files we need.
	# This is important in case usrmerge is set in DISTRO_FEATURES, which
	# means ${base_libdir} == ${libdir}.
	for f in ${LOCALETREESRC}${base_libdir}/l*.so*; do
		[ -e "$f" ] || continue
		cp -a "$f" $treedir/${base_libdir}/
	done

	for f in ${STAGING_LIBDIR_NATIVE}/libgcc_s.*; do
		[ -e "$f" ] || continue
		cp -a "$f" $treedir/${base_libdir}/
	done

	install -m 0755 ${LOCALETREESRC}${bindir}/localedef $treedir/${base_bindir}
}

do_collect_bins_from_locale_tree() {
	treedir=${WORKDIR}/locale-tree

	parent=$(dirname ${localedir})
	name=$(basename ${localedir})
	mkdir -p ${PKGD}/$parent
	cp -a $treedir/$parent/$name ${PKGD}$parent/

	# Finalize tree by chaning all duplicate files into hard links
	cross-localedef-hardlink -c -v ${WORKDIR}/locale-tree
}
