args @ { fetchurl, ... }:
rec {
  baseName = ''cl-opengl'';
  version = ''20190710-git'';

  description = ''Common Lisp bindings to OpenGL.'';

  deps = [ args."alexandria" args."babel" args."cffi" args."documentation-utils" args."float-features" args."trivial-features" args."trivial-indent" ];

  src = fetchurl {
    url = ''http://beta.quicklisp.org/archive/cl-opengl/2019-07-10/cl-opengl-20190710-git.tgz'';
    sha256 = ''0642jik5s9d6wnrwbv47s1jya1ddczs4a7z7plv06pcl9bqwngj5'';
  };

  packageName = "cl-opengl";

  asdFilesToKeep = ["cl-opengl.asd"];
  overrides = x: x;
}
/* (SYSTEM cl-opengl DESCRIPTION Common Lisp bindings to OpenGL. SHA256
    0642jik5s9d6wnrwbv47s1jya1ddczs4a7z7plv06pcl9bqwngj5 URL
    http://beta.quicklisp.org/archive/cl-opengl/2019-07-10/cl-opengl-20190710-git.tgz
    MD5 d9f5d5cf9a0a756dff27aec1164a1830 NAME cl-opengl FILENAME cl-opengl DEPS
    ((NAME alexandria FILENAME alexandria) (NAME babel FILENAME babel)
     (NAME cffi FILENAME cffi)
     (NAME documentation-utils FILENAME documentation-utils)
     (NAME float-features FILENAME float-features)
     (NAME trivial-features FILENAME trivial-features)
     (NAME trivial-indent FILENAME trivial-indent))
    DEPENDENCIES
    (alexandria babel cffi documentation-utils float-features trivial-features
     trivial-indent)
    VERSION 20190710-git SIBLINGS (cl-glu cl-glut-examples cl-glut) PARASITES
    NIL) */
