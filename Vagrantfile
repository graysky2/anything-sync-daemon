Vagrant.configure(2) do |config|
  config.vm.box = 'archlinux/archlinux'
  config.vm.provision 'install-systemd-all', type: 'shell' do |shell|
    shell.privileged = true

    # NOTE you should run `vagrant rsync` before provisioning in order to
    # ensure the files in `/vagrant` on the guest are up-to-date with the files
    # on the host machine.
    shell.inline = <<-INSTALL
      set -eu

      cd /vagrant

      pacman -Syyu --noconfirm
      pacman -S --noconfirm make man-db pandoc pv

      make uninstall-systemd-all || :
      rm -f /etc/asd.conf
      make install-systemd-all

      printf  -- '
        WHATTOSYNC=(/var/lib/pacman)
        USE_OVERLAYFS=1
      ' | sed 's/^[[:space:]]*//' > /etc/asd.conf

      systemctl daemon-reload
      systemctl enable --now asd.service || rc="$?"
      systemctl restart asd.service || rc="$?"

      systemctl status -l asd.service

      exit "${rc:-0}"
    INSTALL
  end
end
