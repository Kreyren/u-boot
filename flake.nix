{
	description = "Das U-Boot!";

	inputs = {
		# Release inputs
		nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
		nixpkgs-staging-next.url = "github:nixos/nixpkgs/staging-next";
		nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-kreyren-crust.url = "github:kreyren/nixpkgs/crust";
    nixpkgs-kreyren-atf-test.url = "github:kreyren/nixpkgs/atf-test";

		# Principle inputs
		flake-parts.url = "github:hercules-ci/flake-parts";
		mission-control.url = "github:Platonic-Systems/mission-control";
		flake-root.url = "github:srid/flake-root";
	};

	outputs = inputs @ { self, ... }:
		inputs.flake-parts.lib.mkFlake { inherit inputs; } {
			imports = [
				inputs.flake-root.flakeModule
				inputs.mission-control.flakeModule
			];

			systems = [ "x86_64-linux" "aarch64-linux" "riscv64-linux" ];

			perSystem = { system, config, ... }: {
				# FIXME-QA(Krey): Move this to  a separate file somehow?
				# FIXME-QA(Krey): Figure out how to shorten the `inputs.nixpkgs-unstable.legacyPackages.${system}` ?
				## _module.args.nixpkgs = inputs.nixpkgs-unstable.legacyPackages.${system};
				## _module.args.nixpkgs = import inputs.nixpkgs { inherit system; };
				mission-control.scripts = {
					# Editors
					vscodium = {
						description = "VSCodium (Fully Integrated)";
						category = "Integrated Editors";
						exec = "${inputs.nixpkgs-unstable.legacyPackages.${system}.vscodium}/bin/codium ./default.code-workspace";
					};
					vim = {
						description = "vIM (Minimal Integration, fixme)";
						category = "Integrated Editors";
						exec = "${inputs.nixpkgs.legacyPackages.${system}.vim}/bin/vim .";
					};
					neovim = {
						description = "Neovim (Minimal Integration, fixme)";
						category = "Integrated Editors";
						exec = "${inputs.nixpkgs.legacyPackages.${system}.neovim}/bin/nvim .";
					};
					emacs = {
						description = "Emacs (Minimal Integration, fixme)";
						category = "Integrated Editors";
						exec = "${inputs.nixpkgs.legacyPackages.${system}.emacs}/bin/emacs .";
					};
					# Code Formating
					nixpkgs-fmt = {
						description = "Format Nix Files With The Standard Nixpkgs Formater";
						category = "Code Formating";
						exec = "${inputs.nixpkgs.legacyPackages.${system}.nixpkgs-fmt}/bin/nixpkgs-fmt .";
					};
					alejandra = {
						description = "Format Nix Files With The Uncompromising Nix Code Formatter (Not Recommended)";
						category = "Code Formating";
						exec = "${inputs.nixpkgs.legacyPackages.${system}.alejandra}/bin/alejandra .";
					};
				};
				devShells.default = inputs.nixpkgs.legacyPackages.${system}.mkShell {
					name = "U-Boot-devshell";
					nativeBuildInputs = [
						inputs.nixpkgs.legacyPackages.${system}.bashInteractive # For terminal
						inputs.nixpkgs.legacyPackages.${system}.nil # Needed for linting
						inputs.nixpkgs.legacyPackages.${system}.nixpkgs-fmt # Nixpkgs formatter
						inputs.nixpkgs.legacyPackages.${system}.git # Working with the codebase
						inputs.nixpkgs.legacyPackages.${system}.fira-code # For liquratures in code editors

						# Build Dependencies
						inputs.nixpkgs.legacyPackages.aarch64-linux.gnumake
						inputs.nixpkgs.legacyPackages.aarch64-linux.gcc
						inputs.nixpkgs.legacyPackages.aarch64-linux.dtc
						inputs.nixpkgs.legacyPackages.aarch64-linux.bison
						inputs.nixpkgs.legacyPackages.aarch64-linux.flex
						inputs.nixpkgs.legacyPackages.aarch64-linux.openssl
						inputs.nixpkgs.legacyPackages.aarch64-linux.ncurses # tools/kwboot
						inputs.nixpkgs.legacyPackages.aarch64-linux.bc
						inputs.nixpkgs.legacyPackages.aarch64-linux.swig
						inputs.nixpkgs.legacyPackages.aarch64-linux.which # scripts/dtc-version.sh
						(inputs.nixpkgs.legacyPackages.aarch64-linux.buildPackages.python3.withPackages (p: [
							p.libfdt
							p.setuptools # for pkg_resources
							p.pyelftools
						]))
					];
					inputsFrom = [ config.mission-control.devShell ];

					# Environmental Variables
					# NAME = "value";
				};

				formatter = inputs.nixpkgs.legacyPackages.${system}.nixpkgs-fmt;

				packages = {
					ubootOlimexA64Teres1 = inputs.nixpkgs-staging-next.legacyPackages.${system}.buildUBoot {
						defconfig = "teres_i_defconfig";
						extraMeta.platforms = ["aarch64-linux"];
						BL31 = "${inputs.nixpkgs-kreyren-atf-test.legacyPackages.aarch64-linux.armTrustedFirmwareAllwinner}/bl31.bin";
						SCP = "${inputs.nixpkgs-kreyren-crust.legacyPackages.${system}.pkgsCross.or1k.crustOlimexA64Teres1}/scp.bin";
						filesToInstall = ["u-boot-sunxi-with-spl.bin"];
					};
				};
			};
		};
}
