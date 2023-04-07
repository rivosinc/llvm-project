{
  lib,
  stdenv,
  llvm_meta,
  monorepoSrc,
  runCommand,
  substituteAll,
  cmake,
  ninja,
  libxml2,
  libllvm,
  version,
  packageVendor ? null,
  python3,
  buildLlvmTools,
  fixDarwinDylibNames,
  enableManpages ? false,
}: let
  self = stdenv.mkDerivation (rec {
      pname = "clang";
      inherit version;

      src = runCommand "${pname}-src-${version}" {} ''
        mkdir -p "$out"
        cp -r ${monorepoSrc}/cmake "$out"
        cp -r ${monorepoSrc}/${pname} "$out"
        #cp -r ${monorepoSrc}/clang-tools-extra "$out"
      '';

      sourceRoot = "${src.name}/${pname}";

      nativeBuildInputs =
        [cmake ninja python3]
        ++ lib.optional enableManpages python3.pkgs.sphinx
        ++ lib.optional stdenv.hostPlatform.isDarwin fixDarwinDylibNames;

      buildInputs = [libxml2 libllvm];

      cmakeFlags =
        [
          "-DCLANG_INSTALL_PACKAGE_DIR=${placeholder "dev"}/lib/cmake/clang"
          "-DCLANGD_BUILD_XPC=OFF"
          # TODO: re-enable
          "-DLLVM_INCLUDE_TESTS=OFF"

          # Failing to link on ToT.
          # [1257/1922] Linking CXX shared module lib/SampleAnalyzerPlugin.so
          # FAILED: lib/SampleAnalyzerPlugin.so
          # : && /nix/store/d9p28gf5acss2h794j3g4k1p78bzjq3x-gcc-wrapper-11.3.0/bin/g++ -fPIC -fPIC -fno-semantic-interposition -fvisibility-inlines-hidden -Werror=date-time -Wall -Wextra -Wno-unused-parameter -Wwrite-strings -Wcast-qual -Wno-missing-field-initializers -Wimplicit-fallthrough -Wno-class-memaccess -Wno-redundant-move -Wno-pessimizing-move -Wno-noexcept-typ>
          # /nix/store/iak3prvh9l562iqjylz4ivdbif0kx8xi-binutils-2.39/bin/ld: cannot open linker script file /build/clang-src-17.0.0-g00bbd81/clang/build/lib/Analysis/plugins/SampleAnalyzer/SampleAnalyzerPlugin.exports: No such file or directory
          # collect2: error: ld returned 1 exit status
          "-DCLANG_ENABLE_ARCMT=OFF"
          "-DCLANG_ENABLE_STATIC_ANALYZER=OFF"
        ]
        ++ lib.optionals enableManpages [
          "-DCLANG_INCLUDE_DOCS=ON"
          "-DLLVM_ENABLE_SPHINX=ON"
          "-DSPHINX_OUTPUT_MAN=ON"
          "-DSPHINX_OUTPUT_HTML=OFF"
          "-DSPHINX_WARNINGS_AS_ERRORS=OFF"
        ]
        ++ lib.optionals (stdenv.hostPlatform != stdenv.buildPlatform) [
          "-DLLVM_TABLEGEN_EXE=${buildLlvmTools.llvm}/bin/llvm-tblgen"
          "-DCLANG_TABLEGEN=${buildLlvmTools.libclang.dev}/bin/clang-tblgen"
        ]
        ++ lib.optionals (packageVendor != null) [
          "-DPACKAGE_VENDOR=${packageVendor}"
        ];

      patches = [
        ./purity.patch
        # https://reviews.llvm.org/D51899
        ./gnu-install-dirs.patch
        (substituteAll {
          src = ./llvmgold-path.patch;
          libllvmLibdir = "${libllvm.lib}/lib";
        })
      ];

      postPatch =
        ''
          #(cd tools && ln -s ../../clang-tools-extra extra)

          sed -i -e 's/DriverArgs.hasArg(options::OPT_nostdlibinc)/true/' \
                 -e 's/Args.hasArg(options::OPT_nostdlibinc)/true/' \
                 lib/Driver/ToolChains/*.cpp
        ''
        + lib.optionalString stdenv.hostPlatform.isMusl ''
          sed -i -e 's/lgcc_s/lgcc_eh/' lib/Driver/ToolChains/*.cpp
        '';

      outputs = ["out" "lib" "dev" "python"];

      postInstall = ''
        ln -sv $out/bin/clang $out/bin/cpp

        # Move libclang to 'lib' output
        moveToOutput "lib/libclang.*" "$lib"
        moveToOutput "lib/libclang-cpp.*" "$lib"
        substituteInPlace $dev/lib/cmake/clang/ClangTargets-release.cmake \
            --replace "\''${_IMPORT_PREFIX}/lib/libclang." "$lib/lib/libclang." \
            --replace "\''${_IMPORT_PREFIX}/lib/libclang-cpp." "$lib/lib/libclang-cpp."

        mkdir -p $python/bin $python/share/clang/
        #mv $out/bin/{git-clang-format,scan-view} $python/bin
        if [ -e $out/bin/set-xcode-analyzer ]; then
          mv $out/bin/set-xcode-analyzer $python/bin
        fi
        mv $out/share/clang/*.py $python/share/clang
        rm -f $out/bin/c-index-test
        patchShebangs $python/bin

        mkdir -p $dev/bin
        cp bin/clang-tblgen $dev/bin
      '';

      passthru = {
        isClang = true;
        inherit libllvm;
      };

      meta =
        llvm_meta
        // {
          homepage = "https://clang.llvm.org/";
          description = "A C language family frontend for LLVM";
          longDescription = ''
            The Clang project provides a language front-end and tooling
            infrastructure for languages in the C language family (C, C++, Objective
            C/C++, OpenCL, CUDA, and RenderScript) for the LLVM project.
            It aims to deliver amazingly fast compiles, extremely useful error and
            warning messages and to provide a platform for building great source
            level tools. The Clang Static Analyzer and clang-tidy are tools that
            automatically find bugs in your code, and are great examples of the sort
            of tools that can be built using the Clang frontend as a library to
            parse C/C++ code.
          '';
          mainProgram = "clang";
        };
    }
    // lib.optionalAttrs enableManpages {
      pname = "clang-manpages";

      ninjaFlags = ["docs-clang-man"];

      installPhase = ''
        mkdir -p $out/share/man/man1
        # Manually install clang manpage
        cp docs/man/*.1 $out/share/man/man1/
      '';

      outputs = ["out"];

      doCheck = false;

      meta =
        llvm_meta
        // {
          description = "man page for Clang ${version}";
        };
    });
in
  self
