export type Mode = "insert" | "normal" | "visual" | "visual-line"

export type Motion =
  | "left"
  | "right"
  | "up"
  | "down"
  | "wordForward"
  | "wordBackward"
  | "wordEnd"
  | "WORDForward"
  | "WORDBackward"
  | "WORDEnd"
  | "lineStart"
  | "lineFirstNonBlank"
  | "lineEnd"
  | "bufferStart"
  | "bufferEnd"
  | "nextMessage"
  | "previousMessage"
  | "lineDown"
  | "lineUp"
  | "halfPageDown"
  | "halfPageUp"
  | "pageDown"
  | "pageUp"

export type TextObject = {
  object: string
  around: boolean
}

export type Operator = "delete" | "change" | "yank"

export type Action =
  | { type: "mode"; mode: Mode }
  | { type: "insert"; at: "cursor" | "after" | "lineStart" | "lineEnd" | "openBelow" | "openAbove" }
  | { type: "motion"; motion: Motion; count: number; select: boolean }
  | { type: "operator"; operator: Operator; count: number; motion?: Motion; textObject?: TextObject; line?: boolean }
  | { type: "deleteChar"; count: number }
  | { type: "replaceChar"; count: number; char: string }
  | { type: "changeChar"; count: number }
  | { type: "deleteLine"; count: number }
  | { type: "changeLine"; count: number }
  | { type: "yankLine"; count: number }
  | { type: "paste"; count: number; before: boolean }
  | { type: "undo" }
  | { type: "redo" }
  | { type: "visual"; line: boolean }
  | { type: "visualOperator"; operator: Operator }
  | { type: "clearSelection" }
  | { type: "session"; command: string }
  | { type: "help" }
  | { type: "noop" }

export type Key = {
  name: string
  sequence?: string
  ctrl?: boolean
  shift?: boolean
  meta?: boolean
  super?: boolean
  hyper?: boolean
}

export type EngineState = {
  mode: Mode
  count: number
  operator?: Operator
  operatorCount: number
  pending?: "g" | "textObject" | "replace"
  around?: boolean
}

export type EngineResult = {
  state: EngineState
  actions: Action[]
  consume: boolean
}

const MOTION_KEYS: Record<string, Motion> = {
  h: "left",
  l: "right",
  j: "down",
  k: "up",
  w: "wordForward",
  b: "wordBackward",
  e: "wordEnd",
  n: "nextMessage",
}

const SHIFT_MOTION_KEYS: Record<string, Motion> = {
  W: "WORDForward",
  B: "WORDBackward",
  E: "WORDEnd",
  N: "previousMessage",
}

const OBJECT_KEYS = new Set(["w", "W", '"', "'", "`", "(", ")", "[", "]", "{", "}", "b", "B"])

function normalizedName(key: Key) {
  if (key.name === "esc") return "escape"
  if (key.name === "enter") return "return"
  if (key.name === "pgup") return "pageup"
  if (key.name === "pgdown") return "pagedown"
  return key.name
}

function shifted(key: Key) {
  if (key.shift) return true
  const name = key.name
  return name.length === 1 && name >= "A" && name <= "Z"
}

function letter(key: Key) {
  return key.name.length === 1 ? key.name.toLowerCase() : key.name.toLowerCase()
}

function isEscape(key: Key) {
  return normalizedName(key) === "escape" || (key.ctrl && key.name === "[")
}

function motionFor(key: Key): Motion | undefined {
  if (key.ctrl) return
  if (key.name === "G" || (letter(key) === "g" && shifted(key))) return "bufferEnd"
  if (shifted(key)) {
    const shiftedMotion = SHIFT_MOTION_KEYS[key.name.toUpperCase()]
    if (shiftedMotion) return shiftedMotion
  }
  if (key.name === "$") return "lineEnd"
  if (key.name === "^") return "lineFirstNonBlank"
  if (key.name === "0") return "lineStart"
  return MOTION_KEYS[key.name]
}

function ctrlMotion(key: Key): Motion | undefined {
  if (!key.ctrl) return
  if (key.name === "d") return "halfPageDown"
  if (key.name === "u") return "halfPageUp"
  if (key.name === "f") return "pageDown"
  if (key.name === "b") return "pageUp"
  if (key.name === "n") return "down"
  if (key.name === "p") return "up"
}

function resetPending(state: EngineState): EngineState {
  return { ...state, count: 0, operator: undefined, operatorCount: 1, pending: undefined, around: undefined }
}

function actionMode(mode: Mode): Action {
  return { type: "mode", mode }
}

function operatorAction(
  operator: Operator,
  count: number,
  input: { motion?: Motion; textObject?: TextObject; line?: boolean },
): Action {
  return {
    type: "operator",
    operator,
    count: count || 1,
    motion: input.motion,
    textObject: input.textObject,
    line: input.line,
  }
}

export function createEngine(mode: Mode = "insert") {
  let state: EngineState = { mode, count: 0, operatorCount: 1 }

  const setMode = (next: Mode) => {
    state = resetPending({ ...state, mode: next })
  }

  const finishOperator = (
    actions: Action[],
    operator: Operator,
    count: number,
    input: { motion?: Motion; textObject?: TextObject; line?: boolean },
  ) => {
    actions.push(operatorAction(operator, count, input))
    if (operator === "change") actions.push(actionMode("insert"))
    state = resetPending(state)
    return { state: { ...state }, actions, consume: true }
  }

  const handleOperator = (key: Key): EngineResult | undefined => {
    const operator = state.operator
    if (!operator) return
    const actions: Action[] = []
    const name = letter(key)

    if (isEscape(key) || key.ctrl) {
      state = resetPending(state)
      return { state: { ...state }, actions: [actionMode(state.mode)], consume: true }
    }

    if (state.pending === "g") {
      if (name === "g" && !shifted(key) && !key.ctrl) {
        const total = state.operatorCount * (state.count || 1)
        return finishOperator(actions, operator, total, { motion: "bufferStart" })
      }
      state = resetPending(state)
      return { state: { ...state }, actions, consume: true }
    }

    if (state.pending === "textObject") {
      if (!OBJECT_KEYS.has(key.name) && !OBJECT_KEYS.has(name)) {
        state = resetPending(state)
        return { state: { ...state }, actions, consume: true }
      }
      const object = key.name.length === 1 ? key.name : name
      const total = state.operatorCount * (state.count || 1)
      return finishOperator(actions, operator, total, {
        textObject: { object, around: state.around === true },
      })
    }

    if (key.name === "g" && !shifted(key)) {
      state = { ...state, pending: "g" }
      return { state: { ...state }, actions, consume: true }
    }

    if (!shifted(key) && (name === "i" || name === "a")) {
      state = { ...state, pending: "textObject", around: name === "a" }
      return { state: { ...state }, actions, consume: true }
    }

    if (name === operator[0] && !shifted(key)) {
      const total = state.operatorCount * (state.count || 1)
      return finishOperator(actions, operator, total, { line: true })
    }

    const motion = motionFor(key)
    if (motion) {
      const total = state.operatorCount * (state.count || 1)
      return finishOperator(actions, operator, total, { motion })
    }

    const ctrl = ctrlMotion(key)
    if (ctrl) {
      const total = state.operatorCount * (state.count || 1)
      return finishOperator(actions, operator, total, { motion: ctrl })
    }

    if (key.name >= "1" && key.name <= "9") {
      state = { ...state, count: state.count * 10 + Number(key.name) }
      return { state: { ...state }, actions, consume: true }
    }
    if (key.name === "0" && state.count > 0) {
      state = { ...state, count: state.count * 10 }
      return { state: { ...state }, actions, consume: true }
    }

    state = resetPending(state)
    return { state: { ...state }, actions, consume: true }
  }

  const handleNormal = (key: Key): EngineResult => {
    const actions: Action[] = []
    const name = letter(key)

    if (isEscape(key)) {
      if (state.pending || state.operator || state.count) {
        state = resetPending(state)
        return { state: { ...state }, actions: [actionMode("normal")], consume: true }
      }
      state = resetPending({ ...state, mode: "insert" })
      return { state: { ...state }, actions: [actionMode("insert")], consume: true }
    }

    if (key.ctrl) {
      if (key.name === "c") {
        state = resetPending({ ...state, mode: "insert" })
        return { state: { ...state }, actions: [actionMode("insert")], consume: true }
      }
      if (key.name === "r") {
        state = resetPending(state)
        return { state: { ...state }, actions: [{ type: "redo" }], consume: true }
      }
      const ctrl = ctrlMotion(key)
      if (ctrl) {
        const count = state.count || 1
        state = resetPending(state)
        return { state: { ...state }, actions: [{ type: "motion", motion: ctrl, count, select: false }], consume: true }
      }
      state = resetPending(state)
      return { state: { ...state }, actions, consume: true }
    }

    if (state.operator) {
      const handled = handleOperator(key)
      if (handled) return handled
    }

    if (state.pending === "g") {
      if (name === "g" && !shifted(key)) {
        const count = state.count || 1
        state = resetPending(state)
        return { state: { ...state }, actions: [{ type: "motion", motion: "bufferStart", count, select: false }], consume: true }
      }
      state = resetPending(state)
      return { state: { ...state }, actions, consume: true }
    }

    if (state.pending === "replace") {
      const char = key.name === "space" ? " " : key.sequence && !key.ctrl && !key.meta ? key.sequence : key.name
      if (isEscape(key) || key.ctrl || Array.from(char).length !== 1) {
        state = resetPending(state)
        return { state: { ...state }, actions, consume: true }
      }
      const total = state.count || 1
      state = resetPending(state)
      return { state: { ...state }, actions: [{ type: "replaceChar", count: total, char }], consume: true }
    }

    if (key.name >= "1" && key.name <= "9") {
      state = { ...state, count: state.count * 10 + Number(key.name) }
      return { state: { ...state }, actions, consume: true }
    }
    if (key.name === "0" && state.count > 0) {
      state = { ...state, count: state.count * 10 }
      return { state: { ...state }, actions, consume: true }
    }

    if (key.name === "g" && !shifted(key)) {
      state = { ...state, pending: "g" }
      return { state: { ...state }, actions, consume: true }
    }

    const count = state.count || 1
    const finish = (result: Action[]) => {
      state = resetPending(state)
      return { state: { ...state }, actions: result, consume: true }
    }

    const motion = motionFor(key)
    if (motion) return finish([{ type: "motion", motion, count, select: false }])

    if (!shifted(key) && (name === "d" || name === "c" || name === "y")) {
      state = { ...state, operator: name === "d" ? "delete" : name === "c" ? "change" : "yank", operatorCount: count, count: 0 }
      return { state: { ...state }, actions, consume: true }
    }

    if (normalizedName(key) === "return") return finish([actionMode("insert")])

    if (name === "i") return finish([{ type: "insert", at: shifted(key) ? "lineStart" : "cursor" }])
    if (name === "a") return finish([{ type: "insert", at: shifted(key) ? "lineEnd" : "after" }])
    if (name === "o") return finish([{ type: "insert", at: shifted(key) ? "openAbove" : "openBelow" }])

    if (name === "v") return finish([{ type: "visual", line: shifted(key) }])

    if (name === "x") return finish([{ type: "deleteChar", count }])
    if (name === "r" && !shifted(key)) {
      state = { ...state, pending: "replace" }
      return { state: { ...state }, actions, consume: true }
    }
    if (name === "s") {
      return shifted(key) ? finish([{ type: "changeLine", count }]) : finish([{ type: "changeChar", count }])
    }
    if (name === "d" && shifted(key)) return finish([operatorAction("delete", count, { motion: "lineEnd" })])
    if (name === "c" && shifted(key)) return finish([operatorAction("change", count, { motion: "lineEnd" }), actionMode("insert")])
    if (name === "y" && shifted(key)) return finish([operatorAction("yank", count, { line: true })])

    if (name === "p") return finish([{ type: "paste", count, before: shifted(key) }])
    if (name === "u") return finish([{ type: "undo" }])
    if (name === "?") return finish([{ type: "help" }])
    if (key.name === ":" || (key.shift && name === ";")) {
      return finish([{ type: "session", command: "command.palette.show" }, actionMode("insert")])
    }

    return finish([])
  }

  const handleVisual = (key: Key): EngineResult => {
    const actions: Action[] = []
    const name = letter(key)
    const count = state.count || 1

    if (isEscape(key)) {
      state = resetPending({ ...state, mode: "normal" })
      return { state: { ...state }, actions: [actionMode("normal"), { type: "clearSelection" }], consume: true }
    }

    if (key.ctrl && key.name === "c") {
      state = resetPending({ ...state, mode: "insert" })
      return { state: { ...state }, actions: [actionMode("insert"), { type: "clearSelection" }], consume: true }
    }

    if (state.pending === "g") {
      if (name === "g" && !shifted(key)) {
        state = resetPending(state)
        return { state: { ...state }, actions: [{ type: "motion", motion: "bufferStart", count, select: true }], consume: true }
      }
      state = resetPending(state)
      return { state: { ...state }, actions, consume: true }
    }

    if (key.name === "g" && !shifted(key)) {
      state = { ...state, pending: "g" }
      return { state: { ...state }, actions, consume: true }
    }

    if (key.name >= "1" && key.name <= "9") {
      state = { ...state, count: state.count * 10 + Number(key.name) }
      return { state: { ...state }, actions, consume: true }
    }
    if (key.name === "0" && state.count > 0) {
      state = { ...state, count: state.count * 10 }
      return { state: { ...state }, actions, consume: true }
    }

    const finish = (result: Action[]) => {
      state = resetPending(state)
      return { state: { ...state }, actions: result, consume: true }
    }

    const motion = motionFor(key)
    if (motion) return finish([{ type: "motion", motion, count, select: true }])

    if (name === "v" && !shifted(key)) return finish([{ type: "clearSelection" }, actionMode("normal")])
    if (name === "v" && shifted(key)) {
      state = resetPending({ ...state, mode: "visual-line" })
      return { state: { ...state }, actions: [{ type: "visual", line: true }], consume: true }
    }
    if (name === "y") return finish([{ type: "visualOperator", operator: "yank" }, actionMode("normal")])
    if (name === "d" || name === "x") return finish([{ type: "visualOperator", operator: "delete" }, actionMode("normal")])
    if (name === "c") return finish([{ type: "visualOperator", operator: "change" }, actionMode("insert")])

    return finish([])
  }

  const handle = (key: Key): EngineResult => {
    if (state.mode === "insert") {
      if (isEscape(key)) {
        state = resetPending({ ...state, mode: "normal" })
        return { state: { ...state }, actions: [actionMode("normal")], consume: true }
      }
      return { state: { ...state }, actions: [], consume: false }
    }
    if (state.mode === "visual" || state.mode === "visual-line") return handleVisual(key)
    return handleNormal(key)
  }

  return {
    state: () => ({ ...state }),
    setMode,
    handle,
  }
}
