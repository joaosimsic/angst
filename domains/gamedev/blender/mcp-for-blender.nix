{
  lib,
  fetchurl,
  python3Packages,
}:

python3Packages.buildPythonApplication rec {
  pname = "mcp-for-blender";
  version = "2.2.2";
  pyproject = true;

  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/61/f5/2dbb6662804de487a8951a9f8fd124fc4ec576d5f5b0a84244f5ce9cc7bf/mcp_for_blender-${version}.tar.gz";
    hash = "sha256-j6l+iiydunDKH07QkGV4Ck0yuIve4d+9mcEZUSi1tnc=";
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
