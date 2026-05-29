{
  config,
  pkgs,
  lib,
  domain ? null,
  ...
}:
let
  hostname = config.networking.hostName;

  mkTraefikLabels =
    {
      name,
      port,
      specialSubdomain ? null,
      passthrough ? false,
      isPublic ? true,
      allowedPaths ? null,
      corsAllowPost ? false,
      useForwardAuth ? false,
    }:
    let
      subdomain = if specialSubdomain != null then specialSubdomain else name;
      localRule = "Host(`${subdomain}.${hostname}.local`)";

      pathRules =
        if allowedPaths != null then
          let
            pathConditions = map (path: "PathPrefix(`${path}`)") allowedPaths;
            pathString = lib.concatStringsSep " || " pathConditions;
          in
          " && (${pathString})"
        else
          "";

      publicRule = "Host(`${subdomain}.${domain}`)${pathRules}";
      publicTcpRule = "HostSNI(`${subdomain}.${domain}`)";

      local = {
        "traefik.enable" = "true";
        "traefik.http.services.${name}.loadbalancer.server.port" = port;

        "traefik.http.routers.${name}-local.entrypoints" = "web";
        "traefik.http.routers.${name}-local.rule" = localRule;
        "traefik.http.routers.${name}-local.service" = name;
      };

      public =
        if !isPublic then
          { }
        else if passthrough then
          {
            "traefik.tcp.routers.${name}-public.entrypoints" = "websecure";
            "traefik.tcp.routers.${name}-public.rule" = publicTcpRule;
            "traefik.tcp.routers.${name}-public.tls.passthrough" = "true";
            "traefik.tcp.routers.${name}-public.service" = name;
          }
        else
          let
            corsMiddleware =
              if corsAllowPost then
                { "traefik.http.routers.${name}-public.middlewares" = "cors-allow-post@file"; }
              else
                { };
            forwardAuthMiddleware =
              if useForwardAuth then
                { "traefik.http.routers.${name}-public.middlewares" = "authentik-forward-auth@file"; }
              else
                { };
          in
          corsMiddleware
          // forwardAuthMiddleware
          // {
            "traefik.http.routers.${name}-public.entrypoints" = "websecure";
            "traefik.http.routers.${name}-public.rule" = publicRule;
            "traefik.http.routers.${name}-public.tls.certresolver" = "myresolver";
            "traefik.http.routers.${name}-public.tls.domains[0].main" = "${subdomain}.${domain}";
            "traefik.http.routers.${name}-public.service" = name;

            "traefik.http.routers.${name}-public-http.entrypoints" = "web";
            "traefik.http.routers.${name}-public-http.rule" = publicRule;
            "traefik.http.routers.${name}-public-http.middlewares" = "redirect-to-https@docker";
            "traefik.http.middlewares.redirect-to-https.redirectscheme.scheme" = "https";
          };
    in
    local // public;

  parseDockerImageReference =
    imageStr:
    let
      partsAt = lib.splitString "@" imageStr;
      beforeAt = builtins.elemAt partsAt 0;
      digest = builtins.elemAt partsAt 1;

      partsColon = lib.splitString ":" beforeAt;
      name = builtins.elemAt partsColon 0;
      tag = builtins.elemAt partsColon 1;
    in
    {
      name = name;
      tag = tag;
      digest = digest;
    };

  processContainers =
    rawContainers:
    lib.mapAttrs (
      containerName: containerConfig:
      let
        hasRawImage = builtins.hasAttr "rawImageReference" containerConfig;
        hasNixSha = builtins.hasAttr "nixSha256" containerConfig;
      in
      if hasRawImage && hasNixSha then
        let
          imageRef = parseDockerImageReference containerConfig.rawImageReference;
          imageFile = pkgs.dockerTools.pullImage {
            imageName = imageRef.name;
            imageDigest = imageRef.digest;
            finalImageTag = imageRef.tag;
            sha256 = containerConfig.nixSha256;
          };
          processedConfig = builtins.removeAttrs containerConfig [
            "rawImageReference"
            "nixSha256"
          ];
        in
        processedConfig
        // {
          image = imageRef.name + ":" + imageRef.tag;
          imageFile = imageFile;
        }
      else
        containerConfig
    ) rawContainers;

  fileScripts = lib.mapAttrsToList (file: permissions: {
    name = "create-${lib.escapeShellArg file}-file";
    value = ''
      mkdir -p ${dirOf file}
      touch ${file}
      chmod ${permissions} ${file}
    '';
  }) config.myVirtualization.dependencies.files;

  networkScripts = lib.mapAttrsToList (networkName: opts: {
    name = "create-${networkName}-network";
    value = ''
      ${pkgs.docker}/bin/docker network inspect ${networkName} >/dev/null 2>&1 || \
      ${pkgs.docker}/bin/docker network create ${opts} ${networkName}
    '';
  }) config.myVirtualization.networks;

  systemServicesList = lib.mapAttrsToList (serviceName: script: {
    name = serviceName;
    value = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = "30s";
      };
      inherit script;
    };
  }) config.myVirtualization.dependencies.systemServices;
in
{
  options.myVirtualization = {
    containers = lib.mkOption {
      type = lib.types.attrsOf lib.types.unspecified;
      default = { };
      description = "OCI container configurations contributed by service modules.";
    };

    networks = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Docker networks to create. The value is extra flags passed to `docker network create`.";
    };

    dependencies = {
      files = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Files to create at activation time. Key is the path, value is the chmod permissions string.";
      };

      systemServices = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Extra systemd services. Key is the service name, value is the shell script to run.";
      };
    };
  };

  config = {
    _module.args = { inherit mkTraefikLabels parseDockerImageReference; };

    system.activationScripts = lib.listToAttrs (fileScripts ++ networkScripts);

    systemd.services = lib.listToAttrs systemServicesList;

    virtualisation.oci-containers = {
      backend = "docker";
      containers = processContainers config.myVirtualization.containers;
    };
  };
}
