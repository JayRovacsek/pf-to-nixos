{ stdenvNoCC, coreutils, yq, lib, writeShellScriptBin }:
with lib;
let
  name = "xml-to-json";
  version = "0.0.1";
  meta = {
    description = "A simple shell wrapper for xq";
    platforms = yq.meta.platforms;
  };

  xml-to-json-wrapped = writeShellScriptBin "xml-to-json" ''
    TARGET="$1"
    if [ -z "$TARGET" ]
    then
      echo "$0 - Error \$TARGET not set or NULL, use the first parameter to this script to define the target"
    else
      ${coreutils}/bin/cat $1 | ${yq}/bin/xq
    fi
  '';

  phases = [ "installPhase" "fixupPhase" ];

in stdenvNoCC.mkDerivation {
  inherit name version meta phases;

  buildInputs = [ xml-to-json-wrapped ];

  installPhase = ''
    mkdir -p $out/bin
    ln -s ${xml-to-json-wrapped}/bin/xml-to-json $out/bin
  '';
}
