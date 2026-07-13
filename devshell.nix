{ pkgs }:

pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    bun
    nodejs
  ];

  packages = with pkgs; [
    typescript
    eslint
    prettier
  ];

  shellHook = ''
    export PATH="$PWD/ui/node_modules/.bin:$PATH"
  '';
}
