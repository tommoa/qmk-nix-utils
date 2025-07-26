{ pkgs, qmk-firmware-default-source, ... }:
{ src
, keyboard-name
, keymap-name
, keyboard-variant ? null
, flash-script ? null
, extra-build-inputs ? [ ]
, qmk-firmware-source ? qmk-firmware-default-source
, type ? "keyboard"
, avr ? true
, arm ? true
, teensy ? true
}:
with pkgs.stdenv;
let
  firmware-path = src;
  keyboard-path = if keyboard-variant != null then
    "${keyboard-name}/${keyboard-variant}"
  else "${keyboard-name}";

  qmk-with-keyboard-src = mkDerivation {
    name = "qmk-with-keyboard-src";
    src = qmk-firmware-source;
    srcs = firmware-path;
    phases = [ "installPhase" ];

    installPhase = let
      target_dir = if type == "keyboard" then
        "$out/keyboards/${keyboard-path}"
      else if type == "keymap" then
        "$out/keyboards/${keyboard-name}/keymaps/${keymap-name}"
      else throw "The only values valid for type are 'keyboard' and 'keymap'.";
    in ''
      mkdir "$out"
      cp -r "$src"/* "$out"
      chmod +w -R $out
      mkdir -p ${target_dir}
      chmod +w ${target_dir}
      cp -r ${firmware-path}/* ${target_dir}/
      chmod -w -R $out
    '';
  };

  hex = mkDerivation {
    name = "hex";
    nativeBuildInputs = with pkgs; extra-build-inputs ++ [
      qmk
    ];
    src = qmk-with-keyboard-src;

    buildPhase = ''
      SKIP_GIT=true SKIP_VERSION=true \
          qmk compile -kb ${keyboard-path} -km ${keymap-name}
    '';
    installPhase = ''
      mkdir $out
      cp -r .build/* $out
    '';
  };

  flasher =
    if builtins.isNull flash-script
    then builtins.throw "You need to pass a \"flash-script\" to \"utils-factory\""
    else
      pkgs.writeShellScriptBin "flasher" ''
        HEX_FILE=$(find ${hex}/ -type f -name "*.hex" | head -n 1)
        BIN_FILE=$(find ${hex}/ -type f -name "*.bin" | head -n 1)
        
        ${flash-script}
      '';

  dev-shell = import ./dev-shell.nix {
    inherit pkgs qmk-firmware-source keyboard-name firmware-path avr arm teensy;
  };

in
{
  inherit hex flasher dev-shell;
}

