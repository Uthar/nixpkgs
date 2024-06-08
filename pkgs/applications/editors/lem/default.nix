{
  stdenv
, lib
, fetchFromGitHub
, makeWrapper
, sbcl
, SDL2
, SDL2_ttf
, SDL2_image
, ...
}:

let

  base16-themes = fetchFromGitHub {
    owner = "lem-project";
    repo = "lem-base16-themes";
    rev = "d7ece2372e94bca76bba7bfc5da3d05eaef31265";
    hash = "sha256-LOB2jhL8I533R3nZQrAmFqPMpIbrJf/NPZNZiyYe1YM=";
  };

  sbcl' = sbcl.withOverrides (self: super: {
    micros = sbcl.buildASDFSystem {
      pname = "micros";
      version = "trunk";
      src = fetchFromGitHub {
        owner = "lem-project";
        repo = "micros";
        rev = "9fc7f1e5b0dbf1b9218a3f0aca7ed46e90aa86fd";
        hash = "sha256-bLFqFA3VxtS5qDEVVi1aTFYLZ33wsJUf26bwIY46Gtw=";
      };
    };
    
    lem-mailbox = sbcl.buildASDFSystem {
      pname = "lem-mailbox";
      version = "trunk";
      src = fetchFromGitHub {
        owner = "lem-project";
        repo = "lem-mailbox";
        rev = "12d629541da440fadf771b0225a051ae65fa342a";
        hash = "sha256-hb6GSWA7vUuvSSPSmfZ80aBuvSVyg74qveoCPRP2CeI=";
      };
      lispLibs = with self; [
        bordeaux-threads
        bt-semaphore
        queues
        queues_dot_simple-cqueue
      ];
    };    
    
    async-process = sbcl.buildASDFSystem {
      pname = "async-process";
      version = "trunk";
      src = fetchFromGitHub {
        owner = "lem-project";
        repo = "async-process";
        rev = "9690530fc92b59636d9f17d821afa7697e7c8ca4";
        hash = "sha256-S9ZTIYcLz6lA14e7Og7xRcjBo4ZK4xs8xg8w89xzWtQ=";
      };
      lispLibs = with self; [
        cffi
      ];
    };
    
    rove = sbcl.buildASDFSystem {
      pname = "rove";
      version = "trunk";
      src = fetchFromGitHub {
        owner = "fukamachi";
        repo = "rove";
        rev = "b9a76a495498087afe77b32412273a2b0f487bc6";
        hash = "sha256-K1hgUSgDRnq4Otkyxl+uNL7/ihh+qavhzw4N7mS/500=";
      };
      lispLibs = with self; [
        cl-ppcre
        dissect
        bordeaux-threads
        trivial-gray-streams
      ];
    };
    
    sdl2 = sbcl.buildASDFSystem {
      pname = "sdl2";
      version = "trunk";
      src = fetchFromGitHub {
        owner = "lem-project";
        repo = "cl-sdl2";
        rev = "24dd7f238f99065b0ae35266b71cce7783e89fa7";
        hash = "sha256-ewMDcM3byCIprCvluEPgHD4hLv3tnUV8fjqOkVrFZSE=";
      };
      lispLibs = with self; [
        alexandria
        cl-autowrap
        cl-plus-c
        cl-ppcre
        trivial-channels
        trivial-features
      ] ++ (lib.optional stdenv.isDarwin self.cl-glut);
      nativeLibs = [
        SDL2
      ];
    };
    
    sdl2-ttf = sbcl.buildASDFSystem {
      pname = "sdl2-ttf";
      version = "trunk";
      src = fetchFromGitHub {
        owner = "lem-project";
        repo = "cl-sdl2-ttf";
        rev = "e61bb2119003d8ae7792d38aa11f7728d3ee5a00";
        hash = "sha256-C+9jNeJ/7HMXDrbxVA9tZWypq3OhiYA5yZon1MR7CJw=";
      };
      patches = [
        ./cl-sdl2-ttf-fix-compilation.patch
      ];
      lispLibs = with self; [
        alexandria
        defpackage-plus
        cl-autowrap
        sdl2
        cffi-libffi
        trivial-garbage
      ];
      nativeLibs = [
        SDL2_ttf
      ];
    };
    
    sdl2-image = sbcl.buildASDFSystem {
      pname = "sdl2-image";
      version = "trunk";
      src = fetchFromGitHub {
        owner = "lem-project";
        repo = "cl-sdl2-image";
        rev = "8734b0e24de9ca390c9f763d9d7cd501546d17d4";
        hash = "sha256-TNcPOBKlB5eTlHtDAW/hpkWDMZZ/sFCHnm7dapMm5lg=";
      };
      lispLibs = with self; [
        alexandria
        defpackage-plus
        cl-autowrap
        sdl2
      ];
      nativeLibs = [
        SDL2_image
      ];
    };
    
    jsonrpc = sbcl.buildASDFSystem {
      pname = "jsonrpc";
      version = "trunk";
      src = fetchFromGitHub {
        owner = "cxxxr";
        repo = "jsonrpc";
        rev = "7fb8e0a40b27c4138e7613e3dc0a335883c1c040";
        hash = "sha256-MlnYsmLrCvEMwspnELm3yfAdSzBBP8+S7Ai8zH1J09A=";
      };
      systems = [
        "jsonrpc"
        "jsonrpc/transport/stdio"
        "jsonrpc/transport/tcp"
      ];
      lispLibs = with self; [
        yason
        usocket
        bordeaux-threads
        alexandria
        dissect
        event-emitter
        chanl
        vom
        cl-ppcre
        dexador
        clack
        clack-handler-hunchentoot
        lack-request
        babel
        http-body
        cl_plus_ssl
        quri
        fast-io
        trivial-utf-8
      ];
    };

    lem-full = sbcl.buildASDFSystem {
      pname = "lem-full";
      version = "2.2.0-trunk";
      src = fetchFromGitHub {
        owner = "lem-project";
        repo = "lem";
        rev = "ca31053a7e45a608917f7bb2ccff426f9b4b0c94";
        hash = "sha256-KlnBzP4E3wuG4xxnI54Yr2QPHJaCXHodOVccCVpWudI=";
      };
      postConfigure = ''
        cp -r ${base16-themes} base16-themes
        chmod u+w -R base16-themes
        export CL_SOURCE_REGISTRY=$CL_SOURCE_REGISTRY:$(pwd)/base16-themes/
      '';
      buildInputs = [ sbcl ];
      doCheck = true;
      checkPhase = ''
        sbcl <<EOF
          (load "$asdfFasl/asdf.$faslExt")
          (asdf:load-system 'lem-tests)
          (rove:run "lem-tests")
        EOF
      '';
      lispLibs = with self; [
        rove
        trivial-package-local-nicknames
        cl-ansi-text
        
        iterate
        closer-mop
        trivia
        alexandria
        trivial-gray-streams
        trivial-types
        cl-ppcre
        micros
        inquisitor
        babel
        bordeaux-threads
        yason
        log4cl
        split-sequence
        str
        dexador
        lem-mailbox
        async-process
        usocket
        cl-change-case
        jsonrpc
        trivia_dot_level2
        quri
        cl-package-locks
        esrap
        parse-number
        swank
        _3bmd
        _3bmd-ext-code-blocks
        lisp-preprocessor
        trivial-ws
        trivial-open-browser
        iconv
      ];
      systems = [
        "lem"
        "lem-encodings-table"
        "lem-encodings"
        "lem-lisp-syntax"
        "lem-process"
        "lem-socket-utils"
        "lem-lsp-base"
        "lem-language-server"
        "lem-language-client"
        "lem/extensions"
        "lem-welcome"
        "lem-lsp-mode"
        "lem-vi-mode"
        "lem-lisp-mode"
        "lem-go-mode"
        "lem-swift-mode"
        "lem-c-mode"
        "lem-xml-mode"
        "lem-html-mode"
        "lem-python-mode"
        "lem-posix-shell-mode"
        "lem-js-mode"
        "lem-typescript-mode"
        "lem-json-mode"
        "lem-css-mode"
        "lem-rust-mode"
        "lem-paredit-mode"
        "lem-nim-mode"
        "lem-scheme-mode"
        "lem-patch-mode"
        "lem-yaml-mode"
        "lem-review-mode"
        "lem-asciidoc-mode"
        "lem-dart-mode"
        "lem-scala-mode"
        "lem-dot-mode"
        "lem-java-mode"
        "lem-haskell-mode"
        "lem-ocaml-mode"
        "lem-asm-mode"
        "lem-makefile-mode"
        "lem-shell-mode"
        "lem-sql-mode"
        "lem-base16-themes"
        "lem-elixir-mode"
        "lem-erlang-mode"
        "lem-documentation-mode"
        "lem-elisp-mode"
        "lem-markdown-mode"
        "lem-color-preview"
      ];
    };
  });

  lem-sdl2 = sbcl'.buildASDFSystem {
    pname = "lem-sdl2";
    version = "2.2.0-trunk";
    src = fetchFromGitHub {
      owner = "lem-project";
      repo = "lem";
      rev = "ca31053a7e45a608917f7bb2ccff426f9b4b0c94";
      hash = "sha256-KlnBzP4E3wuG4xxnI54Yr2QPHJaCXHodOVccCVpWudI=";
    };
    buildInputs = [ sbcl' makeWrapper ];
    lispLibs = with sbcl'.pkgs; [
      sdl2
      sdl2-ttf
      sdl2-image
      lem-full
      trivial-main-thread
    ];
    installPhase = ''
      mkdir -pv $out/bin
      sbcl <<EOF
        (load "$asdfFasl/asdf.$faslExt")
        (asdf:load-system 'lem-sdl2)
        (sb-ext:save-lisp-and-die "$out/bin/lem" :executable t :toplevel #'lem:main)
      EOF
      test -x $out/bin/lem
      wrapProgram $out/bin/lem --prefix LD_LIBRARY_PATH : $LD_LIBRARY_PATH
    '';
  };

in lem-sdl2
