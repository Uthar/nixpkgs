{ stdenv
, pkgs
, runCommand, fetchurl, zlib

, version
, headless ? false
}:

assert stdenv.hostPlatform.libc == "glibc";

let
  fetchboot = version: arch: sha256: fetchurl {
    name = "openjdk${version}-bootstrap-${arch}-linux.tar.xz";
    url  = "http://tarballs.nixos.org/openjdk/2018-03-31/${version}/${arch}-linux.tar.xz";
    inherit sha256;
  };

  blobs = {
    "x86_64-linux" = {
      "10" = fetchboot "10" "x86_64" "08085fsxc1qhqiv3yi38w8lrg3vm7s0m2yvnwr1c92v019806yq2";
    };
    "i686-linux" = {
      "8" = fetchboot "8"  "i686" "1yx04xh8bqz7amg12d13rw5vwa008rav59mxjw1b9s6ynkvfgqq9";
      "10" = fetchboot "10" "i686" "1blb9gyzp8gfyggxvggqgpcgfcyi00ndnnskipwgdm031qva94p7";
    };
  };

  jdks = {
    "x86_64-linux" = {
      "8" = pkgs.callPackage ./bootstrap {};
    };
  };

  blob = blobs.${stdenv.hostPlatform.system}.${version} or null;

  jdk = jdks.${stdenv.hostPlatform.system}.${version} or null;

  bootstrap =
    if jdk != null then jdk
    else if blob != null then runCommand "openjdk-bootstrap" {
      passthru.home = "${bootstrap}/lib/openjdk";
    } ''
      tar xvf ${blob}
      mv openjdk-bootstrap $out
      
      LIBDIRS="$(find $out -name \*.so\* -exec dirname {} \; | sort | uniq | tr '\n' ':')"
      
      find "$out" -type f -print0 | while IFS= read -r -d "" elf; do
        isELF "$elf" || continue
        patchelf --set-interpreter $(cat "${stdenv.cc}/nix-support/dynamic-linker") "$elf" || true
        patchelf --set-rpath "${stdenv.cc.libc}/lib:${stdenv.cc.cc.lib}/lib:${zlib}/lib:$LIBDIRS" "$elf" || true
      done
    ''
    else throw "No bootstrap for jdk ${version} for system ${stdenv.hostPlatform.system}";
in bootstrap
