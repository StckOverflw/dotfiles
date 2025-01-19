{ config, self, ... }:
let
  tikaPort = "33001";
  gotenbergPort = "33002";
in
{
  services.redis.servers.paperless = {
    enable = true;
    port = 0;
    user = "paperless";
  };

  services.postgresql = {
    ensureUsers = [
      {
        name = "paperless";
        ensureDBOwnership = true;
        ensureClauses.login = true;
      }
    ];
    ensureDatabases = ["paperless"];
  };

  services.paperless = {
    enable = true;
    user = "paperless";

    settings = {
      PAPERLESS_URL="https://paper.boecker.dev";

      PAPERLESS_ADMIN_USER = "emma";      

      PAPERLESS_DBENGINE = "postgresql";
      PAPERLESS_DBHOST = "/run/postgresql";
      PAPERLESS_DBNAME="paperless";

      PAPERLESS_REDIS="unix:///run/redis-paperless/redis.sock";

      PAPERLESS_TIKA_ENABLED = true;
      PAPERLESS_TIKA_ENDPOINT = "http://127.0.0.1:${tikaPort}";
      PAPERLESS_TIKA_GOTENBERG_ENDPOINT = "http://127.0.0.1:${gotenbergPort}";

      PAPERLESS_OCR_LANGUAGE = "deu+eng";

      PAPERLESS_TRUSTED_PROXIES = "127.0.0.1";
      PAPERLESS_USE_X_FORWARD_HOST = true;
      PAPERLESS_USE_X_FORWARD_PORT = true;

      PAPERLESS_ENABLE_COMPRESSION = false;
    };
  };

  systemd.services =
    let
      path = config.age.secrets.paperless-env.path;
    in
    {
      paperless-scheduler.serviceConfig.EnvironmentFile = path;
      paperless-task-queue.serviceConfig.EnvironmentFile = path;
      paperless-consumer.serviceConfig.EnvironmentFile = path;
      paperless-web.serviceConfig.EnvironmentFile = path;
    };
  age.secrets.paperless-env.file = "${self}/secrets/paperless-env.age";

  virtualisation.oci-containers.containers.gotenberg = {
    user = "gotenberg:gotenberg";
    image = "docker.io/gotenberg/gotenberg:8.15.3";
    ports = [
      "127.0.0.1:${gotenbergPort}:3000"
    ];
  };

  virtualisation.oci-containers.containers.tika = {
    image = "docker.io/apache/tika:2.9.2.1";
    ports = [
      "127.0.0.1:${toString tikaPort}:9998"
    ];
  };

  services.nginx.tailscaleAuth = {
    enable = true;
    virtualHosts = ["paper.boecker.dev"];
  };
  services.nginx.virtualHosts."paper.boecker.dev" = {
    locations."/" = {
      proxyPass = "http://localhost:28981";
      proxyWebsockets = true;
    };
  };
}