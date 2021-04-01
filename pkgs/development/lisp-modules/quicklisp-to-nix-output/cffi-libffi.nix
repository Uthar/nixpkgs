args @ { fetchurl, ... }:
rec {
  baseName = ''cffi-libffi'';
  version = ''cffi_0.20.1'';

  description = ''Foreign structures by value'';

  deps = [ args."alexandria" args."babel" args."cffi" args."cffi-grovel" args."cffi-toolchain" args."trivial-features" ];

  src = fetchurl {
    url = ''http://beta.quicklisp.org/archive/cffi/2019-07-10/cffi_0.20.1.tgz'';
    sha256 = ''0ppcwc61ww1igmkwpvzpr9hzsl8wpf8acxlamq5r0604iz07qhka'';
  };

  packageName = "cffi-libffi";

  asdFilesToKeep = ["cffi-libffi.asd"];
  overrides = x: x;
}
/* (SYSTEM cffi-libffi DESCRIPTION Foreign structures by value SHA256
    0ppcwc61ww1igmkwpvzpr9hzsl8wpf8acxlamq5r0604iz07qhka URL
    http://beta.quicklisp.org/archive/cffi/2019-07-10/cffi_0.20.1.tgz MD5
    b8a8337465a7b4c1be05270b777ce14f NAME cffi-libffi FILENAME cffi-libffi DEPS
    ((NAME alexandria FILENAME alexandria) (NAME babel FILENAME babel)
     (NAME cffi FILENAME cffi) (NAME cffi-grovel FILENAME cffi-grovel)
     (NAME cffi-toolchain FILENAME cffi-toolchain)
     (NAME trivial-features FILENAME trivial-features))
    DEPENDENCIES
    (alexandria babel cffi cffi-grovel cffi-toolchain trivial-features) VERSION
    cffi_0.20.1 SIBLINGS
    (cffi-examples cffi-grovel cffi-tests cffi-toolchain cffi-uffi-compat cffi)
    PARASITES NIL) */
