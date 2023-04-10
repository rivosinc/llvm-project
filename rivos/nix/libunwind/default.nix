{
  lib,
  stdenv,
  llvm_meta,
  version,
  monorepoSrc,
  runCommand,
  cmake,
  ninja,
  python3,
  enableShared ? !stdenv.hostPlatform.isStatic,
}: let
  useLLVM = stdenv.hostPlatform.useLLVM or false;
in
  stdenv.mkDerivation rec {
    pname = "libunwind";
    inherit version;

    # I am not so comfortable giving libc++ and friends the whole monorepo as
    # requested, so I filter it to what is needed.
    src = runCommand "${pname}-src-${version}" {} ''
      mkdir -p "$out"
      cp -r ${monorepoSrc}/cmake "$out"
      cp -r ${monorepoSrc}/${pname} "$out"
      mkdir -p "$out/libcxx"
      cp -r ${monorepoSrc}/libcxx/cmake "$out/libcxx"
      cp -r ${monorepoSrc}/libcxx/utils "$out/libcxx"
      mkdir -p "$out/llvm"
      cp -r ${monorepoSrc}/llvm/cmake "$out/llvm"
      cp -r ${monorepoSrc}/llvm/utils "$out/llvm"
      cp -r ${monorepoSrc}/runtimes "$out"
    '';

    sourceRoot = "${src.name}/runtimes";

    prePatch = ''
      cd ../${pname}
      chmod -R u+w .
    '';

    patches = [
      ./gnu-install-dirs.patch
    ];

    postPatch = ''
      cd ../runtimes
    '';

    outputs = ["out" "dev"];

    nativeBuildInputs = [cmake ninja python3];

    cmakeFlags =
      [
        "-DLLVM_ENABLE_RUNTIMES=libunwind"
      ]
      ++ lib.optional (!enableShared) "-DLIBUNWIND_ENABLE_SHARED=OFF"
      ++ lib.optionals useLLVM [
        "-DCMAKE_C_COMPILER_WORKS=ON"
        "-DCMAKE_CXX_COMPILER_WORKS=ON"
        "-DLIBUNWIND_USE_COMPILER_RT=ON"
      ];

    # libcxxabi refers to this as unwind_shared and unwind_static. Set up
    # symlinks so both work.
    postInstall =
      ''
        ln -s "$out/lib/libunwind.a" "$out/lib/libunwind_static.a"
      ''
      + lib.optionalString enableShared ''
        ln -s "$out/lib/libunwind.so.1.0" "$out/lib/libunwind_shared.so.1.0"
        ln -s "$out/lib/libunwind.so.1" "$out/lib/libunwind_shared.so.1"
        ln -s "$out/lib/libunwind.so" "$out/lib/libunwind_shared.so"
      '';

    meta =
      llvm_meta
      // {
        # Details: https://github.com/llvm/llvm-project/blob/main/libunwind/docs/index.rst
        homepage = "https://clang.llvm.org/docs/Toolchain.html#unwind-library";
        description = "LLVM's unwinder library";
        longDescription = ''
          The unwind library provides a family of _Unwind_* functions implementing
          the language-neutral stack unwinding portion of the Itanium C++ ABI (Level
          I). It is a dependency of the C++ ABI library, and sometimes is a
          dependency of other runtimes.
        '';
      };
  }
