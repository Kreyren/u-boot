{ stdenv
, lib
, bc
, bison
, dtc
, fetchFromGitHub
, fetchpatch
, fetchurl
, flex
, gnutls
, installShellFiles
, libuuid
, meson-tools
, ncurses
, openssl
, swig
, which
, python3
, armTrustedFirmwareAllwinner
, armTrustedFirmwareAllwinnerH6
, armTrustedFirmwareAllwinnerH616
, armTrustedFirmwareRK3328
, armTrustedFirmwareRK3399
, armTrustedFirmwareS905
, buildPackages
}:

let
	inherit (lib)
		makeOverridable
		concatMapStrings
		;

	# Dependencies for the tools need to be included as either native or cross, depending on which we're building
	toolsDeps = [
		ncurses # tools/kwboot
		libuuid # tools/mkeficapsule
		gnutls # tools/mkeficapsule
		openssl # tools/mkimage
	];
in {
	flake.nixosModules.buildUBoot = makeOverridable ({
		pname ? "uboot-${defconfig}"
	,	version ? "2024.01" # Default version
	, src ? ((version: { # Switch
		"2024.01" = (fetchurl {
				url = "https://ftp.denx.de/pub/u-boot/u-boot-${version}.tar.bz2";
				hash = "sha256-a2pIWBwUq7D5W9h8GvTXQJIkBte4AQAqn5Ryf93gIdU=";
			});
		"2023.07.02" = (fetchurl {
				url = "https://ftp.denx.de/pub/u-boot/u-boot-${version}.tar.bz2";
				hash = "sha256-a2pIWBwUq7D5W9h8GvTXQJIkBte4AQAqn5Ryf93gIdU=";
			});
		# "VERSION" = (fetchurl {
		# 		url = "https://ftp.denx.de/pub/u-boot/u-boot-${version}.tar.bz2";
		# 		hash = "HASH";
		# 	});
	}).${version} or (throw "buildUboot does not have version ${version} integrated yet."))
	, filesToInstall
	, pythonScriptsToInstall ? { }
	, installDir ? "$out"
	, defconfig
	, extraConfig ? ""
	, extraPatches ? []
	, extraMakeFlags ? []
	, extraMeta ? {}
	, crossTools ? false
	, ... } @ args: stdenv.mkDerivation ({
		# Patch managemnt
		patches = [] ++ extraPatches;

		postPatch = ''
			${concatMapStrings (script: ''
				substituteInPlace ${script} \
				--replace "#!/usr/bin/env python3" \
					"#!${pythonScriptsToInstall.${script}}/bin/python3"
			'') (builtins.attrNames pythonScriptsToInstall)}
			patchShebangs tools
			patchShebangs scripts
		'';

		nativeBuildInputs = [
			ncurses # tools/kwboot
			bc
			bison
			flex
			installShellFiles
			(buildPackages.python3.withPackages (p: [
				p.libfdt
				p.setuptools # for pkg_resources
				p.pyelftools
			]))
			swig
			which # for scripts/dtc-version.sh
		] ++ lib.optionals (!crossTools) toolsDeps;

		depsBuildBuild = [ buildPackages.stdenv.cc ];

		buildInputs = lib.optionals crossTools toolsDeps;

		# FIXME-QA(Krey): Figure out hardening options
		hardeningDisable = [ "all" ];

		enableParallelBuilding = true;

		makeFlags = [
			"DTC=${lib.getExe buildPackages.dtc}"
			"CROSS_COMPILE=${stdenv.cc.targetPrefix}"
		] ++ extraMakeFlags;

		passAsFile = [ "extraConfig" ];

		configurePhase = ''
			runHook preConfigure

			make "${defconfig}"

			cat "$extraConfigPath" >> .config

			runHook postConfigure
		'';

		installPhase = ''
			runHook preInstall

			mkdir -p "${installDir}"
			cp -v ${lib.concatStringsSep " " (filesToInstall ++ builtins.attrNames pythonScriptsToInstall)} "${installDir}"

			mkdir -p "$out/nix-support"

			${lib.concatMapStrings (file: ''
				echo "file binary-dist ${installDir}/${builtins.baseNameOf file}" >> "$out/nix-support/hydra-build-products"
			'') (filesToInstall ++ builtins.attrNames pythonScriptsToInstall)}

			runHook postInstall
		'';

		meta = with lib; {
			homepage = "https://www.denx.de/wiki/U-Boot/";
			description = "Bootloader for embedded systems";
			license = licenses.gpl2;
			# maintainers = with maintainers; [ bartsch dezgeg samueldr lopsided98 ];
		} // extraMeta;
	} // removeAttrs args [ "extraMeta" "pythonScriptsToInstall" ]));
}
