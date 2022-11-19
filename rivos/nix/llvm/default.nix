{
  lib,
  stdenv,
  llvm_meta,
  pkgsBuildBuild,
  monorepoSrc,
  runCommand,
  fetchpatch,
  cmake,
  ninja,
  python3,
  libffi,
  libbfd,
  libpfm,
  libxml2,
  ncurses,
  version,
  release_version,
  packageVendor ? null,
  zlib,
  which,
  buildLlvmTools,
  debugVersion ? false,
  enableManpages ? false,
  enableSharedLibraries ? !stdenv.hostPlatform.isStatic,
  enablePFM ?
    !(
      stdenv.isDarwin
      || stdenv.isAarch64 # broken for Ampere eMAG 8180 (c2.large.arm on Packet) #56245
      || stdenv.isAarch32 # broken for the armv7l builder
    ),
  enablePolly ? false,
} @ args: let
  inherit (lib) optional optionals optionalString;

  # Used when creating a version-suffixed symlink of libLLVM.dylib
  shortVersion = with lib;
    concatStringsSep "." (take 1 (splitString "." release_version));
in
  stdenv.mkDerivation (rec {
      pname = "llvm";
      inherit version;

      src = runCommand "${pname}-src-${version}" {} (''
          mkdir -p "$out"
          cp -r ${monorepoSrc}/cmake "$out"
          cp -r ${monorepoSrc}/${pname} "$out"
          cp -r ${monorepoSrc}/third-party "$out"
        ''
        + lib.optionalString enablePolly ''
          cp -r ${monorepoSrc}/polly "$out/llvm/tools"
        '');

      sourceRoot = "${src.name}/${pname}";

      outputs = ["out" "lib" "dev" "python"];

      nativeBuildInputs =
        [cmake ninja python3]
        ++ optionals enableManpages [python3.pkgs.sphinx python3.pkgs.recommonmark];

      buildInputs =
        [libxml2 libffi]
        ++ optional enablePFM libpfm; # exegesis

      propagatedBuildInputs = [ncurses zlib];

      checkInputs = [
        which
        python3.pkgs.psutil # !!! lit still doesn't seem to find this; leads to some
        # tests being skipped
      ];

      patches =
        [
          ./gnu-install-dirs.patch
        ]
        ++ lib.optional enablePolly ./gnu-install-dirs-polly.patch;

      postPatch =
        optionalString stdenv.isDarwin ''
          substituteInPlace cmake/modules/AddLLVM.cmake \
            --replace 'set(_install_name_dir INSTALL_NAME_DIR "@rpath")' "set(_install_name_dir)" \
            --replace 'set(_install_rpath "@loader_path/../''${CMAKE_INSTALL_LIBDIR}''${LLVM_LIBDIR_SUFFIX}" ''${extra_libdir})' ""
        ''
        + ''
          # FileSystem permissions tests fail with various special bits
          substituteInPlace unittests/Support/CMakeLists.txt \
            --replace "Path.cpp" ""
          rm unittests/Support/Path.cpp
          substituteInPlace unittests/IR/CMakeLists.txt \
            --replace "PassBuilderCallbacksTest.cpp" ""
          rm unittests/IR/PassBuilderCallbacksTest.cpp
          rm test/tools/llvm-objcopy/ELF/mirror-permissions-unix.test
        ''
        + optionalString stdenv.hostPlatform.isMusl ''
          patch -p1 -i ${../../TLI-musl.patch}
          substituteInPlace unittests/Support/CMakeLists.txt \
            --replace "add_subdirectory(DynamicLibrary)" ""
          rm unittests/Support/DynamicLibrary/DynamicLibraryTest.cpp
          # valgrind unhappy with musl or glibc, but fails w/musl only
          rm test/CodeGen/AArch64/wineh4.mir
        ''
        + optionalString stdenv.hostPlatform.isAarch32 ''
          # skip failing X86 test cases on 32-bit ARM
          rm test/DebugInfo/X86/convert-debugloc.ll
          rm test/DebugInfo/X86/convert-inlined.ll
          rm test/DebugInfo/X86/convert-linked.ll
          rm test/tools/dsymutil/X86/op-convert.test
          rm test/tools/gold/X86/split-dwarf.ll
          rm test/tools/llvm-dwarfdump/X86/prettyprint_types.s
          rm test/tools/llvm-dwarfdump/X86/simplified-template-names.s
        ''
        + optionalString (stdenv.hostPlatform.system == "armv6l-linux") ''
          # Seems to require certain floating point hardware (NEON?)
          rm test/ExecutionEngine/frem.ll
        ''
        + ''
          patchShebangs test/BugPoint/compile-custom.ll.py
        '';

      preConfigure = ''
        # Workaround for configure flags that need to have spaces
        cmakeFlagsArray+=(
          -DLLVM_LIT_ARGS="-svj''${NIX_BUILD_CORES} --no-progress-bar"
        )
      '';

      # Defensive check: some paths (that we make symlinks to) depend on the release
      # version, for example:
      #  - https://github.com/llvm/llvm-project/blob/406bde9a15136254f2b10d9ef3a42033b3cb1b16/clang/lib/Headers/CMakeLists.txt#L185
      #
      # So we want to sure that the version in the source matches the release
      # version we were given.
      #
      # We do this check here, in the LLVM build, because it happens early.
      postConfigure = let
        v = lib.versions;
        major = v.major release_version;
        minor = v.minor release_version;
        patch = v.patch release_version;
      in ''
        # $1: part, $2: expected
        check_version() {
          part="''${1^^}"
          part="$(cat include/llvm/Config/llvm-config.h  | grep "#define LLVM_VERSION_''${part} " | cut -d' ' -f3)"

          if [[ "$part" != "$2" ]]; then
            echo >&2 \
              "mismatch in the $1 version! we have version ${release_version}" \
              "and expected the $1 version to be $2; the source has $part instead"
            exit 3
          fi
        }

        check_version major ${major}
        check_version minor ${minor}
        check_version patch ${patch}
      '';

      # hacky fix: created binaries need to be run before installation
      preBuild = ''
        mkdir -p $out/
        ln -sv $PWD/lib $out
      '';

      # E.g. mesa.drivers use the build-id as a cache key (see #93946):
      LDFLAGS = optionalString (enableSharedLibraries && !stdenv.isDarwin) "-Wl,--build-id=sha1";

      cmakeFlags = with stdenv; let
        # These flags influence llvm-config's BuildVariables.inc in addition to the
        # general build. We need to make sure these are also passed via
        # CROSS_TOOLCHAIN_FLAGS_NATIVE when cross-compiling or llvm-config-native
        # will return different results from the cross llvm-config.
        #
        # Some flags don't need to be repassed because LLVM already does so (like
        # CMAKE_BUILD_TYPE), others are irrelevant to the result.
        flagsForLlvmConfig =
          [
            "-DLLVM_INSTALL_PACKAGE_DIR=${placeholder "dev"}/lib/cmake/llvm"
          ]
          ++ optionals enableSharedLibraries [
            "-DLLVM_LINK_LLVM_DYLIB=ON"
          ];
      in
        flagsForLlvmConfig
        ++ [
          "-DCMAKE_BUILD_TYPE=${
            if debugVersion
            then "Debug"
            else "Release"
          }"
          "-DLLVM_INSTALL_UTILS=ON" # Needed by rustc
          "-DLLVM_BUILD_TESTS=${
            if doCheck
            then "ON"
            else "OFF"
          }"
          "-DLLVM_ENABLE_FFI=ON"
          "-DLLVM_HOST_TRIPLE=${stdenv.hostPlatform.config}"
          "-DLLVM_DEFAULT_TARGET_TRIPLE=${stdenv.hostPlatform.config}"
          "-DLLVM_ENABLE_DUMP=ON"
        ]
        ++ lib.optionals (packageVendor != null) [
          "-DPACKAGE_VENDOR=${packageVendor}"
        ]
        ++ optionals stdenv.hostPlatform.isStatic [
          # Disables building of shared libs, -fPIC is still injected by cc-wrapper
          "-DLLVM_ENABLE_PIC=OFF"
          "-DLLVM_BUILD_STATIC=ON"
          # libxml2 needs to be disabled because the LLVM build system ignores its .la
          # file and doesn't link zlib as well.
          # https://github.com/ClangBuiltLinux/tc-build/issues/150#issuecomment-845418812
          "-DLLVM_ENABLE_LIBXML2=OFF"
        ]
        ++ optionals enableManpages [
          "-DLLVM_BUILD_DOCS=ON"
          "-DLLVM_ENABLE_SPHINX=ON"
          "-DSPHINX_OUTPUT_MAN=ON"
          "-DSPHINX_OUTPUT_HTML=OFF"
          "-DSPHINX_WARNINGS_AS_ERRORS=OFF"
        ]
        ++ optionals (!isDarwin) [
          "-DLLVM_BINUTILS_INCDIR=${libbfd.dev}/include"
        ]
        ++ optionals isDarwin [
          "-DLLVM_ENABLE_LIBCXX=ON"
          "-DCAN_TARGET_i386=false"
        ]
        ++ optionals (stdenv.hostPlatform != stdenv.buildPlatform) [
          "-DCMAKE_CROSSCOMPILING=True"
          "-DLLVM_TABLEGEN=${buildLlvmTools.llvm}/bin/llvm-tblgen"
          (
            let
              nativeCC = pkgsBuildBuild.targetPackages.stdenv.cc;
              nativeBintools = nativeCC.bintools.bintools;
              nativeToolchainFlags = [
                "-DCMAKE_C_COMPILER=${nativeCC}/bin/${nativeCC.targetPrefix}cc"
                "-DCMAKE_CXX_COMPILER=${nativeCC}/bin/${nativeCC.targetPrefix}c++"
                "-DCMAKE_AR=${nativeBintools}/bin/${nativeBintools.targetPrefix}ar"
                "-DCMAKE_STRIP=${nativeBintools}/bin/${nativeBintools.targetPrefix}strip"
                "-DCMAKE_RANLIB=${nativeBintools}/bin/${nativeBintools.targetPrefix}ranlib"
              ];
              # We need to repass the custom GNUInstallDirs values, otherwise CMake
              # will choose them for us, leading to wrong results in llvm-config-native
              nativeInstallFlags = [
                "-DCMAKE_INSTALL_PREFIX=${placeholder "out"}"
                "-DCMAKE_INSTALL_BINDIR=${placeholder "out"}/bin"
                "-DCMAKE_INSTALL_INCLUDEDIR=${placeholder "dev"}/include"
                "-DCMAKE_INSTALL_LIBDIR=${placeholder "lib"}/lib"
                "-DCMAKE_INSTALL_LIBEXECDIR=${placeholder "lib"}/libexec"
              ];
            in
              "-DCROSS_TOOLCHAIN_FLAGS_NATIVE:list="
              + lib.concatStringsSep ";" (lib.concatLists [
                flagsForLlvmConfig
                nativeToolchainFlags
                nativeInstallFlags
              ])
          )
        ];

      postBuild = ''
        rm -fR $out
      '';

      preCheck = ''
        export LD_LIBRARY_PATH=$LD_LIBRARY_PATH''${LD_LIBRARY_PATH:+:}$PWD/lib
      '';

      postInstall =
        ''
          mkdir -p $python/share
          mv $out/share/opt-viewer $python/share/opt-viewer
          moveToOutput "bin/llvm-config*" "$dev"
          substituteInPlace "$dev/lib/cmake/llvm/LLVMExports-${
            if debugVersion
            then "debug"
            else "release"
          }.cmake" \
            --replace "\''${_IMPORT_PREFIX}/lib/lib" "$lib/lib/lib" \
            --replace "$out/bin/llvm-config" "$dev/bin/llvm-config"
          substituteInPlace "$dev/lib/cmake/llvm/LLVMConfig.cmake" \
            --replace 'set(LLVM_BINARY_DIR "''${LLVM_INSTALL_PREFIX}")' 'set(LLVM_BINARY_DIR "'"$lib"'")'
        ''
        + optionalString (stdenv.isDarwin && enableSharedLibraries) ''
          ln -s $lib/lib/libLLVM.dylib $lib/lib/libLLVM-${shortVersion}.dylib
          ln -s $lib/lib/libLLVM.dylib $lib/lib/libLLVM-${release_version}.dylib
        ''
        + optionalString (stdenv.buildPlatform != stdenv.hostPlatform) ''
          cp NATIVE/bin/llvm-config $dev/bin/llvm-config-native
        '';

      # RIVOS: don't check on vmware machines
      doCheck = false;

      checkTarget = "check-all";

      # For the update script:
      passthru.monorepoSrc = monorepoSrc;

      requiredSystemFeatures = ["big-parallel"];
      meta =
        llvm_meta
        // {
          homepage = "https://llvm.org/";
          description = "A collection of modular and reusable compiler and toolchain technologies";
          longDescription = ''
            The LLVM Project is a collection of modular and reusable compiler and
            toolchain technologies. Despite its name, LLVM has little to do with
            traditional virtual machines. The name "LLVM" itself is not an acronym; it
            is the full name of the project.
            LLVM began as a research project at the University of Illinois, with the
            goal of providing a modern, SSA-based compilation strategy capable of
            supporting both static and dynamic compilation of arbitrary programming
            languages. Since then, LLVM has grown to be an umbrella project consisting
            of a number of subprojects, many of which are being used in production by
            a wide variety of commercial and open source projects as well as being
            widely used in academic research. Code in the LLVM project is licensed
            under the "Apache 2.0 License with LLVM exceptions".
          '';
        };
    }
    // lib.optionalAttrs enableManpages {
      pname = "llvm-manpages";

      propagatedBuildInputs = [];

      ninjaFlags = ["docs-llvm-man"];
      installTargets = ["install-docs-llvm-man"];

      postPatch = null;
      postInstall = null;

      outputs = ["out"];

      doCheck = false;

      meta =
        llvm_meta
        // {
          description = "man pages for LLVM ${version}";
        };
    })
