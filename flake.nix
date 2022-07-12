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
          vimUtilsHybrid = final.callPackage ./neovim-lua/vim-utils.nix {
            inherit (pkgs.lua51Packages) hasLuaModule;
          };
          neovimLuaUtils = final.callPackage ./neovim-lua/utils.nix {
            inherit (pkgs.lua51Packages) buildLuarocksPackage;
          };
          wrapNeovimLuaUnstable = final.callPackage ./neovim-lua/wrapper.nix { };
          neovim-lua-unwrapped = final.callPackage ./neovim-lua {
            CoreServices = pkgs.darwin.apple_sdk.frameworks.CoreServices;
            lua = pkgs.luajit;
          };
          wrapNeovimLua = neovim-lua-unwrapped: pkgs.lib.makeOverridable (neovimLuaUtils.legacyWrapper neovim-lua-unwrapped);
          neovim-lua = wrapNeovimLua neovim-lua-unwrapped { };

        };
    };
}
