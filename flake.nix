{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
    nixpkgs-unstable.url = "nixpkgs";
  };

  outputs = {self, nixpkgs, nixpkgs-unstable}: let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    pkgs1 = nixpkgs-unstable.legacyPackages.x86_64-linux;

    scalaVersion = "2.13.10";
    chiselVersion = "5.0.0";

    scalaVersionM = pkgs.lib.concatStringsSep "."
      (pkgs.lib.take 2 (builtins.splitVersion scalaVersion));

    scala = pkgs.fetchurl {
       url = "https://downloads.lightbend.com/scala/${scalaVersion}/scala-${scalaVersion}.tgz";
       sha256="1i4w06bqx0s6v1jw8bf5j6xvllayyj83flsbqr160y6hkicn255h";
    };

    # generate from ./gen_deps.rb
    deps-json = (builtins.fromJSON (builtins.readFile ./deps.json)) // {
      "chisel-plugin_${scalaVersion}-${chiselVersion}.jar" = {
        url = "https://repo1.maven.org/maven2/org/chipsalliance/chisel-plugin_${scalaVersion}/${chiselVersion}/chisel-plugin_${scalaVersion}-${chiselVersion}.jar";
        sha256 = "1295zfk2a6jl917c622374jccx3ghy5idmh53lnxx1xvaifjbi1l";
      };
    };

    deps = pkgs.lib.mapAttrs (k: v: pkgs.fetchurl v) deps-json;

    deps-script = pkgs.writeShellScript "cp_deps.sh"
      (pkgs.lib.concatStringsSep "\n"
        (pkgs.lib.mapAttrsToList (name: src: "cp ${src} /opt/java/lib/${name}") deps));

    locales = pkgs.glibcLocales.override {
      allLocales = false;
      locales = ["en_US.UTF-8/UTF-8"];
    };
    chisel-base = with pkgs.dockerTools; buildImage {
        name = "chisel-base";
        tag = "v0.2";

        contents = with pkgs; [
          usrBinEnv
          binSh

          bashInteractive coreutils pkgs1.circt pkgs.jdk17_headless
          gnutar gzip gnugrep which
          locales

          ruby
        ];
    };
  in with pkgs.dockerTools; {
    packages.x86_64-linux = {
      default = self.packages.x86_64-linux.chisel;

      chisel = buildImage {
        name = "chisel";
        tag = "v0.3";

        diskSize = 3000;

        fromImage = chisel-base;

        runAsRoot = ''
        #!${pkgs.stdenv.shell} 
        ${shadowSetup}

        mkdir /opt
        cd /opt
        tar zxf ${scala}

        mkdir -p /opt/java/lib
        sh ${deps-script}

        cd /usr/bin
        for i in fsc scala scalac scalap scaladoc; do
           ln -s /opt/scala-${scalaVersion}/bin/$i
        done

        cd /opt/java/lib
        /usr/bin/scalac -cp /opt/java/lib/chisel_${scalaVersionM}-${chiselVersion}.jar ${./chisel2verilog.scala}
        /bin/jar cf chisel2verilog.jar chisel2verilog/*.class
        rm -rf chisel2verilog

        cp ${./entrypoint.rb} /entrypoint.rb
        '';

        config = {
          Entrypoint = ["/entrypoint.rb"];
          Env = [
            "LC_ALL=en_US.UTF-8"
            "LOCALE_ARCHIVE=/lib/locale/locale-archive"
          ];
        };
      };
    };
  };
}
