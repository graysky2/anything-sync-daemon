{self, ...}: {
  perSystem = {
    config,
    lib,
    pkgs,
    ...
  }: let
    mkTestScript = user: {nodes, ...}: ''
      from typing import cast, Optional, Tuple

      # To satisfy the type checker
      class MachineAugmented(Machine):
        def journalctl_as(self, q: str) -> str:
          return ""

        def start_job_as(self, jobname: str) -> Tuple[int, str]:
          return (0, "")

        def stop_job_as(self, jobname: str) -> Tuple[int, str]:
          return (0, "")

        def succeed_as(self, *commands: str, timeout: Optional[int] = None) -> str:
          return ""

        def systemctl_as(self, q: str) -> Tuple[int, str]:
          return (0, "")

        def wait_for_unit_as( self, unit: str, timeout: int = 900) -> None:
          return None

        def wait_until_succeeds_as(self, command: str, timeout: int = 900) -> str:
          return ""

      ${lib.optionalString (user == "root") ''
        def journalctl_as(self, q):
          return self.succeed(f'journalctl {q}')

        start_job_as = Machine.start_job
        stop_job_as = Machine.stop_job
        succeed_as = Machine.succeed
        systemctl_as = Machine.systemctl
        wait_for_unit_as = Machine.wait_for_unit
        wait_until_succeeds_as = Machine.wait_until_succeeds
      ''}

      ${lib.optionalString (user != "root") ''
        def wrap_command(command):
          return f"su -l ${user} --shell /bin/sh -c $'XDG_RUNTIME_DIR=/run/user/$(id -u) {command}'"

        def journalctl_as(self, q):
          return self.succeed(wrap_command(f'journalctl --user {q}'))

        def start_job_as(self, jobname):
          return self.start_job(jobname, user='${user}')

        def stop_job_as(self, jobname):
          return self.stop_job(jobname, user='${user}')

        def succeed_as(self, *commands, timeout = None):
          commands_as = [wrap_command(command) for command in commands]
          return self.succeed(*commands_as, timeout=timeout)

        def systemctl_as(self, q):
          return self.systemctl(q, user='${user}')

        def wait_for_unit_as(self, unit, timeout = 900):
          return self.wait_for_unit(unit, user='${user}', timeout=timeout)

        def wait_until_succeeds_as(self, command, timeout = 900):
          return self.wait_until_succeeds(wrap_command(command), timeout=timeout)
      ''}

      Machine.journalctl_as = journalctl_as # type: ignore
      Machine.start_job_as = start_job_as # type: ignore
      Machine.stop_job_as = stop_job_as # type: ignore
      Machine.succeed_as = succeed_as # type: ignore
      Machine.systemctl_as = systemctl_as # type: ignore
      Machine.wait_for_unit_as = wait_for_unit_as # type: ignore
      Machine.wait_until_succeeds_as = wait_until_succeeds_as # type: ignore

      start_all()

      # Stop MyPy from complaining about calling our monkeypatched mathods
      asd = cast(MachineAugmented, asd)

      ${lib.optionalString (user == "root") ''
        asd.succeed('${./check.sh} setup foo bar baz')

        # In case `asd.service` bailed out before we could set up the
        # `WHATTOSYNC` directories.
        try:
          asd.wait_for_unit_as('asd.service')
        except:
          asd.stop_job_as('asd.service')
          asd.start_job_as('asd.service')
          asd.wait_for_unit_as('asd.service')
      ''}

      ${lib.optionalString (user != "root") ''
        # Ensure user session doesn't end when user logs out
        asd.succeed("loginctl enable-linger ${user}")

        asd.succeed_as('${./check.sh} setup foo bar baz')

        asd.start_job_as('asd.service')
        asd.wait_for_unit_as('asd.service')
      ''}

      with subtest('ensuring target directories exists'):
        asd.wait_until_succeeds_as('${./check.sh} block')

      with subtest('checking that files exist in backup and volatile storage'):
        asd.wait_until_succeeds_as('${./check.sh} before foo bar baz')

      with subtest('checking that resync propagates newly-created files'):
        asd.succeed_as('${./check.sh} setup quux corge grault')
        asd.wait_until_succeeds_as('${./check.sh} before quux corge grault')

      with subtest('checking that files exist on durable storage after unit stop'):
        asd.stop_job_as('asd.service')
        asd.wait_until_succeeds_as('${./check.sh} after foo bar baz quux corge grault')

      with subtest('checking that files exist in backup and volatile storage after restart'):
        asd.start_job_as('asd.service')
        asd.wait_for_unit_as('asd.service')
        asd.wait_until_succeeds_as('${./check.sh} before foo bar baz quux corge grault')

      with subtest('checking that asd recovers from a partial mount scenario'):
        asd.wait_for_unit_as('asd.service')

        def check_partial_mount(op, msg):
          def _check_partial_mount(_):
            success = True

            try:
              asd.succeed_as('${./check.sh} {0} 1>&2'.format(op))
              asd.systemctl_as('restart asd-resync.timer')
              asd.journalctl_as('-b 0 --no-pager --unit="asd-resync.service" --grep="{0}" 1>&2'.format(msg))
              asd.journalctl_as('-b 0 --no-pager --unit="asd-resync.service" --grep="Inconsistent mount state" 1>&2')
              asd.journalctl_as('-b 0 --no-pager --unit="asd-resync.service" --grep="Ungraceful state detected" 1>&2')
            except Exception as e:
              asd.log('got exeception checking partial mount: {0}'.format(str(e)))
              success = False

            return success

          return _check_partial_mount

        cases = {
          'umountb': 'Sync target.*is currently unmounted',
          'umountv': 'Temporary directory.*is currently unmounted',
          'umountx': 'Backup directory.*is currently unmounted',
        }

        for op, msg in cases.items():
          retry(check_partial_mount(op, msg))

      with subtest('checking that asd recovers from wrongly-flagged tmp directories'):
        asd.stop_job_as('asd.service')
        asd.succeed_as('${./check.sh} flag')
        asd.start_job_as('asd.service')
        asd.wait_for_unit_as('asd.service')

      with subtest('checking that the expected number of crash recovery files are generated upon ungraceful state'):
        asd.wait_for_unit_as('asd.service')
        asd.stop_job_as('asd-resync.timer')
        asd.stop_job_as('asd-resync.service')

        # Simulate a crash by removing the `.flagged` file
        for _ in range(${toString nodes.asd.services.asd.system.backupLimit} + 2):
          asd.start_job_as('asd-resync.service')

          # Block until the directories are flagged
          asd.wait_until_succeeds_as('${./check.sh} flagged')

          asd.stop_job_as('asd-resync.service')

          asd.wait_until_succeeds_as('${./check.sh} unflag')

        asd.start_job_as('asd-resync.service')

        # Block until the directories are flagged
        asd.wait_until_succeeds_as('${./check.sh} flagged')

        # Restart `asd.service` to enforce limit on number of backups
        asd.stop_job_as('asd.service')
        asd.start_job_as('asd.service')

        asd.start_job_as('asd-resync.timer')

        asd.wait_until_succeeds_as('env BACKUP_LIMIT=${toString nodes.asd.services.asd.system.backupLimit} ${./check.sh} crash')
    '';
  in {
    checks = {
      default = config.checks.anything-sync-daemon-system;

      anything-sync-daemon-system = pkgs.testers.nixosTest {
        name = "anything-sync-daemon-user";

        #skipTypeCheck = true;

        nodes.asd = {
          imports = [
            self.nixosModules.example-profile
          ];

          services.asd.user.enable = lib.mkForce false;

          # Disable systemd's restart rate limiting to help avoid test failures
          # due to frequent unit restarts.
          systemd = {
            services = {
              asd.startLimitBurst = 0;
              asd-resync.startLimitBurst = 0;
            };

            timers.asd-resync.startLimitBurst = 0;
          };
        };

        testScript = {nodes, ...} @ args: mkTestScript "root" args;
      };

      anything-sync-daemon-user = pkgs.testers.nixosTest {
        name = "anything-sync-daemon-user";

        #skipTypeCheck = true;

        nodes.asd = {
          imports = [
            self.nixosModules.example-profile
          ];

          services.asd.system.enable = lib.mkForce false;

          # Disable systemd's restart rate limiting to help avoid test failures
          # due to frequent unit restarts.
          systemd.user = {
            services = {
              asd.startLimitBurst = 0;
              asd-resync.startLimitBurst = 0;
            };

            timers.asd-resync.startLimitBurst = 0;
          };
        };

        testScript = {nodes, ...} @ args: mkTestScript nodes.asd.users.users.asduser.name args;
      };

      docs =
        pkgs.runCommand "anything-sync-daemon-docs-check" {
          src = self;
        } ''
          current="''${src}/doc/nixos-modules.md"
          target=${config.packages.docs}

          if ! [ -f "$current" ]; then
            printf 1>&2 -- 'missing "%s"; please generate documentation with `mkoptdocs`.\n' "$current"
            exit 1
          elif ! ${pkgs.diffutils}/bin/cmp "$current" "$target"; then
            printf 1>&2 -- '"%s" and "%s" differ; please generate documentation with `mkoptdocs`.\n' "$current" "$target"
            exit 1
          else
            touch "$out"
          fi
        '';
    };
  };
}
