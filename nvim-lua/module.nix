{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.home-manager.programs.neovim-lua;

  jsonFormat = pkgs.formats.json { };

  extraPython3PackageType = mkOptionType {
    name = "extra-python3-packages";
    description = "python3 packages in python.withPackages format";
    check = with types;
      (x: if isFunction x then isList (x pkgs.python3Packages) else false);
    merge = mergeOneOption;
  };

  # Currently, upstream Neovim is pinned on Lua 5.1 for LuaJIT support.
  # This will need to be updated if Neovim ever migrates to a newer
  # version of Lua.
  extraLua51PackageType = mkOptionType {
    name = "extra-lua51-packages";
    description = "lua5.1 packages in lua5_1.withPackages format";
    check = with types;
      (x: if isFunction x then isList (x pkgs.lua51Packages) else false);
    merge = mergeOneOption;
  };

  pluginWithConfigType = types.submodule {
    options = {
      config = mkOption {
        type = types.lines;
        description =
          "Script to configure this plugin. The scripting language should match type.";
        default = "";
      };

      type = mkOption {
        type =
          types.either (types.enum [ "lua" "viml" "teal" "fennel" ]) types.str;
        description =
          "Language used in config. Configurations are aggregated per-language.";
        default = "viml";
      };

      optional = mkEnableOption "optional" // {
        description = "Don't load by default (load with :packadd)";
      };

      plugin = mkOption {
        type = types.package;
        description = "vim plugin";
      };
    };
  };

  # A function to get the configuration string (if any) from an element of 'plugins'
  pluginConfig = p:
    if p ? plugin && (p.config or "") != "" then ''
      " ${p.plugin.pname or p.plugin.name} {{{
      ${p.config}
      " }}}
    '' else
      "";

  allPlugins = cfg.plugins ++ optional cfg.coc.enable {
    type = "viml";
    plugin = cfg.coc.package;
    config = cfg.coc.pluginConfig;
    optional = false;
  };

  moduleConfigure = {
    packages.home-manager = {
      start = remove null (map
        (x: if x ? plugin && x.optional == true then null else (x.plugin or x))
        allPlugins);
      opt = remove null
        (map (x: if x ? plugin && x.optional == true then x.plugin else null)
          allPlugins);
    };
    beforePlugins = "";
  };

  extraMakeWrapperArgs = lib.optionalString (cfg.extraPackages != [ ])
    ''--suffix PATH : "${lib.makeBinPath cfg.extraPackages}"'';
  extraMakeWrapperLuaCArgs = lib.optionalString (cfg.extraLuaPackages != [ ]) ''
    --suffix LUA_CPATH ";" "${
      lib.concatMapStringsSep ";" pkgs.lua51Packages.getLuaCPath
      cfg.extraLuaPackages
    }"'';
  extraMakeWrapperLuaArgs = lib.optionalString (cfg.extraLuaPackages != [ ]) ''
    --suffix LUA_PATH ";" "${
      lib.concatMapStringsSep ";" pkgs.lua51Packages.getLuaPath
      cfg.extraLuaPackages
    }"'';

in
{
  imports = [
    (mkRemovedOptionModule [ "programs" "neovim" "withPython" ]
      "Python2 support has been removed from neovim.")
    (mkRemovedOptionModule [ "programs" "neovim" "extraPythonPackages" ]
      "Python2 support has been removed from neovim.")
  ];

  options = {
    programs.neovim-lua = {
      enable = mkEnableOption "Neovim-Lua";

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

      vimdiffAlias = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Alias <command>vimdiff</command> to <command>nvim -d</command>.
        '';
      };

      withNodeJs = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable node provider. Set to <literal>true</literal> to
          use Node plugins.
        '';
      };

      withRuby = mkOption {
        type = types.nullOr types.bool;
        default = true;
        description = ''
          Enable ruby provider.
        '';
      };

      withPython3 = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable Python 3 provider. Set to <literal>true</literal> to
          use Python 3 plugins.
        '';
      };

      extraPython3Packages = mkOption {
        type = with types; either extraPython3PackageType (listOf package);
        default = (_: [ ]);
        defaultText = literalExpression "ps: [ ]";
        example = literalExpression "(ps: with ps; [ python-language-server ])";
        description = ''
          A function in python.withPackages format, which returns a
          list of Python 3 packages required for your plugins to work.
        '';
      };

      extraLuaPackages = mkOption {
        type = with types; either extraLua51PackageType (listOf package);
        default = [ ];
        defaultText = literalExpression "[ ]";
        example = literalExpression "(ps: with ps; [ luautf8 ])";
        description = ''
          A function in lua5_1.withPackages format, which returns a
          list of Lua packages required for your plugins to work.
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

      configure = mkOption {
        type = types.attrsOf types.anything;
        default = { };
        example = literalExpression ''
          configure = {
              customRC = $''''
              " here your custom configuration goes!
              $'''';
              packages.myVimPackage = with pkgs.vimPlugins; {
                # loaded on launch
                start = [ fugitive ];
                # manually loadable by calling `:packadd $plugin-name`
                opt = [ ];
              };
            };
        '';
        description = ''
          Deprecated. Please use the other options.
          Generate your init file from your list of plugins and custom commands,
          and loads it from the store via <command>nvim -u /nix/store/hash-vimrc</command>
          </para><para>
          This option is mutually exclusive with <varname>extraConfig</varname>
          and <varname>plugins</varname>.
        '';
      };

      extraConfig = mkOption {
        type = types.lines;
        default = "";
        example = ''
          set nocompatible
          set nobackup
        '';
        description = ''
          Custom vimrc lines.
          </para><para>
          This option is mutually exclusive with <varname>configure</varname>.
        '';
      };

      extraPackages = mkOption {
        type = with types; listOf package;
        default = [ ];
        example = literalExpression "[ pkgs.shfmt ]";
        description = "Extra packages available to nvim.";
      };

      plugins = mkOption {
        type = with types; listOf (either package pluginWithConfigType);
        default = [ ];
        example = literalExpression ''
          with pkgs.vimPlugins; [
            yankring
            vim-nix
            { plugin = vim-startify;
              config = "let g:startify_change_to_vcs_root = 0";
            }
          ]
        '';
        description = ''
          List of vim plugins to install optionally associated with
          configuration to be placed in init.vim.
          </para><para>
          This option is mutually exclusive with <varname>configure</varname>.
        '';
      };
    };
  };

  config =
    let
      # transform all plugins into an attrset
      pluginsNormalized = map
        (x:
          if (x ? plugin) then
            x
          else {
            type = x.type or "viml";
            plugin = x;
            config = "";
            optional = false;
          })
        allPlugins;
      suppressNotVimlConfig = p:
        if p.type != "viml" then p // { config = ""; } else p;

      neovimConfig = pkgs.neovimLuaUtils.makeNeovimConfig {
        inherit (cfg) extraPython3Packages lua withPython3 withRuby viAlias vimAlias;
        withNodeJs = cfg.withNodeJs;
        configure = cfg.configure // moduleConfigure;
        plugins = map suppressNotVimlConfig pluginsNormalized;
        customRC = cfg.extraConfig;
      };

    in
    mkIf cfg.enable {
      warnings = optional (cfg.configure != { }) ''
        programs.neovim-lua.configure is deprecated.
        Other programs.neovim options can override its settings or ignore them.
        Please use the other options at your disposal:
          configure.packages.*.opt  -> programs.neovim-lua.plugins = [ { plugin = ...; optional = true; }]
          configure.packages.*.start  -> programs.neovim-lua.plugins = [ { plugin = ...; }]
          configure.customRC -> programs.neovim-lua.extraConfig
      '';


      home.packages = [ cfg.finalPackage ];

      xdg.configFile =
        if cfg.lua then {
          "nvim/init.vim" = mkIf (neovimConfig.neovimRcContent != "") {
            text =
              if hasAttr "lua" config.programs.neovim.generatedConfigs then
                neovimConfig.neovimRcContent + ''
                  lua require('init-home-manager')''
              else
                neovimConfig.neovimRcContent;
          };
        } else {
          "nvim/init.lua" = mkIf (neovimConfig.neovimRcContent != "") {
            text =
              if hasAttr "lua" config.programs.neovim.generatedConfigs then
                neovimConfig.neovimRcContent + ''
                  require('init-home-manager')''
              else
                neovimConfig.neovimRcContent;
          };
        };
      xdg.configFile."nvim/lua/init-home-manager.lua" =
        mkIf (hasAttr "lua" config.programs.neovim-lua.generatedConfigs) {
          text = config.programs.neovim-lua.generatedConfigs.lua;
        };

      programs.neovim-lua.finalPackage = pkgs.wrapNeovimLuaUnstable cfg.package
        (neovimConfig // {
          wrapperArgs = (lib.escapeShellArgs neovimConfig.wrapperArgs) + " "
            + extraMakeWrapperArgs + " " + extraMakeWrapperLuaCArgs + " "
            + extraMakeWrapperLuaArgs;
          wrapRc = false;
        });

      programs.bash.shellAliases = mkIf cfg.vimdiffAlias { vimdiff = "nvim -d"; };
      programs.fish.shellAliases = mkIf cfg.vimdiffAlias { vimdiff = "nvim -d"; };
      programs.zsh.shellAliases = mkIf cfg.vimdiffAlias { vimdiff = "nvim -d"; };
    };
}
