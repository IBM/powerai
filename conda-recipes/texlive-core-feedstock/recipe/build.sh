#! /bin/bash

set -e
set -x

# From: https://github.com/TeX-Live/texlive-source/blob/trunk/Build
unset TEXMFCNF; export TEXMFCNF
LANG=C; export LANG
# [[ -d "${PREFIX}"/texmf ]] || mkdir -p "${PREFIX}"/texmf
# ./configure --help

# Using texlive just does not work, various sub-parts ignore that and use PREFIX/share
# SHARE_DIR=${PREFIX}/share/texlive
SHARE_DIR=${PREFIX}/share

declare -a CONFIG_EXTRA
if [[ ${target_platform} =~ .*ppc.* ]]; then
  # luajit is incompatible with powerpc.
  CONFIG_EXTRA+=(--disable-luajittex)
  CONFIG_EXTRA+=(--disable-mfluajit)
fi

TEST_SEGFAULT=yes

# if [[ ${TEST_SEGFAULT} == yes ]] && [[ ${target_platform} =~ .*linux.* ]]; then
if [[ ${TEST_SEGFAULT} == yes ]]; then
  # -O2 results in:
  # FAIL: mplibdir/mptraptest.test
  # FAIL: pdftexdir/pdftosrc.test
  # .. so (sorry!)
  export CFLAGS="${CFLAGS} -O0 -ggdb"
  export CXXFLAGS="${CXXFLAGS} -O0 -ggdb"
  CONFIG_EXTRA+=(--enable-debug)
else
  CONFIG_EXTRA+=(--disable-debug)
fi


# kpathsea scans the texmf.cnf file to set up its hardcoded paths, so set them
# up before building. It doesn't seem to handle multivalued TEXMFCNF entries,
# so we patch that up after install.
# Requires prefix replacement, which does not work correctly.
mv "${SRC_DIR}"/texk/kpathsea/texmf.cnf tmp.cnf
sed \
    -e "s|TEXMFROOT =.*|TEXMFROOT = ${SHARE_DIR}|" \
    -e "s|TEXMFLOCAL =.*|TEXMFLOCAL = ${SHARE_DIR}/texmf-local|" \
    -e "/^TEXMFCNF/,/^}/d" \
    -e "s|%TEXMFCNF =.*|TEXMFCNF = ${SHARE_DIR}/texmf-dist/web2c|" \
    <tmp.cnf >"${SRC_DIR}"/texk/kpathsea/texmf.cnf
rm -f tmp.cnf

[[ -d "${SHARE_DIR}/tlpkg/TeXLive" ]] || mkdir -p "${SHARE_DIR}/tlpkg/TeXLive"
[[ -d "${SHARE_DIR}/texmf-dist/scripts/texlive" ]] || mkdir -p "${SHARE_DIR}/texmf-dist/scripts/texlive"

# Completely essential, see https://github.com/conda-forge/texlive-core-feedstock/issues/19
find . -name "TexLive"
install -v -m644 texk/tests/TeXLive/* "${SHARE_DIR}/tlpkg/TeXLive" || exit 1
install -v -m644 texmf/texmf-dist/scripts/texlive/mktexlsr.pl "${SHARE_DIR}/texmf-dist/scripts/texlive" || exit 1

export KPATHSEA_WARNING=0

mkdir tmp_build || true
pushd tmp_build
  ${SRC_DIR}/configure \
               --prefix="${PREFIX}" \
               --host=${HOST} \
               --build=${BUILD} \
               --datarootdir="${SHARE_DIR}" \
               --disable-all-pkgs \
               --disable-native-texlive-build \
               --disable-ipc \
               --disable-debug \
               --disable-dependency-tracking \
               --disable-mf \
               --disable-pmp \
               --disable-upmp \
               --disable-aleph \
               --disable-eptex \
               --disable-euptex \
               --disable-luatex \
               --disable-luajittex \
               --disable-uptex \
               --enable-web2c \
               --enable-silent-rules \
               --enable-tex \
               --enable-etex \
               --enable-pdftex \
               --enable-xetex \
               --enable-web-progs \
               --enable-texlive \
               --enable-dvipdfm-x \
               --with-system-cairo \
               --with-system-freetype2 \
               --with-system-gmp \
               --with-system-graphite2 \
               --with-system-harfbuzz \
               --with-system-icu \
               --with-system-libpng \
               --with-system-mpfr \
               --with-system-pixman \
               --with-system-poppler \
               --with-system-zlib \
               --without-x \
               "${CONFIG_EXTRA[@]}" || { cat config.log ; exit 1 ; }
  # There is a race-condition in the build system.
  make -j${CPU_COUNT} ${VERBOSE_AT} || make -j1 ${VERBOSE_AT}
  # make check reads files from the installation prefix:
  make install-strip -j${CPU_COUNT}
  make texlinks

  # At this point BLFS does:
  # tar -xf ../../texlive-20180414-texmf.tar.xz -C /opt/texlive/2018 --strip-components=1
  # .. but we would like to avoid this 2.5GB of stuff.
  [[ -d "${SHARE_DIR}/texmf-dist" ]] || mkdir -p "${SHARE_DIR}/texmf-dist"
  cp -rf "${SRC_DIR}"/texmf/texmf-dist/* "${SHARE_DIR}/texmf-dist/"

  # get some ini files too
  git clone https://github.com/latex3/tex-ini-files.git "${SRC_DIR}"/texmf/texmf-dist/tex-ini-files
  [[ -d "${SHARE_DIR}/texmf-dist/tex/generic" ]] || mkdir -p "${SHARE_DIR}/texmf-dist/tex/generic"
  cp -rf "${SRC_DIR}"/texmf/texmf-dist/tex-ini-files "${SHARE_DIR}"/texmf-dist/tex/generic

  #xetex
  pushd "${SHARE_DIR}"
  #wget -e robots=off -nH -nv --cut-dirs=3 --recursive --no-parent --reject="index.html*" https://www.tug.org/texlive/devsrc/Master/texmf-dist/tex/generic/tex-ini-files/
  wget -e robots=off -nH -nv --cut-dirs=3 --recursive --no-parent --reject="index.html*" https://www.tug.org/texlive/devsrc/Master/texmf-dist/dvipdfmx/dvipdfmx.cfg
  wget -e robots=off -nH -nv --cut-dirs=3 --recursive --no-parent --reject="index.html*" https://www.tug.org/texlive/devsrc/Master/texmf-dist/tex/generic/unicode-data/
  wget -e robots=off -nH -nv --cut-dirs=3 --recursive --no-parent --reject="index.html*" https://www.tug.org/texlive/devsrc/Master/texmf-dist/tex/latex/base/
  wget -e robots=off -nH -nv --cut-dirs=3 --recursive --no-parent --reject="index.html*" https://www.tug.org/texlive/devsrc/Master/texmf-dist/tex/plain/etex/
  #wget -e robots=off -nH -nv --cut-dirs=3 --recursive --no-parent --reject="index.html*" https://www.tug.org/texlive/devsrc/Master/texmf-dist/fonts/source/public/cm/
  wget -e robots=off -nH -nv --cut-dirs=3 --recursive --no-parent --reject="index.html*" https://www.tug.org/texlive/devsrc/Master/texmf-dist/fonts/cmap/dvipdfmx/
  wget -e robots=off -nH -nv --cut-dirs=3 --recursive --no-parent --reject="index.html*" https://www.tug.org/texlive/devsrc/Master/texmf-dist/fonts/map/dvipdfmx/cid-x.map
  wget -e robots=off -nH -nv --cut-dirs=3 --recursive --no-parent --reject="index.html*" https://www.tug.org/texlive/devsrc/Master/texmf-dist/fonts/map/glyphlist/
  wget -e robots=off -nH -nv --cut-dirs=3 --recursive --no-parent --reject="index.html*" https://www.tug.org/texlive/devsrc/Master/texmf-dist/texconfig/
  wget -e robots=off -nH -nv --cut-dirs=3 --recursive --no-parent --reject="index.html*" https://www.tug.org/texlive/devsrc/Master/texmf-dist/web2c/fmtutil.cnf
  wget -e robots=off -nH -nv --cut-dirs=3 --recursive --no-parent --reject="index.html*" https://www.tug.org/texlive/devsrc/Master/texmf-dist/web2c/texmf.cnf
  wget -e robots=off -nH -nv --cut-dirs=3 --recursive --no-parent --reject="index.html*" https://www.tug.org/texlive/devsrc/Master/texmf-dist/web2c/cp227.tcx
  wget -e robots=off -nH -nv --cut-dirs=3 --recursive --no-parent --reject="index.html*" https://www.tug.org/texlive/devsrc/Master/texmf-dist/web2c/mktex.cnf
  wget -e robots=off -nH -nv --cut-dirs=3 --recursive --no-parent --reject="index.html*" https://www.tug.org/texlive/devsrc/Master/texmf-dist/web2c/mktex.opt
  wget -e robots=off -nH -nv --cut-dirs=3 --recursive --no-parent --reject="index.html*" https://www.tug.org/texlive/devsrc/Master/texmf-dist/web2c/mktexdir
  wget -e robots=off -nH -nv --cut-dirs=3 --recursive --no-parent --reject="index.html*" https://www.tug.org/texlive/devsrc/Master/texmf-dist/web2c/mktexdir.opt
  wget -e robots=off -nH -nv --cut-dirs=3 --recursive --no-parent --reject="index.html*" https://www.tug.org/texlive/devsrc/Master/texmf-dist/web2c/mktexnam
  wget -e robots=off -nH -nv --cut-dirs=3 --recursive --no-parent --reject="index.html*" https://www.tug.org/texlive/devsrc/Master/texmf-dist/web2c/mktexnam.opt
  wget -e robots=off -nH -nv --cut-dirs=3 --recursive --no-parent --reject="index.html*" https://www.tug.org/texlive/devsrc/Master/texmf-dist/web2c/mktexupd
  popd

  # Disable generating formats
  #
  #mktexlsr "${SHARE_DIR}/texmf-local" || exit 1
  #mktexlsr || exit 1
  #fmtutil-sys --no-error-if-no-engine=luatex,luajittex,dviluatex,lualatex --all || exit 1
  #fmtutil-sys --all || exit 1
  #mtxrun --generate || exit 1

  #if [[ ! ${target_platform} =~ .*linux.* ]]; then
  #  LC_ALL=C make check ${VERBOSE_AT}
  #el
#  if [[ ${TEST_SEGFAULT} == yes ]]; then # && [[ ${target_platform} =~ .*linux.* ]]; then
#    LC_ALL=C make check ${VERBOSE_AT}
#    echo "pushd ${SRC_DIR}/build-tmp/texk/web2c"
#    echo "LC_ALL=C make check ${VERBOSE_AT}"
#    echo "cat mplibdir/mptraptest.log"
#    pushd "${SRC_DIR}/build-tmp/texk/web2c/mpost"
#      # I believe mpost test fails here because it tries to load mpost itself as a configuration file
#      # .. this happens in both failing tests on Linux. Debug builds (CFLAGS-wise) do not suffer a
#      # segfault at this point but release ones. Skipping for now, will re-visit later.
#      LC_ALL=C ../mpost --ini ../mpost
#    popd
#    exit 1
#  fi
popd

# Remove info and man pages.
rm -rf "${SHARE_DIR}/man"
rm -rf "${SHARE_DIR}/info"

mv "${SHARE_DIR}"/texmf-dist/web2c/texmf.cnf tmp.cnf
sed \
    -e "s|TEXMFCNF =.*|TEXMFCNF = {${SHARE_DIR}/texmf-local/web2c, ${SHARE_DIR}/texmf-dist/web2c}|" \
    <tmp.cnf >${SHARE_DIR}/texmf-dist/web2c/texmf.cnf
rm -f tmp.cnf

# Create symlinks for pdflatex and latex
#pushd "${PREFIX}"/bin
#  ln -s pdftex pdflatex
#  ln -s pdftex latex
#popd
