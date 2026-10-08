{ lib, pkgs }:

let
  src = pkgs.fetchFromGitHub {
    owner = "osmontero";
    repo = "opencode-skills";
    rev = "c269996b62c8a8f245264851e24110b46c9d8863";
    hash = "sha256-ZZs0K3k8VNcd3Jjcg0/xcw7phkRwS2DnwqcS8CgJ1L4=";
  };

  cavemanSrc = pkgs.fetchFromGitHub {
    owner = "JuliusBrussee";
    repo = "caveman";
    rev = "2e08b9177c07bb7249a8a2d1a6758e5db281d002";
    hash = "sha256-przOot/S0VLw2aP3tOdxF27mZHMp0NQhyTls0eDAjjs=";
  };

  skillNames = [
    "designing-frontend-interfaces"
    "designing-user-experience"
    "building-accessible-interfaces"
    "reviewing-interface-quality"
  ];

  cavemanSkill = "caveman";

  missing = builtins.filter (n: !(builtins.pathExists "${src}/skills/${n}/SKILL.md")) skillNames;
in
if missing != [ ] then
  throw "domains/agents/opencode/skills.nix: missing SKILL.md for ${lib.concatStringsSep ", " missing} at pinned rev"
else if !(builtins.pathExists "${cavemanSrc}/skills/${cavemanSkill}/SKILL.md") then
  throw "domains/agents/opencode/skills.nix: missing SKILL.md for ${cavemanSkill} at pinned rev"
else
  builtins.listToAttrs (
    map (name: {
      name = "opencode/skills/${name}";
      value.source = "${src}/skills/${name}";
    }) skillNames
    ++ [
      {
        name = "opencode/skills/${cavemanSkill}";
        value.source = "${cavemanSrc}/skills/${cavemanSkill}";
      }
    ]
  )
