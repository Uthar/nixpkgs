{ newScope, config, stdenv, fetchurl, makeWrapper
, llvmPackages_10, llvmPackages_11, ed, gnugrep, coreutils, xdg_utils
, glib, gtk3, gnome3, gsettings-desktop-schemas, gn, fetchgit
, libva ? null
, gcc, nspr, nss, patchelfUnstable, runCommand
, lib

# package customization
# Note: enable* flags should not require full rebuilds (i.e. only affect the wrapper)
, channel ? "stable"
, gnomeSupport ? false, gnome ? null
, gnomeKeyringSupport ? false
, proprietaryCodecs ? true
, enablePepperFlash ? false
, enableWideVine ? false
, useVaapi ? false # Deprecated, use enableVaapi instead!
, enableVaapi ? false # Disabled by default due to unofficial support and issues on radeon
, useOzone ? false
, cupsSupport ? true
, pulseSupport ? config.pulseaudio or stdenv.isLinux
, commandLineArgs ? ""
}:

let
  llvmPackages = llvmPackages_10;
  stdenv = llvmPackages.stdenv;

  callPackage = newScope chromium;

  chromium = rec {
    inherit stdenv llvmPackages;

    upstream-info = (lib.importJSON ./upstream-info.json).${channel};

    mkChromiumDerivation = callPackage ./common.nix ({
      inherit channel gnome gnomeSupport gnomeKeyringSupport proprietaryCodecs
              cupsSupport pulseSupport useOzone;
      # TODO: Remove after we can update gn for the stable channel (backward incompatible changes):
      gnChromium = gn.overrideAttrs (oldAttrs: {
        version = "2020-05-19";
        src = fetchgit {
          url = "https://gn.googlesource.com/gn";
          rev = "d0a6f072070988e7b038496c4e7d6c562b649732";
          sha256 = "0197msabskgfbxvhzq73gc3wlr3n9cr4bzrhy5z5irbvy05lxk17";
        };
      });
    } // lib.optionalAttrs (lib.versionAtLeast upstream-info.version "86") {
      llvmPackages = llvmPackages_11;
      gnChromium = gn.overrideAttrs (oldAttrs: {
        version = "2020-07-20";
        src = fetchgit {
          url = "https://gn.googlesource.com/gn";
          rev = "3028c6a426a4aaf6da91c4ebafe716ae370225fe";
          sha256 = "0h3wf4152zdvrbb0jbj49q6814lfl3rcy5mj8b2pl9s0ahvkbc6q";
        };
      });
    } // lib.optionalAttrs (lib.versionAtLeast upstream-info.version "87") {
      useOzone = true; # YAY: https://chromium-review.googlesource.com/c/chromium/src/+/2382834 \o/
      gnChromium = gn.overrideAttrs (oldAttrs: {
        version = "2020-08-17";
        src = fetchgit {
          url = "https://gn.googlesource.com/gn";
          rev = "6f13aaac55a977e1948910942675c69f2b4f7a94";
          sha256 = "01hpma1sllpdx09mvr4d6073sg6zmk6iv44kd3r28khymcj4s251";
        };
      });
    });

    browser = callPackage ./browser.nix { inherit channel enableWideVine; };

    plugins = callPackage ./plugins.nix {
      inherit enablePepperFlash;
    };
  };

  pkgSuffix = if channel == "dev" then "unstable" else channel;
  pkgName = "google-chrome-${pkgSuffix}";
  chromeSrc = fetchurl {
    urls = map (repo: "${repo}/${pkgName}/${pkgName}_${version}-1_amd64.deb") [
      "https://dl.google.com/linux/chrome/deb/pool/main/g"
      "http://95.31.35.30/chrome/pool/main/g"
      "http://mirror.pcbeta.com/google/chrome/deb/pool/main/g"
      "http://repo.fdzh.org/chrome/deb/pool/main/g"
    ];
    sha256 = chromium.upstream-info.sha256bin64;
  };

  mkrpath = p: "${lib.makeSearchPathOutput "lib" "lib64" p}:${lib.makeLibraryPath p}";
  widevineCdm = stdenv.mkDerivation {
    name = "chrome-widevine-cdm";

    src = chromeSrc;

    nativeBuildInputs = [ patchelfUnstable ];

    phases = [ "unpackPhase" "patchPhase" "installPhase" "checkPhase" ];

    unpackCmd = let
      widevineCdmPath =
        if channel == "stable" then
          "./opt/google/chrome/WidevineCdm"
        else if channel == "beta" then
          "./opt/google/chrome-beta/WidevineCdm"
        else if channel == "dev" then
          "./opt/google/chrome-unstable/WidevineCdm"
        else
          throw "Unknown chromium channel.";
    in ''
      # Extract just WidevineCdm from upstream's .deb file
      ar p "$src" data.tar.xz | tar xJ "${widevineCdmPath}"

      # Move things around so that we don't have to reference a particular
      # chrome-* directory later.
      mv "${widevineCdmPath}" ./

      # unpackCmd wants a single output directory; let it take WidevineCdm/
      rm -rf opt
    '';

    doCheck = true;
    checkPhase = ''
      ! find -iname '*.so' -exec ldd {} + | grep 'not found'
    '';

    PATCH_RPATH = mkrpath [ gcc.cc glib nspr nss ];

    patchPhase = ''
      patchelf --set-rpath "$PATCH_RPATH" _platform_specific/linux_x64/libwidevinecdm.so
    '';

    installPhase = ''
      mkdir -p $out/WidevineCdm
      cp -a * $out/WidevineCdm/
    '';

    meta = {
      platforms = [ "x86_64-linux" ];
      license = lib.licenses.unfree;
    };
  };

  suffix = if channel != "stable" then "-" + channel else "";

  sandboxExecutableName = chromium.browser.passthru.sandboxExecutableName;

  version = chromium.browser.version;

  # We want users to be able to enableWideVine without rebuilding all of
  # chromium, so we have a separate derivation here that copies chromium
  # and adds the unfree WidevineCdm.
  chromiumWV = let browser = chromium.browser; in if enableWideVine then
    runCommand (browser.name + "-wv") { version = browser.version; }
      ''
        mkdir -p $out
        cp -a ${browser}/* $out/
        chmod u+w $out/libexec/chromium
        cp -a ${widevineCdm}/WidevineCdm $out/libexec/chromium/
      ''
    else browser;

  optionalVaapiFlags = if useVaapi # TODO: Remove after 20.09:
    then throw ''
      Chromium's useVaapi was replaced by enableVaapi and you don't need to pass
      "--ignore-gpu-blacklist" anymore (also no rebuilds are required anymore).
    '' else lib.optionalString
      (!enableVaapi)
      "--add-flags --disable-accelerated-video-decode --add-flags --disable-accelerated-video-encode";
in stdenv.mkDerivation {
  name = "chromium${suffix}-${version}";
  inherit version;

  buildInputs = [
    makeWrapper ed

    # needed for GSETTINGS_SCHEMAS_PATH
    gsettings-desktop-schemas glib gtk3

    # needed for XDG_ICON_DIRS
    gnome3.adwaita-icon-theme
  ];

  outputs = ["out" "sandbox"];

  buildCommand = let
    browserBinary = "${chromiumWV}/libexec/chromium/chromium";
    getWrapperFlags = plugin: "$(< \"${plugin}/nix-support/wrapper-flags\")";
    libPath = stdenv.lib.makeLibraryPath [ libva ];

  in with stdenv.lib; ''
    mkdir -p "$out/bin"

    eval makeWrapper "${browserBinary}" "$out/bin/chromium" \
      --add-flags ${escapeShellArg (escapeShellArg commandLineArgs)} \
      ${optionalVaapiFlags} \
      ${concatMapStringsSep " " getWrapperFlags chromium.plugins.enabled}

    ed -v -s "$out/bin/chromium" << EOF
    2i

    if [ -x "/run/wrappers/bin/${sandboxExecutableName}" ]
    then
      export CHROME_DEVEL_SANDBOX="/run/wrappers/bin/${sandboxExecutableName}"
    else
      export CHROME_DEVEL_SANDBOX="$sandbox/bin/${sandboxExecutableName}"
    fi

  '' + lib.optionalString (libPath != "") ''
    # To avoid loading .so files from cwd, LD_LIBRARY_PATH here must not
    # contain an empty section before or after a colon.
    export LD_LIBRARY_PATH="\$LD_LIBRARY_PATH\''${LD_LIBRARY_PATH:+:}${libPath}"
  '' + ''

    # libredirect causes chromium to deadlock on startup
    export LD_PRELOAD="\$(echo -n "\$LD_PRELOAD" | ${coreutils}/bin/tr ':' '\n' | ${gnugrep}/bin/grep -v /lib/libredirect\\\\.so$ | ${coreutils}/bin/tr '\n' ':')"

    export XDG_DATA_DIRS=$XDG_ICON_DIRS:$GSETTINGS_SCHEMAS_PATH\''${XDG_DATA_DIRS:+:}\$XDG_DATA_DIRS

    # Mainly for xdg-open but also other xdg-* tools:
    export PATH="${xdg_utils}/bin\''${PATH:+:}\$PATH"

    .
    w
    EOF

    ln -sv "${chromium.browser.sandbox}" "$sandbox"

    ln -s "$out/bin/chromium" "$out/bin/chromium-browser"

    mkdir -p "$out/share"
    for f in '${chromium.browser}'/share/*; do # hello emacs */
      ln -s -t "$out/share/" "$f"
    done
  '';

  inherit (chromium.browser) packageName;
  meta = chromium.browser.meta;
  passthru = {
    inherit (chromium) upstream-info browser;
    mkDerivation = chromium.mkChromiumDerivation;
    inherit chromeSrc sandboxExecutableName;
    updateScript = ./update.py;
  };
}
