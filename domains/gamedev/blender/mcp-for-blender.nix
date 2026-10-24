{
  lib,
  fetchurl,
  python3Packages,
}:

python3Packages.buildPythonApplication rec {
  pname = "mcp-for-blender";
  version = "2.2.3";
  pyproject = true;

  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/45/e3/d09f156a433c2bd259969e72c6458456f213e444762f502c91b41d692549/mcp_for_blender-${version}.tar.gz";
    hash = "sha256-g+eK6QNkTQOlXAylVJVBdc/ybt4Nym9dXbIGiV2O2jQ=";
  };

  build-system = [ python3Packages.setuptools ];
  dependencies = with python3Packages; [
    httpx
    mcp
  ];

  postInstall = ''
    install -Dm644 src/blender_mcp/bundled/addon.py \
      "$out/share/blender/scripts/addons/blender_mcp.py"
  '';

  meta = {
    description = "MCP server and Blender addon for controlling Blender from LLM clients";
    homepage = "https://github.com/ahujasid/mcp-for-blender";
    license = lib.licenses.mit;
    mainProgram = "mcp-for-blender";
  };
}
