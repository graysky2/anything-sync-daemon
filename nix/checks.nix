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

        nodes.asd = {lib, ...}: let
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

          services.asd.system = lib.mkMerge [
            common

            {
              whatToSync = [
                "/var/lib/what-to-sync"
              ];
            }
          ];
        };

        testScript = {nodes, ...}: ''
          start_all()

          asd.succeed('mkdir -p /var/lib/what-to-sync 1>&2')
          asd.succeed("""
            for f in foo bar baz; do
              touch "/var/lib/what-to-sync/''${f}"
            done
          """)

          asd.wait_for_unit('asd.service')

          with subtest('ensuring target directory exists'):
            asd.wait_for_file('/var/lib/what-to-sync')

          with subtest('checking that files exist in backup and volatile storage'):
            for file in ['foo', 'bar', 'baz']:
              asd.wait_for_file(f'/run/asd/asd-root/var/lib/what-to-sync/{file}')
              asd.wait_for_file(f'/var/lib/.what-to-sync-backup_asd/{file}')

          with subtest('checking that resync propagates newly-created files'):
            asd.succeed("""
              for f in quux corge grault; do
                touch "/var/lib/what-to-sync/''${f}";
              done
            """)

            for file in ['quux', 'corge', 'grault']:
              asd.wait_for_file(f'/run/asd/asd-root/var/lib/what-to-sync/{file}')
              asd.wait_for_file(f'/var/lib/.what-to-sync-backup_asd/{file}')

          with subtest('checking that files exist on durable storage after unit stop'):
            asd.stop_job('asd.service')

            for file in ['foo', 'bar', 'baz', 'quux', 'corge', 'grault']:
              asd.wait_for_file(f'/var/lib/what-to-sync/{file}')

            asd.succeed("""
              for f in foo bar baz quux corge grault; do
                ! [ -f "/run/asd/asd-root/var/lib/what-to-sync/''${f}" ] || exit
              done 1>&2
            """)

          with subtest('checking that files exist in backup and volatile storage after restart'):
            asd.start_job('asd.service')
            asd.wait_for_unit('asd.service')

            for file in ['foo', 'bar', 'baz', 'quux', 'corge', 'grault']:
              asd.wait_for_file(f'/run/asd/asd-root/var/lib/what-to-sync/{file}')
              asd.wait_for_file(f'/var/lib/.what-to-sync-backup_asd/{file}')

          with subtest('checking that crash recovery file is generated after hard crash'):
            for _ in range(${toString nodes.asd.services.asd.system.backupLimit} + 2):
              # ACHTUNG! `asd.succeed('sync')` is *vital* -- otherwise, the
              # system will break in any number of hilarious ways upon reboot.
              # For instance, `/var/lib/nixos/uid-map` (used by the
              # `update-users-groups.pl` script) appears to become corrupt.
              asd.succeed('sync')

              asd.crash()

              asd.wait_for_unit('asd.service')

            asd.succeed("""
              i=0
              for cr in /var/lib/.what-to-sync-backup_asd-crashrecovery-*.tar.zstd; do
                if [[ -f "$cr" ]]; then
                  i="$(( i + 1 ))"
                fi
              done

              if [ "$i" -eq ${lib.escapeShellArg (toString nodes.asd.services.asd.system.backupLimit)} ]; then
                exit 0
              else
                exit 1
              fi
            """)
        '';
      };
    };
  };
}
