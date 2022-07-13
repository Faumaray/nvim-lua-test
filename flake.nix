{
  description = "A collection of packages for the Nix package manager";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, ... }:
    rec {
      nixosModules = rec {
        neovim-lua = import ./lib/module.nix;
        default = neovim-lua;
      };
      overlay = final: prev:
        let
          pkgs = nixpkgs.legacyPackages.${prev.system};
        in
        rec {
          vimUtilsHybrid = final.callPackage ./lib/plugins/vim-utils.nix {
            inherit (pkgs.lua51Packages) hasLuaModule;
          };
          neovimLuaUtils = final.callPackage ./lib/neovim/utils.nix {
            inherit (pkgs.lua51Packages) buildLuarocksPackage;
          };
          wrapNeovimLuaUnstable = final.callPackage ./lib/neovim/wrapper.nix { };
          neovim-lua-unwrapped = final.callPackage ./lib/neovim {
            CoreServices = pkgs.darwin.apple_sdk.frameworks.CoreServices;
            lua = pkgs.luajit;
          };
          wrapNeovimLua = neovim-lua-unwrapped: pkgs.lib.makeOverridable (neovimLuaUtils.legacyWrapper neovim-lua-unwrapped);
          neovim-lua = wrapNeovimLua neovim-lua-unwrapped { };

        };
    };
}
