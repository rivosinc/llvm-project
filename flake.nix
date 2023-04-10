# Copyright (c) 2022 Rivos Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met: redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer;
# redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution;
# neither the name of the copyright holders nor the names of its
# contributors may be used to endorse or promote products derived from
# this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
{
  description = "LLVM Compiler Infrastructure Project (Rivos fork)";

  # Nixpkgs / NixOS version to use.
  inputs = {
    nix-filter.url = "github:numtide/nix-filter";

    nixpkgs.url = "github:rivosinc/nixpkgs/rivos/nixos-22.11?allRefs=1";
  };

  outputs = {
    self,
    nixpkgs,
    nix-filter,
    ...
  }: let
    rev = self.shortRev or "dirty";

    llvmCmake = nixpkgs.lib.fileContents ./llvm/CMakeLists.txt;
    llvmMajor = builtins.head (builtins.match ".*set\\(LLVM_VERSION_MAJOR ([0-9]+)\\).*" llvmCmake);
    llvmMinor = builtins.head (builtins.match ".*set\\(LLVM_VERSION_MINOR ([0-9]+)\\).*" llvmCmake);
    llvmPatch = builtins.head (builtins.match ".*set\\(LLVM_VERSION_PATCH ([0-9]+)\\).*" llvmCmake);
    llvmVersion = "${llvmMajor}.${llvmMinor}.${llvmPatch}";

    # System types to support.
    supportedSystems = ["aarch64-linux" "x86_64-linux"];

    # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

    # Nixpkgs instantiated for supported system types.
    nixpkgsFor = forAllSystems (system:
      import nixpkgs {
        inherit system;
        overlays = [self.overlays.default];
      });
    riscv64CrossPkgsFor = forAllSystems (system:
      import nixpkgs {
        inherit system;
        crossSystem = "riscv64-linux";
        overlays = [self.overlays.default];
      });
  in rec {
    overlays.default = final: prev: {
      llvmPackages_rivos = with final;
        lib.recurseIntoAttrs (callPackage ./rivos/nix {
          inherit overrideCC;
          officialRelease = null;
          packageVendor = "Rivos";
          gitRelease = rec {
            inherit rev;
            version = llvmVersion;
            rev-version = "${version}-g${rev}";
          };
          monorepoSrc = nix-filter.lib {
            root = ./.;
            exclude = [
              ./rivos
              ./flake.nix
              ./flake.lock
            ];
          };
          libxml2 = prev.libxml2.override {
            pythonSupport = false;
          };
          buildLlvmTools = pkgsBuildHost.llvmPackages_rivos.tools;
          targetLlvmLibraries = pkgsTargetTarget.llvmPackages_rivos.libraries or llvmPackages_rivos.libraries;
          targetLlvm = targetPackages.llvmPackages_rivos.llvm or llvmPackages_rivos.llvm;
        });
    };
    overlays.cross = final: prev: let
      flakePkgs = overlays.default final prev;
    in {
      inherit (flakePkgs) llvmPackages_rivos;
      llvmPackages =
        if final.stdenv.targetPlatform != final.stdenv.buildPlatform
        then flakePkgs.llvmPackages_rivos
        else prev.llvmPackages;
    };

    legacyPackages = forAllSystems (system: let
      llvmPackages_rivos = (nixpkgsFor.${system}).llvmPackages_rivos;
      llvmPackages_rivos_riscv64 = (riscv64CrossPkgsFor.${system}).buildPackages.llvmPackages_rivos;
    in {
      inherit llvmPackages_rivos;
      inherit llvmPackages_rivos_riscv64;
    });

    formatter = forAllSystems (system: nixpkgsFor.${system}.alejandra);
  };
}
