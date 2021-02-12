{ stdenv, fetchurl, gettext }:

stdenv.mkDerivation rec {
  name = "attr-2.4.48";

  src = fetchurl {
    url = "mirror://savannah/attr/${name}.tar.gz";
    sha256 = "1rr4adzwax4bzr2c00f06zcsljv5y6p9wymz1g89ww7cb2rp5bay";
  };

  outputs = [ "bin" "dev" "out" "man" "doc" ];

  nativeBuildInputs = [ gettext ];

  patches = [
    # fix fakechroot: https://github.com/dex4er/fakechroot/issues/57
    (fetchurl {
      url = "https://git.savannah.nongnu.org/cgit/attr.git/patch/?id=14adc898a36948267bfe5c63b399996879e94c98";
      sha256 = "1g8sky52rjg9fpmrddza1af89s9qd4bzsbxqb7mc5bv8gyh10s1k";
    })
  ];

  postPatch = ''
    for script in install-sh include/install-sh; do
      patchShebangs $script
    done
  '';

  meta = with stdenv.lib; {
    homepage = "https://savannah.nongnu.org/projects/attr/";
    description = "Library and tools for manipulating extended attributes";
    platforms = platforms.linux;
    license = licenses.gpl2Plus;
  };
}
