{ modulesPath, lib, disko, nixpkgs, ... }:
{
  imports =
    [
      "${modulesPath}/profiles/qemu-guest.nix"
      "${modulesPath}/profiles/headless.nix"
      ./hardware.nix
      disko.nixosModules.default
    ];

  boot.loader.grub.devices = [ "/dev/vda" ];

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      KbdInteractiveAuthentication = false;
    };
  };

  networking.firewall.allowedTCPPorts = [
    22 80 443
  ];

  security.sudo.wheelNeedsPassword = false;

  time.timeZone = "Europe/Berlin";

  users.users.emma = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
    ];
  	openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIh+tAKie4OOkzxIwprEcQHiaL4ifkJKcSeN3bytV1rZ stckoverflw@gmail.com"
    ];
  };
  system.stateVersion = "23.11";

  disko.devices = import ./disk-config.nix {
    inherit lib;
  };

  nix = {
    settings = {
      experimental-features = ["nix-command" "flakes"];
      trusted-users = ["@wheel"];
    };
    registry.nixpkgs.flake = nixpkgs;
    nixPath = [
      "nixpkgs=${nixpkgs}"
    ];
  };
}
