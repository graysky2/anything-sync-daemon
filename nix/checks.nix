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
          imports = [
            self.nixosModules.example-profile
          ];
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

          with subtest('checking that asd recovers from a partial mount scenario'):
            asd.wait_for_unit('asd.service')
            asd.wait_for_unit('asd.service', user='${user}')

            def check_partial_mount_root(op, msg):
              def _check_partial_mount_root(_):
                success = True

                try:
                  asd.succeed('${./check.sh} {0} 1>&2'.format(op))
                  asd.systemctl('restart asd-resync.timer')
                  asd.succeed('journalctl -b 0 --no-pager --unit="asd-resync.service" --grep="{0}" 1>&2'.format(msg))
                  asd.succeed('journalctl -b 0 --no-pager --unit="asd-resync.service" --grep="Inconsistent mount state" 1>&2')
                  asd.succeed('journalctl -b 0 --no-pager --unit="asd-resync.service" --grep="Ungraceful state detected" 1>&2')
                except:
                  success = False

                return success

              return _check_partial_mount_root

            def check_partial_mount_user(op, msg):
              def _check_partial_mount_user(_):
                success = True

                try:
                  asd.succeed('sudo -u ${user} ${./check.sh} {0} 1>&2'.format(op))
                  asd.systemctl('restart asd-resync.timer', user='${user}')
                  asd.succeed('sudo -u ${user} journalctl -b 0 --no-pager --user --unit="asd-resync.service" --grep="{0}" 1>&2'.format(msg))
                  asd.succeed('sudo -u ${user} journalctl -b 0 --no-pager --user --unit="asd-resync.service" --grep="Inconsistent mount state" 1>&2')
                  asd.succeed('sudo -u ${user} journalctl -b 0 --no-pager --user --unit="asd-resync.service" --grep="Ungraceful state detected" 1>&2')
                except:
                  success = False

                return success

              return _check_partial_mount_user

            cases = {
              'umountb': 'Sync target.*is currently unmounted',
              'umountv': 'Temporary directory.*is currently absent',
              'umountx': 'Backup directory.*is currently unmounted',
            }

            for op, msg in cases.items():
              retry(check_partial_mount_root(op, msg))
              retry(check_partial_mount_user(op, msg))

          with subtest('checking that asd recovers from wrongly-flagged tmp directories'):
            asd.stop_job('asd.service')
            asd.stop_job('asd.service', user='${user}')

            asd.succeed('${./check.sh} flag')
            asd.succeed('sudo -u ${user} ${./check.sh} flag')

            asd.start_job('asd.service')
            asd.start_job('asd.service', user='${user}')

            asd.wait_for_unit('asd.service')
            asd.wait_for_unit('asd.service', user='${user}')

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
