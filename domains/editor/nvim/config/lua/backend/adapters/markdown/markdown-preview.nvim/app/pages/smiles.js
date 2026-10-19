const aliases = new Set([
  'smiles',
  'skeletal',
  'lineangle',
  'line-angle',
  'molecule',
  'chem'
])

const drawerOptions = {
  width: 360,
  height: 240,
  padding: 12,
  bondLength: 26,
  compactDrawing: true
}

let smilesDrawerPromise

const escapeAttribute = (value) =>
  value
    .replace(/&/g, '&amp;')
    .replace(/"/g, '&quot;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')

const loadSmilesDrawer = () => {
  if (!smilesDrawerPromise) {
    smilesDrawerPromise = import('smiles-drawer').then((module) => module.default || module)
  }
  return smilesDrawerPromise
}

const showError = (element, smiles) => {
  element.textContent = ''
  const code = document.createElement('code')
  code.textContent = `Invalid SMILES: ${smiles}`
  element.appendChild(code)
}

const resizeSvg = (svg) => {
  const viewBox = svg.viewBox && svg.viewBox.baseVal
  if (!viewBox || !viewBox.width || !viewBox.height) return

  const scale = Math.min(360 / viewBox.width, 300 / viewBox.height, 4)
  svg.setAttribute('width', Math.round(viewBox.width * scale))
  svg.setAttribute('height', Math.round(viewBox.height * scale))
}

const draw = (SmilesDrawer, element, theme) => {
  const smiles = element.getAttribute('data-smiles')
  if (!smiles) return

  const key = `${theme}:${smiles}`
  if (element.getAttribute('data-smiles-rendered') === key) return
  element.setAttribute('data-smiles-rendered', key)
  element.textContent = ''

  try {
    SmilesDrawer.parse(
      smiles,
      (tree) => {
        const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg')
        element.appendChild(svg)
        try {
          new SmilesDrawer.SvgDrawer(drawerOptions).draw(tree, svg, theme)
          resizeSvg(svg)
        } catch (error) {
          showError(element, smiles)
        }
      },
      () => showError(element, smiles)
    )
  } catch (error) {
    showError(element, smiles)
  }
}

export const renderSmiles = async (theme = 'light') => {
  if (typeof document === 'undefined') return

  const SmilesDrawer = await loadSmilesDrawer()
  document.querySelectorAll('.smiles[data-smiles]').forEach((element) => {
    draw(SmilesDrawer, element, theme)
  })
}

export default (md) => {
  const fallback = md.renderer.rules.fence.bind(md.renderer.rules)

  md.renderer.rules.fence = (tokens, idx, options, env, slf) => {
    const token = tokens[idx]
    const language = (token.info || '').trim().split(/\s+/)[0].toLowerCase()

    if (!aliases.has(language)) {
      return fallback(tokens, idx, options, env, slf)
    }

    const molecules = token.content
      .split('\n')
      .map((line) => line.trim())
      .filter(Boolean)

    if (molecules.length === 0) {
      return fallback(tokens, idx, options, env, slf)
    }

    const items = molecules
      .map((smiles) => `<div class="smiles" data-smiles="${escapeAttribute(smiles)}"></div>`)
      .join('')

    return `<div class="smiles-group">${items}</div>\n`
  }
}
