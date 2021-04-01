args @ { fetchurl, ... }:
rec {
  baseName = ''cl-liballegro'';
  version = ''20181018-git'';

  description = ''Allegro 5 game programming library bindings for Common Lisp'';

  deps = [ args."alexandria" args."babel" args."cffi" args."cffi-grovel" args."cffi-libffi" args."cffi-toolchain" args."trivial-features" args."trivial-garbage" ];

  src = fetchurl {
    url = ''http://beta.quicklisp.org/archive/cl-liballegro/2018-10-18/cl-liballegro-20181018-git.tgz'';
    sha256 = ''1ngs4axlzh0ba55jy023ipgz7mnnk9qh9am0i4d2vh01j1xg917x'';
  };

  packageName = "cl-liballegro";

  asdFilesToKeep = ["cl-liballegro.asd"];
  overrides = x: x;
}
/* (SYSTEM cl-liballegro DESCRIPTION
    Allegro 5 game programming library bindings for Common Lisp SHA256
    1ngs4axlzh0ba55jy023ipgz7mnnk9qh9am0i4d2vh01j1xg917x URL
    http://beta.quicklisp.org/archive/cl-liballegro/2018-10-18/cl-liballegro-20181018-git.tgz
    MD5 2586db67394dc7ebafb4c31efc7b4ba8 NAME cl-liballegro FILENAME
    cl-liballegro DEPS
    ((NAME alexandria FILENAME alexandria) (NAME babel FILENAME babel)
     (NAME cffi FILENAME cffi) (NAME cffi-grovel FILENAME cffi-grovel)
     (NAME cffi-libffi FILENAME cffi-libffi)
     (NAME cffi-toolchain FILENAME cffi-toolchain)
     (NAME trivial-features FILENAME trivial-features)
     (NAME trivial-garbage FILENAME trivial-garbage))
    DEPENDENCIES
    (alexandria babel cffi cffi-grovel cffi-libffi cffi-toolchain
     trivial-features trivial-garbage)
    VERSION 20181018-git SIBLINGS NIL PARASITES NIL) */
