{ inputs, config, pkgs, outputs, lib, ... }:

let
  hd = config.home.homeDirectory;
  link = config.lib.file.mkOutOfStoreSymlink;
in
{

  nix = {
    package = pkgs.nix;
    settings.experimental-features = [ "nix-command" "flakes" ];
  };

  home.username = "njg";
  home.homeDirectory = "/home/njg";
  programs.git = {
    enable = true;
    userName = "Nathan Goldschmidt";
    userEmail = "nathan.goldschmidt@gmail.com";
  };

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "23.05"; # Please read the comment before changing.


  # allow install of unfree software (eg google chrome)
  nixpkgs.config.allowUnfree = true;

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    firefox
    google-chrome
    fuse
    sops
    gnupg
    rclone
    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    (writeShellScriptBin "my-hello"
      ''echo "Hello, ${config.home.username}!"
      ''
    )
    vim
    wget
    git
    ripgrep
    coreutils
    fd
    clang
    gnumake
    cmake
    ((emacsPackagesFor emacs28).emacsWithPackages (epkgs: [ epkgs.vterm
                                                            epkgs.pdf-tools
                                                            epkgs.djvu ]))
    (aspellWithDicts (dicts: with dicts; [ en en-computers en-science es]))
    nixfmt

    ghostscript
    mupdf
    imagemagick
    poppler_utils

    # for org mode in doom emacs
    texlive.combined.scheme-medium
    # required by +jupyter
    (python3.withPackages(ps: with ps; [jupyter]))
    shellcheck

    # for +roam2 option for org mode in doom emacs
    sqlite
    pandoc
    hugo
    graphviz

    starsector
  ];

  home.activation.emacs-org-link = lib.hm.dag.entryAfter ["writeBoundary"] ''
  $DRY_RUN_CMD ln -Tsf $VERBOSE_ARG $HOME/gdrive/org $HOME/org
  '';

  # manage dotfiles
  home.file = {
    # give mkOutOfStoreSymlink a full (not relative) path, otherwise the file is copied into the nix store
    "${hd}/.config/doom".source = link "${hd}/.config/home-manager/dotfiles/doom";
    "${hd}/.ssh/config".source = link "${hd}/.config/home-manager/dotfiles/ssh/config";
    "${hd}/.sops.yaml".source = link ./dotfiles/sops/dot-sops.yaml;
  };

  home = {
    sessionVariables = { TEST = "nate"; };
    sessionPath = [ "$HOME/.config/emacs/bin" ];
  };

  systemd.user.services.rclone-gdrive = {
      Unit = {
        Description = "rclone mount of google drive";
        AssertPathIsDirectory = "%h/gdrive";
        # sops-nix.service provides the config file for rclone
        After = [ "network.target" "sops-nix.service" ];
      };

      Service = {
        Type = "simple";
        ExecStart = "%h/.nix-profile/bin/rclone mount --vfs-cache-mode full nate-google: gdrive";
        ExecStop = "%h/.nix-profile/bin/fusermount -zu %h/gdrive";
        Restart = "on-failure";
        RestartSec = 15;
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
  };

  sops = {
    gnupg.home = "${hd}/.gnupg";
    secrets.rclone-gdrive = {
      sopsFile = ./secrets/rclone/rclone.conf.enc;
      format = "ini";
      path = "${hd}/.config/rclone/rclone.conf";
    };
    secrets.ssh-config-secret = {
      sopsFile = ./secrets/ssh/config.secret.enc;
      format = "binary";
      path = "${hd}/.ssh/config.secret";
    };
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
  programs.bash = {
    enable = true;
    bashrcExtra = ''
      unset __HM_SESS_VARS_SOURCED
      source "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
      export EDITOR=emacsclient
    '';
  };
  services.gpg-agent = {
    enable = true;
    defaultCacheTtl = 1800;
    enableSshSupport = true;
    pinentryFlavor = "emacs";
  };
}
