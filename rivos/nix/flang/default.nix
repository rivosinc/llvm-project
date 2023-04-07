# From https://github.com/NixOS/nixpkgs/pull/163878
{
  lib,
  stdenv,
  llvm_meta,
  buildLlvmTools,
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
  pname = "flang";
  inherit version;

  src = runCommand "${pname}-src-${version}" {} ''
    mkdir -p "$out"
    cp -r ${monorepoSrc}/cmake "$out"
    cp -r ${monorepoSrc}/${pname} "$out"
  '';

  sourceRoot = "${src.name}/${pname}";

  patches = [
    ./gnu-install-dirs.patch
  ];

  outputs = ["out" "lib" "dev"];

  nativeBuildInputs = [cmake ninja];
  buildInputs = [libclang libllvm libxml2 mlir];

  cmakeFlags =
    [
      "-DCLANG_DIR=${libclang.dev}/lib/cmake/clang"
      "-DMLIR_DIR=${mlir.dev}/lib/cmake/mlir"
      "-DLLVM_DIR=${libllvm}/lib/cmake/llvm"
      "-DMLIR_TABLEGEN_EXE=${buildLlvmTools.mlir}/bin/mlir-tblgen"
      "-DLLVM_EXTERNAL_LIT=${lit}/bin/lit"
      "-DLLVM_LIT_ARGS=-v"
      "-DLLVM_BUILD_MAIN_SRC_DIR=${src}/llvm"
      "-DFLANG_INCLUDE_TESTS=OFF"
    ]
    ++ lib.optionals (packageVendor != null) [
      "-DPACKAGE_VENDOR=${packageVendor}"
    ];

  doCheck = false;

  checkTarget = "check-all";

  # Point tests to new 'tools dir' that contains all tools + llvm-config (from .dev output)
  # Only need it for /bin but symlinkJoin links over other directories too
  postPatch = let
    llvmToolsDir = symlinkJoin {
      name = "llvm-tools";
      paths = [libllvm libllvm.dev];
    };
  in ''
    for x in test/lit.site.cfg.py.in test/Unit/lit.site.cfg.py.in test/NonGtestUnit/lit.site.cfg.py.in; do
      substituteInPlace "$x" --replace "@LLVM_TOOLS_DIR@" "${llvmToolsDir}/bin"
    done
  '';

  passthru = {
    langFortran = true;
    isClang = true;
  };

  meta =
    llvm_meta
    // {
      homepage = "https://flang.llvm.org";
      description = "LLVM Fortran Compiler";
    };
}
