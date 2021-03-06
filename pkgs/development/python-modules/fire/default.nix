{ stdenv, buildPythonPackage, fetchFromGitHub, fetchpatch, six, hypothesis, mock
, python-Levenshtein, pytest, termcolor, isPy27, enum34, isPy38 }:

buildPythonPackage rec {
  pname = "fire";
  version = "0.2.1";

  src = fetchFromGitHub {
    owner = "google";
    repo = "python-fire";
    rev = "v${version}";
    sha256 = "1r6cmihafd7mb6j3mvgk251my6ckb0sqqj1l2ny2azklv175b38a";
  };

  propagatedBuildInputs = [ six termcolor ] ++ stdenv.lib.optional isPy27 enum34;

  checkInputs = [ hypothesis mock python-Levenshtein pytest ];

  checkPhase = ''
    py.test
  '';

  meta = with stdenv.lib; {
    description = "A library for automatically generating command line interfaces";
    longDescription = ''
      Python Fire is a library for automatically generating command line
      interfaces (CLIs) from absolutely any Python object.

      * Python Fire is a simple way to create a CLI in Python.

      * Python Fire is a helpful tool for developing and debugging
        Python code.

      * Python Fire helps with exploring existing code or turning other
        people's code into a CLI.

      * Python Fire makes transitioning between Bash and Python easier.

      * Python Fire makes using a Python REPL easier by setting up the
        REPL with the modules and variables you'll need already imported
        and created.
    '';
    license = licenses.asl20;
    maintainers = with maintainers; [ leenaars ];
    broken = isPy38;
  };
}
