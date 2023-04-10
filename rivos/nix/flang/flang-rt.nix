{
  lib,
  stdenv,
  llvm_meta,
  symlinkJoin,
  monorepoSrc,
  runCommand,
  cmake,
  libclang,
  libllvm,
  libxml2,
  lit,
  mlir,
  ninja,
  version,
  packageVendor ? null,
}:
stdenv.mkDerivation rec {
  pname = "flang-rt";
  inherit version;

  src = runCommand "${pname}-src-${version}" {} ''
    mkdir -p "$out"
    cp -r ${monorepoSrc}/cmake "$out"
    cp -r ${monorepoSrc}/flang "$out"
  '';

  sourceRoot = "${src.name}/flang";

  outputs = ["out"];

  nativeBuildInputs = [cmake ninja];
  buildInputs = [libclang libllvm mlir];

  buildPhase = ''
    ninja -j"$NIX_BUILD_CORES" \
      Fortran_main \
      FortranDecimal \
      FortranRuntime
  '';

  installPhase = ''
    ninja -j"$NIX_BUILD_CORES" \
      install-Fortran_main \
      install-FortranDecimal \
      install-FortranRuntime
  '';

  cmakeFlags =
    [
      "-DCLANG_DIR=${libclang.dev}/lib/cmake/clang"
      "-DMLIR_DIR=${mlir.dev}/lib/cmake/mlir"
      "-DLLVM_DIR=${libllvm}/lib/cmake/llvm"
      "-DLLVM_BUILD_MAIN_SRC_DIR=${src}/llvm"
      "-DFLANG_INCLUDE_TESTS=OFF"
      "-GNinja" # Required since we're overriding the build phase.
    ]
    ++ lib.optionals (packageVendor != null) [
      "-DPACKAGE_VENDOR=${packageVendor}"
    ];

  doCheck = false;

  meta =
    llvm_meta
    // {
      homepage = "https://flang.llvm.org";
      description = "LLVM Fortran Runtime";
    };
}
