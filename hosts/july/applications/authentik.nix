{
  self,
  config,
  ...
}: let
  image = "ghcr.io/goauthentik/server:2024.12.2";

  mkEnvironemt = {
    AUTHENTIK_POSTGRESQL__HOST = "/run/postgresql";
    AUTHENTIK_POSTGRESQL__NAME = "authentik";
    AUTHENTIK_POSTGRESQL__USER = "authentik";
    AUTHENTIK_POSTGRESQL__PORT = "5432";

    AUTHENTIK_REDIS__HOST = "localhost";
    AUTHENTIK_REDIS__PORT = "6379";

    AUTHENTIK_LISTEN__HTTP = "0.0.0.0:9000";
    AUTHENTIK_FOOTER_LINKS = "[{\"name\": \"Emma Website :3\",\"href\":\"https://www.boecker.dev\"}]";

    AUTHENTIK_DEFAULT_USER_CHANGE_EMAIL = "true";
    AUTHENTIK_DEFAULT_USER_CHANGE_USERNAME = "true";

    AUTHENTIK_AVATARS = "gravatar,initials";
  };
in {
  users.users.authentik = {
    isSystemUser = true;
    group = "authentik";
    uid = 985;
  };
  users.groups.authentik = {
    gid = 982;
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/authentik/media/ 0770 authentik authentik -"
  ];

  age.secrets.authentik-secrets = {
    file = "${self}/secrets/authentik-secrets.age";
    owner = "authentik";
    group = "authentik";
  };

  services.postgresql = {
    ensureUsers = [
      {
        name = "authentik";
        ensureDBOwnership = true;
      }
    ];
    ensureDatabases = ["authentik"];
  };

  virtualisation.oci-containers.containers = {
    authentik-server = {
      image = image;

      cmd = ["server"];

      environmentFiles = [
        config.age.secrets.authentik-secrets.path
      ];

      environment = mkEnvironemt;

      volumes = [
        "/run/postgresql:/run/postgresql:ro"
        "/var/lib/authentik/media/:/media/"
      ];

      extraOptions = [
        "--network=host"
      ];

      user = "${toString config.users.users.authentik.uid}:${toString config.users.groups.authentik.gid}";
    };
    authentik-worker = {
      image = image;

      cmd = ["worker"];

      dependsOn = ["authentik-server"];

      environmentFiles = [
        config.age.secrets.authentik-secrets.path
      ];
      environment = mkEnvironemt;

      volumes = [
        "/run/postgresql:/run/postgresql:ro"
        "/var/lib/authentik/media/:/media/"
      ];

      extraOptions = [
        "--network=host"
      ];

      user = "${toString config.users.users.authentik.uid}:${toString config.users.groups.authentik.gid}";
    };
  };

  systemd.services.podman-authentik-server = {
    after = ["network-online.target" "postgresql.service"];
    wants = ["network-online.target" "postgresql.service"];
  };

  systemd.services.podman-authentik-worker = {
    after = ["network-online.target" "postgresql.service"];
    wants = ["network-online.target" "postgresql.service"];
  };

  services.nginx.virtualHosts."sso.boecker.dev" = {
    locations."/" = {
      proxyPass = "http://localhost:9000";
      proxyWebsockets = true;
    };
  };
}
