{ self, pkgs, ... }:
let

  xml-to-json = pkgs.callPackage ./xml-to-json { };

in { inherit xml-to-json; }
