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

  services.pulseeffects.enable = true;

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [

    usbutils # better lsusb than default nixos
    yakuake
    gimp
    vlc
    firefox
    google-chrome
    fuse
    sops
    gnupg
    rclone
    autossh
    vim
    wget
    git
    gnugrep
    ripgrep
    fd
    gnumake
    cmake
    ((emacsPackagesFor emacs29).emacsWithPackages (epkgs: with epkgs; [ vterm
                                                                        saveplace-pdf-view
                                                                        pdf-tools
                                                                        nov
                                                                        djvu
                                                                        ripgrep ]))
     (aspellWithDicts (dicts: with dicts; [ en en-computers en-science es]))
    nodePackages.npm
    libtool
    nixfmt-classic

    file
    mtr
    sshfs

    ghostscript
    mupdf
    imagemagick
    poppler_utils
    sigil # epub
    calibre # ebook manager

    webcamoid
    yt-dlp
    audacity

    # for org mode in doom emacs
    texlive.combined.scheme-medium
    # required by +jupyter
    (python3.withPackages(ps: with ps; [ jupyter
                                           isort
                                           pytest ]))
    pipenv
    shellcheck

    clj-kondo

    # for +roam2 option for org mode in doom emacs
    sqlite
    pandoc
    hugo
    graphviz

    starsector
    libvirt
    virt-manager
    virtiofsd

    jdk17 ant ivy

    appimage-run
    qt6.full
    qtcreator
    qt6.qtdeclarative
    qt6.qtquick3d



    pulseaudio-dlna


    #  https://github.com/NixOS/nixpkgs/issues/186570
  #   (let cura5 = appimageTools.wrapType2 rec {
  #          name = "cura5";
  #          version = "5.7.0";
  #          src = fetchurl {
  #            url = "https://github.com/Ultimaker/Cura/releases/download/${version}/UltiMaker-Cura-${version}-linux-X64.AppImage";
  #            hash = "sha256-5PaBhPJKqa8LxEHTRNTLqkcIfC2PkqmTWx9c1+dc7k0=";
  #          };
  #          extraPkgs = pkgs: with pkgs; [ ];
  #        }; in writeScriptBin "cura" ''
  #     #! ${pkgs.bash}/bin/bash
  #     # AppImage version of Cura loses current working directory and treats all paths relateive to $HOME.
  #     # So we convert each of the files passed as argument to an absolute path.
  #     # This fixes use cases like `cd /path/to/my/files; cura mymodel.stl anothermodel.stl`.
  #     args=()
  #     for a in "$@"; do
  #       if [ -e "$a" ]; then
  #         a="$(realpath "$a")"
  #       fi
  #       args+=("$a")
  #     done
  #     exec "${cura5}/bin/cura5" "''${args[@]}"
  #   '')

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

  systemd.user.services.autossh-kilgore = {
    Unit = {
      Description = "ssh tunnel to kilgore";
      After = [ "network.target" ];
    };
   Service = {
     Type="simple";
     # TODO autossh doesn't work well with "ControlMaster yes/auto"
     ExecStart = ''%h/.nix-profile/bin/autossh -M 0 -o "ControlMaster no" \
                                                    -L 8080:localhost:8080 \
                                                    -L 8082:localhost:8082 \
                                                    -L 8083:localhost:8083 \
                                                    -N media@kilgore'';
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
      format = "binary";
      path = "${hd}/.config/rclone/rclone.conf";
    };
    secrets.ssh-config-secret = {
      sopsFile = ./secrets/ssh/config.secret.enc;
      format = "binary";
      path = "${hd}/.ssh/config.secret";
    };
  };

  # Specify default hypervisor for virt-manager
  dconf.settings = {
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = ["qemu:///system"];
      uris = ["qemu:///system"];
    };
  };



  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
  programs.bash = {
    enable = true;
    bashrcExtra = ''
      if [ -f /etc/bashrc ];
        then
        source /etc/bashrc
      fi
      unset __HM_SESS_VARS_SOURCED
      source "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
      export EDITOR=emacsclient
    '';
  };
  services.gpg-agent = {
    enable = true;
    defaultCacheTtl = 1800;
    enableSshSupport = true;
    # pinentryPackage = "emacs";
  };
}
