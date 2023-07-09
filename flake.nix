{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";
    nixpkgs-unstable.url = "nixpkgs";
  };

  outputs = {self, nixpkgs, nixpkgs-unstable}: let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    pkgs1 = nixpkgs-unstable.legacyPackages.x86_64-linux;

    scala = pkgs.fetchurl {
       url = https://downloads.lightbend.com/scala/2.13.10/scala-2.13.10.tgz;
       sha256="1i4w06bqx0s6v1jw8bf5j6xvllayyj83flsbqr160y6hkicn255h";
    };

    # generate from ./gen_deps.rb
    deps-json = (builtins.fromJSON (builtins.readFile ./deps.json)) // {
      "chisel-plugin_2.13.10-5.0.0-RC2.jar" = {
        url = https://repo1.maven.org/maven2/org/chipsalliance/chisel-plugin_2.13.10/5.0.0-RC2/chisel-plugin_2.13.10-5.0.0-RC2.jar;
        sha256 = "0qq3nskzx2z4dnx2gwgz4dvs42209w4yd1fzpd5l7jw6pk98gzq4";
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
        tag = "v0.1";

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
        tag = "v0.2";

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
           ln -s /opt/scala-2.13.10/bin/$i
        done

        cd /opt/java/lib
        /usr/bin/scalac -cp /opt/java/lib/chisel_2.13-5.0.0-RC2.jar ${./chisel2verilog.scala}
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
