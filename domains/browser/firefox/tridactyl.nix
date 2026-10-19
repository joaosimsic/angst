{ theme, config }:
let
  tridactylVars = [
    {
      name = "tridactyl-fg";
      value = theme.fg;
      important = false;
    }
    {
      name = "tridactyl-bg";
      value = theme.bg;
      important = false;
    }
    {
      name = "tridactyl-url-fg";
      value = theme.accent;
      important = false;
    }
    {
      name = "tridactyl-url-bg";
      value = theme.bg;
      important = false;
    }
    {
      name = "tridactyl-highlight-box-bg";
      value = theme.surface;
      important = false;
    }
    {
      name = "tridactyl-highlight-box-fg";
      value = theme.fgVariant;
      important = false;
    }
    {
      name = "tridactyl-of-fg";
      value = theme.fgVariant;
      important = false;
    }
    {
      name = "tridactyl-of-bg";
      value = theme.surfaceVariant;
      important = false;
    }
    {
      name = "tridactyl-cmdl-fg";
      value = theme.fgVariant;
      important = false;
    }
    {
      name = "tridactyl-cmdl-bg";
      value = theme.bgVariant;
      important = false;
    }
    {
      name = "tridactyl-cmdl-font-family";
      value = "monospace";
      important = false;
    }
    {
      name = "tridactyl-cmdl-font-size";
      value = "calc(12pt * 0.75)";
      important = false;
    }
    {
      name = "tridactyl-cmdl-line-height";
      value = "1.5";
      important = false;
    }
    {
      name = "tridactyl-cmplt-bg";
      value = theme.bg;
      important = false;
    }
    {
      name = "tridactyl-cmplt-fg";
      value = theme.fg;
      important = false;
    }
    {
      name = "tridactyl-cmplt-font-family";
      value = "monospace";
      important = false;
    }
    {
      name = "tridactyl-cmplt-font-size";
      value = "calc(12pt * 9/12)";
      important = false;
    }
    {
      name = "tridactyl-cmplt-option-height";
      value = "1.4em";
      important = false;
    }
    {
      name = "tridactyl-cmplt-border-top";
      value = "none";
      important = false;
    }
    {
      name = "tridactyl-status-fg";
      value = theme.fg;
      important = false;
    }
    {
      name = "tridactyl-status-bg";
      value = theme.bg;
      important = false;
    }
    {
      name = "tridactyl-status-border";
      value = "none";
      important = false;
    }
    {
      name = "tridactyl-status-border-radius";
      value = "2px";
      important = false;
    }
    {
      name = "tridactyl-status-font-family";
      value = "monospace";
      important = false;
    }
    {
      name = "tridactyl-status-font-size";
      value = "calc(12pt * 0.75)";
      important = false;
    }
    {
      name = "tridactyl-hint-fg";
      value = theme.bg;
      important = false;
    }
    {
      name = "tridactyl-hint-bg";
      value = theme.accent;
      important = false;
    }
    {
      name = "tridactyl-hint-outline";
      value = "none";
      important = false;
    }
    {
      name = "tridactyl-hint-active-fg";
      value = theme.bg;
      important = false;
    }
    {
      name = "tridactyl-hint-active-bg";
      value = theme.accentVariant;
      important = false;
    }
    {
      name = "tridactyl-hint-active-outline";
      value = "none";
      important = false;
    }
    {
      name = "tridactyl-hintspan-fg";
      value = theme.bg;
      important = true;
    }
    {
      name = "tridactyl-hintspan-bg";
      value = theme.accent;
      important = true;
    }
    {
      name = "tridactyl-hintspan-font-family";
      value = "sans-serif";
      important = false;
    }
    {
      name = "tridactyl-hintspan-font-size";
      value = "calc(12pt * 0.75)";
      important = false;
    }
    {
      name = "tridactyl-hintspan-font-weight";
      value = "bold";
      important = false;
    }
    {
      name = "tridactyl-hintspan-border-color";
      value = "transparent";
      important = false;
    }
    {
      name = "tridactyl-hintspan-border-width";
      value = "0px";
      important = false;
    }
    {
      name = "tridactyl-hintspan-border-style";
      value = "none";
      important = false;
    }
    {
      name = "tridactyl-scrollbar-color";
      value = "${theme.surface} ${theme.bg}";
      important = false;
    }
    {
      name = "tridactyl-photon-colours-accent-1";
      value = theme.accent;
      important = false;
    }
    {
      name = "tridactyl-photon-colours-accent-2";
      value = theme.accentVariant;
      important = false;
    }
    {
      name = "tridactyl-photon-colours-accent-3";
      value = theme.accentVariant;
      important = false;
    }
    {
      name = "tridactyl-photon-colours-in-content-page-background";
      value = theme.bg;
      important = false;
    }
    {
      name = "tridactyl-photon-colours-in-content-page-color";
      value = theme.fg;
      important = false;
    }
    {
      name = "tridactyl-photon-colours-in-content-box-background";
      value = theme.surface;
      important = false;
    }
    {
      name = "tridactyl-photon-colours-in-content-link-color";
      value = theme.accent;
      important = false;
    }
    {
      name = "tridactyl-photon-colours-in-content-text-color";
      value = theme.fgVariant;
      important = false;
    }
    {
      name = "tridactyl-photon-colours-cm-background";
      value = theme.bgVariant;
      important = false;
    }
    {
      name = "tridactyl-photon-colours-cm-selection";
      value = theme.surface;
      important = false;
    }
  ];

  mkLine = v: theme.mkVar v.name v.value v.important;
  cssVarsText = builtins.concatStringsSep "\n" (map mkLine tridactylVars);

  css = ''
    :root {
    ${cssVarsText}
    }
    #command-line-holder { order: 1; border: none !important; background: var(--tridactyl-cmdl-bg) !important; }
    #tridactyl-input { color: var(--tridactyl-cmdl-fg) !important; background: var(--tridactyl-cmdl-bg) !important; }
    #completions { --option-height: var(--tridactyl-cmplt-option-height); color: var(--tridactyl-cmplt-fg) !important; background: var(--tridactyl-cmplt-bg) !important; border: none !important; }
    #completions .focused { background: ${theme.accent} !important; color: ${theme.bg} !important; }
    #completions .focused .url { background: ${theme.accent} !important; color: ${theme.bg} !important; }
    .TridactylStatusIndicator { background: var(--tridactyl-status-bg) !important; color: var(--tridactyl-status-fg) !important; border: none !important; }
  '';

  rc = ''
    " === core settings — keyboard-only copy ===
    set smoothscroll true
    set hintchars 1234567890
    set yankto both
    set putfrom clipboard
    set yankto clipboard
    set visualenterauto true
    set visualexitauto true
    set hintfiltermode vimperator-reflow
    set hintnames numeric
    " --- navigation ---
    bind j scrollline 10
    bind k scrollline -10
    bind h scrollpx -50
    bind l scrollpx 50
    bind <C-d> scrollpage 0.5
    bind <C-u> scrollpage -0.5
    bind <C-f> scrollpage 1
    bind <C-b> scrollpage -1
    bind gg scrolltop
    bind G scrollbottom
    bind d tabclose
    bind u undo
    bind r reload
    bind R reloadhard
    " --- hints — open ---
    bind f hint
    bind F hint -b
    " --- hints — yank / copy (no mouse) ---
    bind yy clipboard yank
    bind ys clipboard yankshort
    bind yc clipboard yankcanon
    bind yt clipboard yanktitle
    bind ym clipboard yankmd
    bind ;y hint -y
    bind ;p hint -p
    bind ;P hint -P
    bind ;# hint -#
    bind ;h hint -h
    bind v hint -h
    bind V hint -h
    bind gy hint -y
    bind gp hint -p
    " --- open / search ---
    bind o fillcmdline open
    bind O fillcmdline tabopen
    bind b fillcmdline taball
    bind t fillcmdline tabopen
    bind / fillcmdline find
    bind n findnext 1
    bind N findnext -1
    bind s fillcmdline open search
    bind S fillcmdline tabopen search
    bind p clipboard open
    bind P clipboard tabopen
    " --- tabs / history ---
    bind gt tabnext
    bind gT tabprev
    bind H back
    bind L forward
    bind gh home
    bind gH tabopen home
    bind gu urlparent
    bind gU urlroot
    unbind <C-h>
    unbind <C-l>
    bind <C-h> tabprev
    bind <C-l> tabnext
    bind <C-1> tabnext_gt 1
    bind <C-2> tabnext_gt 2
    bind <C-3> tabnext_gt 3
    bind <C-4> tabnext_gt 4
    bind <C-5> tabnext_gt 5
    bind <C-6> tabnext_gt 6
    bind <C-7> tabnext_gt 7
    bind <C-8> tabnext_gt 8
    bind <C-9> tabnext_gt 9
    bind --mode=browser <C-1> tabnext_gt 1
    bind --mode=browser <C-2> tabnext_gt 2
    bind --mode=browser <C-3> tabnext_gt 3
    bind --mode=browser <C-4> tabnext_gt 4
    bind --mode=browser <C-5> tabnext_gt 5
    bind --mode=browser <C-6> tabnext_gt 6
    bind --mode=browser <C-7> tabnext_gt 7
    bind --mode=browser <C-8> tabnext_gt 8
    bind --mode=browser <C-9> tabnext_gt 9
    bind gi focusinput -l
    " --- visual mode — arbitrary sentence copy ---
    bind --mode=visual y composite js document.getSelection().toString() | clipboard yank
    bind --mode=visual Y composite js document.getSelection().toString() | clipboard yank; js window.getSelection().empty(); mode normal
    bind --mode=visual s composite js document.getSelection().toString() | fillcmdline open search
    bind --mode=visual S composite js document.getSelection().toString() | fillcmdline tabopen search
    bind --mode=visual h js document.getSelection().modify("extend","backward","character")
    bind --mode=visual l js document.getSelection().modify("extend","forward","character")
    bind --mode=visual j js document.getSelection().modify("extend","forward","line")
    bind --mode=visual k js document.getSelection().modify("extend","backward","line")
    bind --mode=visual w js document.getSelection().modify("extend","forward","word")
    bind --mode=visual b js document.getSelection().modify("extend","backward","word")
    bind --mode=visual e js document.getSelection().modify("extend","forward","word")
    bind --mode=visual 0 js document.getSelection().modify("extend","backward","lineboundary")
    bind --mode=visual $ js document.getSelection().modify("extend","forward","lineboundary")
    bind --mode=visual o js document.getSelection().modify("extend","backward","character"); js document.getSelection().modify("extend","forward","character")
    bind --mode=visual <Escape> composite js window.getSelection().empty(); mode normal; hidecmdline
    bind --mode=visual <C-c> composite js window.getSelection().empty(); mode normal; hidecmdline
    bind --mode=visual <C-[> composite js window.getSelection().empty(); mode normal; hidecmdline
    " --- mode resets ---
    bind --mode=normal <C-c> composite mode normal; hidecmdline
    bind --mode=insert <C-c> composite js document.activeElement.blur(); mode normal; hidecmdline
    bind --mode=input <C-c> composite js document.activeElement.blur(); mode normal; hidecmdline
    bind --mode=ex <C-c> ex.hide_and_clear
    bind --mode=hint <C-c> composite hint.reset; mode normal; hidecmdline
    bind --mode=ignore <C-c> composite mode normal; hidecmdline
    bind --mode=browser <C-c> composite mode normal; hidecmdline
    colours statusfg ${theme.fg}
    colours statusbg ${theme.bg}
    colours hintfg ${theme.bg}
    colours hintbg ${theme.accent}
    colourscheme --url file://${config.home.homeDirectory}/.config/tridactyl/themes/angst.css angst
  '';
in
{
  inherit css rc;
  vars = tridactylVars;
}
