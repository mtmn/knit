{
  lib,
  buildGoModule,
  src,
  version,
}:

buildGoModule {
  pname = "knit";
  inherit src version;

  vendorHash = "sha256-+IZFydwchHIMIvYmIgZ0uJKjW4aVBFuj3SQk58I0z/g=";

  subPackages = [ "cmd/knit" ];

  ldflags = [
    "-s"
    "-w"
    "-X github.com/zyedidia/knit/info.Version=${version}"
  ];

  meta = {
    description = "Simple and flexible build tool using Lua, similar to make/mk";
    mainProgram = "knit";
    homepage = "https://github.com/zyedidia/knit";
    license = lib.licenses.mit;
  };
}
