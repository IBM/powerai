#!/bin/bash

aclocal -I m4
autoconf

# Filter out -std=.* from CXXFLAGS as it disrupts checks for C++ language levels.
re='(.*[[:space:]])\-std\=[^[:space:]]*(.*)'
if [[ "${CXXFLAGS}" =~ $re ]]; then
  export CXXFLAGS="${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
fi

# Without this, dependency scanning fails.
export CPPFLAGS="${CPPFLAGS} -I$PREFIX/include"
if [[ $target_platform =~ linux.* ]]; then
  export LDFLAGS="${LDFLAGS} -Wl,-rpath-link,$PREFIX/lib"
fi
export TCL_CONFIG=${PREFIX}/lib/tclConfig.sh
export TK_CONFIG=${PREFIX}/lib/tkConfig.sh
export TCL_LIBRARY=${PREFIX}/lib/tcl8.6
export TK_LIBRARY=${PREFIX}/lib/tk8.6
# BUILD_PREFIX does not get considered for prefix replacement.
[[ -n ${AR} ]] && export AR=$(basename ${AR})
[[ -n ${CC} ]] && export CC=$(basename ${CC})
[[ -n ${GCC} ]] && export GCC=$(basename ${GCC})
[[ -n ${CXX} ]] && export CXX=$(basename ${CXX})
[[ -n ${F77} ]] && export F77=$(basename ${F77})
[[ -n ${FC} ]] && export FC=$(basename ${FC})
[[ -n ${LD} ]] && export LD=$(basename ${LD})
[[ -n ${RANLIB} ]] && export RANLIB=$(basename ${RANLIB})
[[ -n ${STRIP} ]] && export STRIP=$(basename ${STRIP})

Linux() {
    # If lib/R/etc/javaconf ends up with anything other than ~autodetect~
    # for any value (except JAVA_HOME) then 'R CMD javareconf' will never
    # change it, so we prevent configure from finding Java.  post-install
    # and activate scripts now call 'R CMD javareconf'.
    unset JAVA_HOME

    echo "ac_cv_lib_Xt_XtToolkitInitialize=yes" > config.site
    export CONFIG_SITE=${PWD}/config.site
    mkdir -p ${PREFIX}/lib
    ./configure --prefix=${PREFIX}               \
                --host=${HOST}                   \
                --build=${BUILD}                 \
                --enable-shared                  \
                --enable-R-shlib                 \
                --enable-BLAS-shlib              \
                --disable-prebuilt-html          \
                --enable-memory-profiling        \
                --with-tk-config=${TK_CONFIG}    \
                --with-tcl-config=${TCL_CONFIG}  \
                --with-x                         \
                --with-pic                       \
                --with-cairo                     \
                --with-readline                  \
                --with-recommended-packages=no   \
                --without-libintl-prefix         \
                LIBnn=lib

    if cat src/include/config.h | grep "undef HAVE_PANGOCAIRO"; then
        echo "Did not find pangocairo, refusing to continue"
        cat config.log | grep pango
        exit 1
    fi

    make -j${CPU_COUNT} ${VERBOSE_AT}
    # echo "Running make check-all, this will take some time ..."
    # make check-all -j1 V=1 > $(uname)-make-check.log 2>&1 || make check-all -j1 V=1 > $(uname)-make-check.2.log 2>&1

    make install
    # Prevent C and C++ extensions from linking to libgfortran.
    sed -i -r 's|(^LDFLAGS = .*)-lgfortran|\1|g' ${PREFIX}/lib/R/etc/Makeconf

    # Backup the old libR{blas,lapack}.so files and replace them with OpenBLAS
    pushd ${PREFIX}/lib/R/lib
      mv libRblas.so libRblas.so.reference
      mv libRlapack.so libRlapack.so.reference
      cp ../../libblas.so libRblas.so
      cp ../../liblapack.so libRlapack.so
      # .. and modify the SONAME.
      patchelf --set-soname libRblas.so libRblas.so
      patchelf --set-soname libRlapack.so libRlapack.so
    popd

    # # Backup the old libR{blas,lapack}.so files and make them symlinks to OpenBLAS
    # pushd ${PREFIX}/lib/R/lib
    #   mv libRblas.so libRblas.so.reference
    #   mv libRlapack.so libRlapack.so.reference
    #   ln -s ../../libblas.so libRblas.so
    #   ln -s ../../liblapack.so libRlapack.so
    # popd
    # .. and make sure that the fact it is now a symlink to libblas.so in $PREFIX/lib
    # does not trip up the linker when it tries to find DT_NEEDED for libgfortran.so.
    # (r-rserve falls without this fix).
    # pushd ${PREFIX}/lib/R/etc
    #   sed -i -r "s|-lRblas|-Wl,-rpath-link,${PREFIX}/lib -lRblas|" Makeconf
    # popd
}

# This was an attempt to see how far we could get with using Autotools as things
# stand. On 3.2.4, the build system attempts to compile the Unix code which works
# to an extent, finally falling over due to fd_set references in sys-std.c when
# it should be compiling sys-win32.c instead. Eventually it would be nice to fix
# the Autotools build framework so that can be used for Windows builds too.
Mingw_w64_autotools() {
    unset JAVA_HOME

    mkdir -p ${PREFIX}/lib
    export TCL_CONFIG=${PREFIX}/Library/mingw-w64/lib/tclConfig.sh
    export TK_CONFIG=${PREFIX}/Library/mingw-w64/lib/tkConfig.sh
    export TCL_LIBRARY=${PREFIX}/Library/mingw-w64/lib/tcl8.6
    export TK_LIBRARY=${PREFIX}/Library/mingw-w64/lib/tk8.6
    export CPPFLAGS="${CPPFLAGS} -I${SRC_DIR}/src/gnuwin32/fixed/h"
    if [[ "${ARCH}" == "64" ]]; then
        export CPPFLAGS="${CPPFLAGS} -DWIN=64 -DMULTI=64"
    fi
    ./configure --prefix=${PREFIX}              \
                --enable-shared                 \
                --enable-R-shlib                \
                --enable-BLAS-shlib             \
                --disable-prebuilt-html         \
                --enable-memory-profiling       \
                --with-tk-config=$TK_CONFIG     \
                --with-tcl-config=$TCL_CONFIG   \
                --with-x=no                     \
                --with-readline=no              \
                --with-recommended-packages=no  \
                LIBnn=lib

    make -j${CPU_COUNT} ${VERBOSE_AT}
    # echo "Running make check-all, this will take some time ..."
    # make check-all -j1 V=1 > $(uname)-make-check.log 2>&1
    make install
}

# Use the hand-crafted makefiles.
Mingw_w64_makefiles() {
    local _use_msys2_mingw_w64_tcltk=yes
    local _use_w32tex=no
    local _debug=no

    # Instead of copying a MkRules.dist file to MkRules.local
    # just create one with the options we know our toolchains
    # support, and don't set any
    if [[ "${ARCH}" == "64" ]]; then
        CPU="x86-64"
    else
        CPU="i686"
    fi

    if [[ "${_use_msys2_mingw_w64_tcltk}" == "yes" ]]; then
        TCLTK_VER=86
    else
        TCLTK_VER=85
        # Linking directly to DLLs, yuck.
        if [[ "${ARCH}" == "64" ]]; then
            export LDFLAGS="${LDFLAGS} -L${PREFIX}/lib/R/Tcl/bin64"
        else
            export LDFLAGS="${LDFLAGS} -L${PREFIX}/lib/R/Tcl/bin"
        fi
    fi

    # I want to use /tmp and have that mounted to Windows %TEMP% in Conda's MSYS2
    # but there's a permissions issue preventing that from working at present.
    # DLCACHE=/tmp
    DLCACHE=/c/Users/${USER}/Downloads
    [[ -d $DLCACHE ]] || mkdir -p $DLCACHE
    # Some hints from https://www.r-bloggers.com/an-openblas-based-rblas-for-windows-64-step-by-step/
    echo "LEA_MALLOC = YES"                              > "${SRC_DIR}/src/gnuwin32/MkRules.local"
    echo "BINPREF = "                                   >> "${SRC_DIR}/src/gnuwin32/MkRules.local"
    echo "BINPREF64 = "                                 >> "${SRC_DIR}/src/gnuwin32/MkRules.local"
    echo "USE_ATLAS = YES"                              >> "${SRC_DIR}/src/gnuwin32/MkRules.local"
    echo "ATLAS_PATH = ${PREFIX}/Library/mingw-w64/lib" >> "${SRC_DIR}/src/gnuwin32/MkRules.local"
    sed -i.bak 's|-lf77blas -latlas|-lopenblas|g' src/extra/blas/Makefile.win
    rm src/extra/blas/Makefile.win.bak
    echo "MULTI =   "                                   >> "${SRC_DIR}/src/gnuwin32/MkRules.local"
    echo "BUILD_HTML = YES"                             >> "${SRC_DIR}/src/gnuwin32/MkRules.local"
    echo "WIN = ${ARCH}"                                >> "${SRC_DIR}/src/gnuwin32/MkRules.local"
    if [[ "${_debug}" == "yes" ]]; then
        echo "EOPTS = -march=${CPU} -mtune=generic -O0" >> "${SRC_DIR}/src/gnuwin32/MkRules.local"
        echo "DEBUG = 1"                                >> "${SRC_DIR}/src/gnuwin32/MkRules.local"
    else
        # -O3 is used by R by default. It might be sensible to adopt -O2 here instead?
        echo "EOPTS = -march=${CPU} -mtune=generic"     >> "${SRC_DIR}/src/gnuwin32/MkRules.local"
    fi
    echo "OPENMP = -fopenmp"                            >> "${SRC_DIR}/src/gnuwin32/MkRules.local"
    echo "PTHREAD = -pthread"                           >> "${SRC_DIR}/src/gnuwin32/MkRules.local"
    echo "COPY_RUNTIME_DLLS = 1"                        >> "${SRC_DIR}/src/gnuwin32/MkRules.local"
    echo "TEXI2ANY = texi2any"                          >> "${SRC_DIR}/src/gnuwin32/MkRules.local"
    echo "TCL_VERSION = ${TCLTK_VER}"                   >> "${SRC_DIR}/src/gnuwin32/MkRules.local"
    echo "ISDIR = ${PWD}/isdir"                         >> "${SRC_DIR}/src/gnuwin32/MkRules.local"
    echo "USE_ICU = YES"                                >> "${SRC_DIR}/src/gnuwin32/MkRules.local"
    echo "ICU_PATH = \$(R_HOME)/../Library/mingw-w64"   >> "${SRC_DIR}/src/gnuwin32/MkRules.local"
    # This won't take and we'll force the issue at the end of the build* It's not really clear
    # if this is the best way to achieve my goal here (shared libraries, libpng, curl etc) but
    # it seems fairly reasonable all options considered. On other OSes, it's for '/usr/local'
    echo "LOCAL_SOFT = \$(R_HOME)/../Library/mingw-w64" >> "${SRC_DIR}/src/gnuwin32/MkRules.local"

    # The build process copies this across if it finds it and rummaging about on
    # the website I found a file, so why not, eh?
    curl -C - -o "${SRC_DIR}/etc/curl-ca-bundle.crt" -SLO http://www.stats.ox.ac.uk/pub/Rtools/goodies/multilib/curl-ca-bundle.crt

    # The hoops we must jump through to get innosetup installed in an unattended way.
    curl -C - -o ${DLCACHE}/innoextract-1.6-windows.zip -SLO http://constexpr.org/innoextract/files/innoextract-1.6/innoextract-1.6-windows.zip
    unzip -o ${DLCACHE}/innoextract-1.6-windows.zip -d ${PWD}
    curl -C - -o ${DLCACHE}/innosetup-5.5.9-unicode.exe -SLO http://files.jrsoftware.org/is/5/innosetup-5.5.9-unicode.exe || true
    ./innoextract.exe ${DLCACHE}/innosetup-5.5.9-unicode.exe 2>&1
    mv app isdir
    if [[ "${_use_msys2_mingw_w64_tcltk}" == "yes" ]]; then
        # I wanted to go for the following unusual approach here of using conda install (in copy mode)
        # and using MSYS2's mingw-w64 tcl/tk packages, but this is something for longer-term as there
        # is too much work to do around removing baked-in paths and logic around the ActiveState TCL.
        # For example expectations of Tcl/{bin,lib}64 folders in src/gnuwin32/installer/JRins.R and
        # other places I've not yet found.
        #
        # Plan was to install excluding the dependencies (so the necessary DLL dependencies will not
        # be present!). This should not matter since the DLL dependencies have already been installed
        # when r-base itself was installed and will be on the PATH already. The alternative to this
        # is to patch R so that it doesn't look for Tcl executables in in Tcl/bin or Tcl/bin64 and
        # instead looks in the same folder as the R executable which would be my prefered approach.
        #
        # The thing to is probably to make stub programs launching the right binaries in mingw-w64/bin
        # .. perhaps launcher.c can be generalized?
        mkdir -p "${SRC_DIR}/lib/R/Tcl"
        CONDA_SUBDIR=$target_platform conda.bat install -c https://conda.anaconda.org/msys2 \
                                                       --no-deps --yes --copy --prefix "${SRC_DIR}/lib/R/Tcl" \
                                                       m2w64-{tcl,tk,bwidget,tktable}
        mv "${SRC_DIR}"/lib/R/Tcl/Library/mingw-w64/* "${SRC_DIR}"/lib/R/Tcl/ || exit 1
        rm -Rf "${SRC_DIR}"/lib/R/Tcl/{Library,conda-meta,.BUILDINFO,.MTREE,.PKGINFO}
        if [[ "${ARCH}" == "64" ]]; then
            mv "${SRC_DIR}/lib/R/Tcl/bin" "${SRC_DIR}/lib/R/Tcl/bin64"
        fi
    else
        #
        # .. instead, more innoextract for now. We can probably use these archives instead:
        # http://www.stats.ox.ac.uk/pub/Rtools/R_Tcl_8-5-8.zip
        # http://www.stats.ox.ac.uk/pub/Rtools/R_Tcl_8-5-8.zip
        # as noted on http://www.stats.ox.ac.uk/pub/Rtools/R215x.html.
        #
        # curl claims most servers do not support byte ranges, hence the || true
        mkdir -p "${SRC_DIR}/lib/R"
        curl -C - -o ${DLCACHE}/Rtools34.exe -SLO http://cran.r-project.org/bin/windows/Rtools/Rtools34.exe || true
        if [[ "${ARCH}" == "64" ]]; then
            ./innoextract.exe -I "code\$rhome64" ${DLCACHE}/Rtools34.exe
            mv "code\$rhome64/Tcl" "${SRC_DIR}/lib/R"
        else
            ./innoextract.exe -I "code\$rhome" ${DLCACHE}/Rtools34.exe
            mv "code\$rhome/Tcl" "${SRC_DIR}/lib/R"
        fi
    fi

    # Horrible. We need MiKTeX or something like it (for pdflatex.exe. Building from source
    # may be possible but requires CLisp and I've not got time for that at present).  w32tex
    # looks a little less horrible than MiKTex (just read their build instructions and cry:
    # For  example:
    # Cygwin
    # Hint: install all packages, or be prepared to install missing packages later, when
    #       CMake fails to find them...
    # So, let's try with standard w32tex instead: http://w32tex.org/

    # W32TeX doesn't have inconsolata.sty which is
    # needed for R 3.2.4 (later Rs have switched to zi4
    # instead), I've switched to miktex instead.
    if [[ "${_use_w32tex}" == "yes" ]]; then
      mkdir w32tex || true
        pushd w32tex
        curl -C - -o ${DLCACHE}/texinst2016.zip -SLO http://ctan.ijs.si/mirror/w32tex/current/texinst2016.zip
        unzip -o ${DLCACHE}/texinst2016.zip
        mkdir archives || true
          pushd archives
            for _file in latex mftools platex pdftex-w32 ptex-w32 web2c-lib web2c-w32 \
                         datetime2 dvipdfm-w32 dvipsk-w32 jtex-w32 ltxpkgs luatexja \
                         luatex-w32 makeindex-w32 manual newtxpx-boondoxfonts pgfcontrib \
                         t1fonts tex-gyre timesnew ttf2pk-w32 txpx-pazofonts vf-a2bk \
                         xetex-w32 xindy-w32 xypic; do
              curl -C - -o ${DLCACHE}/${_file}.tar.xz -SLO http://ctan.ijs.si/mirror/w32tex/current/${_file}.tar.xz
            done
          popd
        ./texinst2016.exe ${PWD}/archives
        ls -l ./texinst2016.exe
        mount
        PATH=${PWD}/bin:${PATH}
      popd
    else
      mkdir miktex || true
      pushd miktex
      MIKTEX_VER=2.9.6753

      # Fetch e.g.:
      # http://ctan.mines-albi.fr/systems/win32/miktex/tm/packages/url.tar.lzma
      # http://ctan.mines-albi.fr/systems/win32/miktex/tm/packages/mptopdf.tar.lzma
      # http://ctan.mines-albi.fr/systems/win32/miktex/tm/packages/inconsolata.tar.lzma
        curl --insecure -C - -o ${DLCACHE}/miktex-portable-${MIKTEX_VER}.exe -SLO https://miktex.org/download/ctan/systems/win32/miktex/setup/windows-x86/miktex-portable-${MIKTEX_VER}.exe || true
        echo "Extracting miktex-portable-${MIKTEX_VER}.exe, this will take some time ..."
        7za x -y ${DLCACHE}/miktex-portable-${MIKTEX_VER}.exe > /dev/null || exit 1
        # We also need the url, incolsolata and mptopdf packages and
        # do not want a GUI to prompt us about installing these.
        # sed -i 's|AutoInstall=2|AutoInstall=1|g' miktex/config/miktex.ini
        #see also: http://tex.stackexchange.com/q/302679
        PATH=${PWD}/texmfs/install/miktex/bin:${PATH}
        initexmf.exe --set-config-value [MPM]AutoInstall=1
        initexmf.exe --update-fndb
        cat texmfs/config/miktex/config/miktex.ini
      popd
    fi

    # R_ARCH looks like an absolute path (e.g. "/x64"), so MSYS2 will convert it.
    # We need to prevent that from happening.
    export MSYS2_ARG_CONV_EXCL="R_ARCH"
    cd "${SRC_DIR}/src/gnuwin32"
    if [[ "${_use_msys2_mingw_w64_tcltk}" == "yes" ]]; then
        # rinstaller and crandir would come after manuals (if it worked with MSYS2/mingw-w64-{tcl,tk}, in which case we'd just use make distribution anyway)
        echo "***** R-${PACKAGE_VERSION} Build started *****"
        for _stage in all cairodevices recommended vignettes manuals; do
            echo "***** R-${PACKAGE_VERSION} Stage started: ${_stage} *****"
            make ${_stage} -j${CPU_COUNT} || exit 1
        done
    else
        echo "***** R-${PACKAGE_VERSION} Stage started: distribution *****"
        make distribution -j${CPU_COUNT} || exit 1
    fi
    # The flakiness mentioned below can be seen if the values are hacked to:
    # supremum error =  0.022  with p-value= 1e-04
    #  FAILED
    # Error in dkwtest("beta", shape1 = 0.2, shape2 = 0.2) : dkwtest failed
    # Execution halted
    # .. and testsuite execution is forced with:
    # pushd /c/Users/${USER}/mc3/conda-bld/work/R-revised/tests
    # ~/mc3/conda-bld/work/R-revised/bin/x64/R CMD BATCH --vanilla --no-timing ~/mc3/conda-bld/work/R-revised/tests/p-r-random-tests.R ~/gd/r-language/mingw-w64-p-r-random-tests.R.win.out
    # .. I need to see if this can be repeated on other systems and reported upstream or investigated more, it is very rare and I don't think warrants holding things up.
    # echo "Running make check-all (up to 3 times, there is some flakiness in p-r-random-tests.R), this will take some time ..."
    # make check-all -j1 > make-check.log 2>&1 || make check-all -j1 > make-check.2.log 2>&1 || make check-all -j1 > make-check.3.log 2>&1
    cd installer
    make imagedir
    cp -Rf R-${PKG_VERSION} R
    # Copied to ${PREFIX}/lib to mirror the unix layout so we can use "noarch: generic" packages for any that do not require compilation.
    mkdir -p "${PREFIX}"/lib

    cp -Rf R "${PREFIX}"/lib/
    # Copy Tcl/Tk support files
    cp -rf ${SRC_DIR}/lib/R/Tcl ${PREFIX}/lib/R

    # Remove the recommeded libraries, we package them separately as-per the other platforms now.
    rm -Rf "${PREFIX}"/lib/R/library/{MASS,lattice,Matrix,nlme,survival,boot,cluster,codetools,foreign,KernSmooth,rpart,class,nnet,spatial,mgcv}
    # * Here we force our MSYS2/mingw-w64 sysroot to be looked in for LOCAL_SOFT during r-packages builds (but actually this will not work since
    # R will append lib/$(R_ARCH) to this in various Makefiles. So long as we set build/merge_build_host then they will get found automatically)
    for _makeconf in $(find "${PREFIX}"/lib/R -name Makeconf); do
        # For SystemDependencies the host prefix is good.
        sed -i 's|LOCAL_SOFT = |LOCAL_SOFT = \$(R_HOME)/../../Library/mingw-w64|g' ${_makeconf}
        sed -i 's|^BINPREF ?= .*$|BINPREF ?= \$(R_HOME)/../../Library/mingw-w64/bin/|g' ${_makeconf}
        # For compilers it is not, since they're put in the build prefix.
        sed -i 's| = \$(BINPREF)| = |g' ${_makeconf}
    done
    return 0
}

Darwin() {
    unset JAVA_HOME

    # --without-internal-tzcode to avoid warnings:
    # unknown timezone 'Europe/London'
    # unknown timezone 'GMT'
    # https://stat.ethz.ch/pipermail/r-devel/2014-April/068745.html

    ./configure --prefix=${PREFIX}                  \
                --host=${HOST}                      \
                --build=${BUILD}                    \
                --with-blas="-framework Accelerate" \
                --with-tk-config=${TK_CONFIG}       \
                --with-tcl-config=${TCL_CONFIG}     \
                --with-lapack                       \
                --enable-R-shlib                    \
                --enable-memory-profiling           \
                --without-x                         \
                --without-internal-tzcode           \
                --enable-R-framework=no             \
                --with-included-gettext=yes         \
                --with-recommended-packages=no

    # Horrendous hack to make up for what seems to be bugs (or over-cautiousness?) in ld64's -dead_strip_dylibs (and/or -no_implicit_dylibs)
    sed -i'.bak' 's|-lgobject-2.0 -lglib-2.0 -lintl||g' src/library/grDevices/src/cairo/Makefile
    rm src/library/grDevices/src/cairo/Makefile.bak

    make -j${CPU_COUNT} ${VERBOSE_AT}
    # echo "Running make check-all, this will take some time ..."
    # make check-all -j1 V=1 > $(uname)-make-check.log 2>&1
    make install
}

if [[ $target_platform == osx-64 ]]; then
  Darwin
  mkdir -p ${PREFIX}/etc/conda/activate.d
  cp "${RECIPE_DIR}"/activate-${PKG_NAME}.sh ${PREFIX}/etc/conda/activate.d/activate-${PKG_NAME}.sh
elif [[ $target_platform =~ linux.* ]]; then
  Linux
  mkdir -p ${PREFIX}/etc/conda/activate.d
  cp "${RECIPE_DIR}"/activate-${PKG_NAME}.sh ${PREFIX}/etc/conda/activate.d/activate-${PKG_NAME}.sh
elif [[ $target_platform =~ win.* ]]; then
  # Mingw_w64_autotools
  Mingw_w64_makefiles
fi
