{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.neovim-lua;

  runtime' = filter (f: f.enable) (attrValues cfg.runtime);

  runtime = pkgs.linkFarm "neovim-runtime" (map (x: { name = x.target; path = x.source; }) runtime');

in
{
  options.programs.neovim-lua = {
    enable = mkEnableOption "Neovim";

    defaultEditor = mkOption {
      type = types.bool;
      default = false;
      description = ''
        When enabled, installs neovim and configures neovim to be the default editor
        using the EDITOR environment variable.
      '';
    };

    lua = mkOption {
      type = types.bool;
      default = true;

    };

    viAlias = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Symlink <command>vi</command> to <command>nvim</command> binary.
      '';
    };

    vimAlias = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Symlink <command>vim</command> to <command>nvim</command> binary.
      '';
    };

    withRuby = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Ruby provider.";
    };

    withPython3 = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Python 3 provider.";
    };

    withNodeJs = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Node provider.";
    };

    configure = mkOption {
      type = types.attrs;
      default = { };
      example = literalExpression ''
        {
          customRC = '''
            " here your custom configuration goes!
          ''';
          packages.myVimPackage = with pkgs.vimPlugins; {
            # loaded on launch
            start = [ fugitive ];
            # manually loadable by calling `:packadd $plugin-name`
            opt = [ ];
          };
        }
      '';
      description = ''
        Generate your init file from your list of plugins and custom commands.
        Neovim will then be wrapped to load <command>nvim -u /nix/store/<replaceable>hash</replaceable>-vimrc</command>
      '';
    };

    extraConfig = mkOption {
	type = types.lines;
	default = '''';
	description = ''
		Extra configuration goes to init file;
		Alternative to configure.customRC
	'';

	    };

    plugins = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Plugins to be autoloaded";
      example = literalExpression ''
        with pkgs.vimPlugins; [ dracula-vim ]
      '';
    };

    optionalPlugins = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Optional plugins";
      example = literalExpression ''
        with pkgs.vimPlugins; [ dracula-vim ]
      '';
    };

    packages = mkOption {
      type = types.attrsOf (types.submodule ({
        options.start = mkOption {
          type = types.listOf types.package;
          default = [ ];
          description = "Plugins to be autoloaded";
          example = literalExpression ''
            with pkgs.vimPlugins; [ dracula-vim ]
          '';
        };

        options.opt = mkOption {
          type = types.listOf types.package;
          default = [ ];
          description = "Optional plugins";
          example = literalExpression ''
            with pkgs.vimPlugins; [ dracula-vim ]
          '';
        };
      }));
      default = { };
      description = "Attributes gets passed to 'configure.packages'";
      example = literalExpression ''
        with pkgs.vimPlugins; {
          start = [ ];
          opt = [];
        };
      '';
    };

    package = mkOption {
      type = types.package;
      default = pkgs.neovim-lua-unwrapped;
      defaultText = literalExpression "pkgs.neovim-lua-unwrapped";
      description = "The package to use for the neovim binary.";
    };

    finalPackage = mkOption {
      type = types.package;
      visible = false;
      readOnly = true;
      description = "Resulting customized neovim package.";
    };

    runtime = mkOption {
      default = { };
      example = literalExpression ''
        { "ftplugin/c.vim".text = "setlocal omnifunc=v:lua.vim.lsp.omnifunc"; }
      '';
      description = ''
        Set of files that have to be linked in <filename>runtime</filename>.
      '';

      type = with types; attrsOf (submodule (
        { name, config, ... }:
        {
          options = {

            enable = mkOption {
              type = types.bool;
              default = true;
              description = ''
                Whether this /etc file should be generated.  This
                option allows specific /etc files to be disabled.
              '';
            };

            target = mkOption {
              type = types.str;
              description = ''
                Name of symlink.  Defaults to the attribute
                name.
              '';
            };

            text = mkOption {
              default = null;
              type = types.nullOr types.lines;
              description = "Text of the file.";
            };

            source = mkOption {
              type = types.path;
              description = "Path of the source file.";
            };

          };

          config = {
            target = mkDefault name;
            source = mkIf (config.text != null) (
              let name' = "neovim-runtime" + baseNameOf name;
              in mkDefault (pkgs.writeText name' config.text)
            );
          };

        }
      ));

    };
  };
  config = mkIf cfg.enable {
    environment.systemPackages = [
      cfg.finalPackage
    ];
    environment.variables.EDITOR = mkIf cfg.defaultEditor (mkOverride 900 "nvim");
    programs.neovim-lua.finalPackage = pkgs.wrapNeovimLua cfg.package {
      inherit (cfg) viAlias vimAlias lua withPython3 withNodeJs withRuby;
      configure = cfg.configure // {
        packages.plugins.start = cfg.plugins;
        customRC = (cfg.extraConfig or cfg.configure.customRC or "");
      };
    };
  };
}
