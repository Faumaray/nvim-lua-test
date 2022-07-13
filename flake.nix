{
  description = "A collection of packages for the Nix package manager";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, ... }:
    rec {
      overlay = final: prev:
        let
          pkgs = nixpkgs.legacyPackages.${prev.system};
        in
        rec {
          vimUtils = final.callPackage ./nvim-lua/vim-utils.nix {
            inherit (pkgs.lua51Packages) hasLuaModule;
          };
          neovimUtils = final.callPackage ./nvim-lua/utils.nix {
            inherit (pkgs.lua51Packages) buildLuarocksPackage;
          };
          wrapNeovimUnstable = final.callPackage ./nvim-lua/wrapper.nix { };
          neovim-unwrapped = final.callPackage ./nvim-lua {
            CoreServices = pkgs.darwin.apple_sdk.frameworks.CoreServices;
            lua = pkgs.luajit;
          };
          wrapNeovim = neovim-unwrapped: pkgs.lib.makeOverridable (neovimUtils.legacyWrapper neovim-unwrapped);
          neovim = wrapNeovim neovim-unwrapped { };

        };
    };
}
