args @ { fetchurl, ... }:
rec {
  baseName = ''float-features'';
  version = ''20190710-git'';

  description = ''A portability library for IEEE float features not covered by the CL standard.'';

  deps = [ args."documentation-utils" args."trivial-indent" ];

  src = fetchurl {
    url = ''http://beta.quicklisp.org/archive/float-features/2019-07-10/float-features-20190710-git.tgz'';
    sha256 = ''078qwd2spqgaalv229kyfvkszjrqjrjqqbmkl1fsqyd4zl8h8y6a'';
  };

  packageName = "float-features";

  asdFilesToKeep = ["float-features.asd"];
  overrides = x: x;
}
/* (SYSTEM float-features DESCRIPTION
    A portability library for IEEE float features not covered by the CL standard.
    SHA256 078qwd2spqgaalv229kyfvkszjrqjrjqqbmkl1fsqyd4zl8h8y6a URL
    http://beta.quicklisp.org/archive/float-features/2019-07-10/float-features-20190710-git.tgz
    MD5 94d87f2cef635664423b6a418f19f3b9 NAME float-features FILENAME
    float-features DEPS
    ((NAME documentation-utils FILENAME documentation-utils)
     (NAME trivial-indent FILENAME trivial-indent))
    DEPENDENCIES (documentation-utils trivial-indent) VERSION 20190710-git
    SIBLINGS NIL PARASITES NIL) */
