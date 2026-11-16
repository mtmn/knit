{
  lib,
  buildGoModule,
  go_1_27,
  src,
  version,
}:
buildGoModule.override {go = go_1_27;} {
  pname = "knit";
  inherit src version;

  vendorHash = "sha256-7czD/ysrW8LA08p+nAddZ6ldOguEldYcWDrbgF/cDYA=";

  subPackages = ["cmd/knit"];

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
