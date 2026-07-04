{
  stdenv,
  callPackage,
  pkgs,
  inputs,
  stdPath,
  lib,
}:
let
  fixGlibBuildOverlay =
    (final: prev: {
      systemtap-sdt = final.runCommand "systemtap-sdt-stub" { } ''
        mkdir -p $out/include/sys
        touch $out/include/sys/sdt.h
      '';

      glib = prev.glib.overrideAttrs (old: {
          mesonFlags = (builtins.filter
              (flag: !(lib.hasPrefix "-Ddtrace" flag) && !(lib.hasPrefix "-Dsystemtap" flag))
              (old.mesonFlags or [ ])
            ) ++ [
              "-Ddtrace=disabled"
              "-Dsystemtap=disabled"
            ];

        buildInputs = builtins.filter
          (pkg: pkg.pname or "" != "libsystemtap")
          old.buildInputs;
        
        nativeBuildInputs = builtins.filter
          (pkg: pkg.pname or "" != "libsystemtap")
          old.nativeBuildInputs;
      });
    });

  patchedNixpkgs =
    (import inputs.nixpkgs {
      system = stdenv.hostPlatform.system;
      overlays = [
        fixGlibBuildOverlay
        (final: prev: {
          pkgsi686Linux = prev.pkgsi686Linux.extend fixGlibBuildOverlay;
          # buildPackages  = prev.buildPackages.extend fixGlibBuildOverlay;
        })
      ];
    });

  wineUnstable = patchedNixpkgs.wineWow64Packages.full;

  symlink = callPackage ./symlink.nix { };

  wineUnwrapped = symlink {
    wine = wineUnstable;
  };

  wrapWithPrefix = callPackage ./wrapWithPrefix.nix {
    inherit wineUnwrapped;
    stdPath = stdPath pkgs;
  };
in
{
  inherit wineUnwrapped;

  wine = wrapWithPrefix wineUnwrapped "wine";
  winetricks = wrapWithPrefix patchedNixpkgs.winetricks "winetricks";
  wineserver = wrapWithPrefix wineUnwrapped "wineserver";
}
