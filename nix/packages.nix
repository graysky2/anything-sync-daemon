{self, ...}: {
  perSystem = {
    config,
    lib,
    pkgs,
    ...
  }: {
    packages = {
      default = config.packages.anything-sync-daemon;

      anything-sync-daemon = let
        # Although we explicitly wrap `anything-sync-daemon` to inject these
        # into `PATH`, we also declare them as build inputs in order to make
        # them appear in the `nix develop '.#anything-sync-daemon'` shell
        # environment.
        buildInputs = with pkgs; [
          coreutils
          findutils
          gawk
          gnugrep
          gnutar
          procps
          pv
          rsync
          utillinux
          zstd
        ];
      in
        pkgs.stdenv.mkDerivation {
          src = self;

          version = "6.0.0";

          pname = "anything-sync-daemon";

          inherit buildInputs;
          nativeBuildInputs = with pkgs; [makeWrapper pandoc];

          makeFlags = ["DESTDIR=$(out)" "PREFIX=/"];

          installTargets = ["install-systemd-all"];

          postPatch = ''
            substituteInPlace ./Makefile \
              --replace "systemctl" ": systemctl : " \
              --replace "sudo " ": sudo : "
          '';

          preInstall = ''
            mkdir -p $out/etc
          '';

          checkPhase = ''
            ${pkgs.shellcheck}/bin/shellcheck ./common/anything-sync-daemon.in -e SC1091
          '';

          postInstall = ''
            wrapProgram $out/bin/anything-sync-daemon --suffix PATH : "''${out}/bin" --suffix PATH : ${lib.makeBinPath buildInputs}
            wrapProgram $out/bin/asd-mount-helper --suffix PATH : ${lib.makeBinPath (with pkgs; [coreutils utillinux])}
          '';

          meta = {
            description = "";
            longDescription = ''
              Anything-sync-daemon (asd) is a tiny pseudo-daemon designed to
              manage user defined dirs in tmpfs and to periodically sync back to
              the physical disc (HDD/SSD). This is accomplished via a symlinking
              step and an innovative use of rsync to maintain back-up and
              synchronization between the two. One of the major design goals of
              asd is a completely transparent user experience.
            '';
            downloadPage = "https://github.com/graysky2/profile-sync-daemon/releases";
            license = lib.licenses.mit;
            platforms = lib.platforms.linux;
          };
        };
    };
  };
}
