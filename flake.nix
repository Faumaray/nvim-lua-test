{
  description = "A collection of packages for the Nix package manager";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, ... }:
    rec {
      nixosModules = rec {
        neovim-lua = import ./nvim-lua/module.nix;
        default = neovim-lua;
      };
      overlay = final: prev:
        let
          pkgs = nixpkgs.legacyPackages.${prev.system};
        in
        rec {
          vimUtilsHybrid = final.callPackage ./nvim-lua/vim-utils.nix {
            inherit (pkgs.lua51Packages) hasLuaModule;
          };
          neovimLuaUtils = final.callPackage ./nvim-lua/utils.nix {
            inherit (pkgs.lua51Packages) buildLuarocksPackage;
          };
          wrapNeovimLuaUnstable = final.callPackage ./nvim-lua/wrapper.nix { };
          neovim-lua-unwrapped = final.callPackage ./nvim-lua {
            CoreServices = pkgs.darwin.apple_sdk.frameworks.CoreServices;
            lua = pkgs.luajit;
          };
          wrapNeovimLua = neovim-lua-unwrapped: pkgs.lib.makeOverridable (neovimLuaUtils.legacyWrapper neovim-lua-unwrapped);
          neovim-lua = wrapNeovim neovim-lua-unwrapped { };

        };
    };
}
