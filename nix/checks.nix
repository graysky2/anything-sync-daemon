{self, ...}: {
  perSystem = {
    config,
    lib,
    pkgs,
    ...
  }: {
    checks = {
      default = config.checks.anything-sync-daemon;
      anything-sync-daemon = pkgs.testers.nixosTest {
        name = "anything-sync-daemon";

        nodes.asd = {
          config,
          lib,
          ...
        }: let
          common = {
            enable = true;
            resyncTimer = "3s";
            backupLimit = 2;
            useOverlayFS = true;
          };
        in {
          imports = [
            self.nixosModules.anything-sync-daemon
          ];

          security.sudo = {
            enable = true;
            extraRules = [
              {
                users = [config.users.users.asduser.name];
                commands = [
                  {
                    command = "${config.services.asd.package}/bin/asd-mount-helper";
                    options = ["NOPASSWD" "SETENV"];
                  }
                ];
              }
            ];
          };

          # `false` is the default; set it here anyway to document that we want
          # user processes (e.g. `asd-resync`) to persist after the user
          # session closes.
          services.logind.killUserProcesses = false;

          services.asd.system = lib.mkMerge [
            common

            {
              whatToSync = [
                "/var/lib/what-to-sync"
              ];
            }
          ];

          services.asd.user = lib.mkMerge [
            common

            {
              extraConfig = ''
                WHATTOSYNC=(
                  "''${HOME}/what-to-sync"
                )
              '';
            }
          ];

          users.users.asduser = {
            createHome = true;
            home = "/home/asduser";
            isNormalUser = true;
          };
        };

        testScript = {nodes, ...}: let
          user = nodes.asd.users.users.asduser.name;
        in ''
          start_all()

          asd.succeed('${./check.sh} setup foo bar baz')

          # In case `asd.service` bailed out before we could set up the
          # `WHATTOSYNC` directories.
          try:
            asd.wait_for_unit('asd.service')
          except:
            asd.stop_job('asd.service')
            asd.start_job('asd.service')
            asd.wait_for_unit('asd.service')

          asd.wait_for_unit('multi-user.target')

          # Ensure user session doesn't end when user logs out
          asd.succeed("loginctl enable-linger ${user}")

          asd.succeed('sudo -u ${user} ${./check.sh} setup foo bar baz')

          asd.start_job('asd.service', user='${user}')
          asd.wait_for_unit('asd.service', user='${user}')

          with subtest('ensuring target directories exists'):
            asd.wait_for_file('~${user}/what-to-sync')
            asd.wait_for_file('/var/lib/what-to-sync')

          with subtest('checking that files exist in backup and volatile storage'):
            asd.wait_until_succeeds('${./check.sh} before foo bar baz')
            asd.wait_until_succeeds('sudo -u ${user} ${./check.sh} before foo bar baz')

          with subtest('checking that resync propagates newly-created files'):
            asd.succeed('${./check.sh} setup quux corge grault')
            asd.succeed('sudo -u ${user} ${./check.sh} setup quux corge grault')

            asd.wait_until_succeeds('${./check.sh} before quux corge grault')
            asd.wait_until_succeeds('sudo -u ${user} ${./check.sh} before quux corge grault')

          with subtest('checking that files exist on durable storage after unit stop'):
            asd.stop_job('asd.service')
            asd.stop_job('asd.service', user='${user}')

            asd.wait_until_succeeds('${./check.sh} after foo bar baz quux corge grault')
            asd.wait_until_succeeds('sudo -u ${user} ${./check.sh} after foo bar baz quux corge grault')

          with subtest('checking that files exist in backup and volatile storage after restart'):
            asd.start_job('asd.service')
            asd.wait_for_unit('asd.service')

            asd.wait_for_unit('multi-user.target')
            asd.start_job('asd.service', user='${user}')
            asd.wait_for_unit('asd.service', user='${user}')

            asd.wait_until_succeeds('${./check.sh} before foo bar baz quux corge grault')
            asd.wait_until_succeeds('sudo -u ${user} ${./check.sh} before foo bar baz quux corge grault')

          with subtest('checking that crash recovery file is generated after hard crash'):
            for _ in range(${toString nodes.asd.services.asd.system.backupLimit} + 2):
              # ACHTUNG! `asd.succeed('sync')` is *vital* -- otherwise, the
              # system will break in any number of hilarious ways upon reboot.
              # For instance, `/var/lib/nixos/uid-map` (used by the
              # `update-users-groups.pl` script) appears to become corrupt.
              asd.succeed('sync')

              asd.crash()

              asd.wait_for_unit('asd.service')

            asd.wait_until_succeeds('env BACKUP_LIMIT=${toString nodes.asd.services.asd.system.backupLimit} ${./check.sh} crash')
            asd.wait_until_succeeds('sudo -u ${user} env BACKUP_LIMIT=${toString nodes.asd.services.asd.system.backupLimit} ${./check.sh} crash')
        '';
      };
    };
  };
}
