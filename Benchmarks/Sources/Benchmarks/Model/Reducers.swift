@_implementationOnly import ComposableArchitecture

let simpleReducer = Reducer<SimpleState, SimpleAction, Void> {
  state, action, _ in
  switch action {
  case .action0:
    state.value0 += "0"
    return .none
  case .action1:
    state.value1 += "1"
    return .none
  case .action2:
    state.value2 += "2"
    return .none
  case .action3:
    state.value3 += "3"
    return .none
  case .action4:
    state.value4 += "4"
    return .none
  case .action5:
    state.value5 += "5"
    return .none
  case .action6:
    state.value6 += "6"
    return .none
  case .action7:
    state.value7 += "7"
    return .none
  case .action8:
    state.value8 += "8"
    return .none
  case .action9:
    state.value9 += "9"
    return .none
//  case .action10:
//    state.value10 += "10"
//    return .none
//  case .action11:
//    state.value11 += "11"
//    return .none
//  case .action12:
//    state.value12 += "12"
//    return .none
//  case .action13:
//    state.value13 += "13"
//    return .none
//  case .action14:
//    state.value14 += "14"
//    return .none
//  case .action15:
//    state.value15 += "15"
//    return .none
//  case .action16:
//    state.value16 += "16"
//    return .none
//  case .action17:
//    state.value17 += "17"
//    return .none
//  case .action18:
//    state.value18 += "18"
//    return .none
//  case .action19:
//    state.value19 += "19"
//    return .none
//  case .action20:
//    state.value20 += "20"
//    return .none
//  case .action21:
//    state.value21 += "21"
//    return .none
//  case .action22:
//    state.value22 += "22"
//    return .none
//  case .action23:
//    state.value23 += "23"
//    return .none
//  case .action24:
//    state.value24 += "24"
//    return .none
//  case .action25:
//    state.value25 += "25"
//    return .none
//  case .action26:
//    state.value26 += "26"
//    return .none
//  case .action27:
//    state.value27 += "27"
//    return .none
//  case .action28:
//    state.value28 += "28"
//    return .none
//  case .action29:
//    state.value29 += "29"
//    return .none
//  case .action30:
//    state.value30 += "30"
//    return .none
//  case .action31:
//    state.value31 += "31"
//    return .none
//  case .action32:
//    state.value32 += "32"
//    return .none
//  case .action33:
//    state.value33 += "33"
//    return .none
//  case .action34:
//    state.value34 += "34"
//    return .none
//  case .action35:
//    state.value35 += "35"
//    return .none
//  case .action36:
//    state.value36 += "36"
//    return .none
//  case .action37:
//    state.value37 += "37"
//    return .none
//  case .action38:
//    state.value38 += "38"
//    return .none
//  case .action39:
//    state.value39 += "39"
//    return .none
//  case .action40:
//    state.value40 += "40"
//    return .none
//  case .action41:
//    state.value41 += "41"
//    return .none
//  case .action42:
//    state.value42 += "42"
//    return .none
//  case .action43:
//    state.value43 += "43"
//    return .none
//  case .action44:
//    state.value44 += "44"
//    return .none
//  case .action45:
//    state.value45 += "45"
//    return .none
//  case .action46:
//    state.value46 += "46"
//    return .none
//  case .action47:
//    state.value47 += "47"
//    return .none
//  case .action48:
//    state.value48 += "48"
//    return .none
//  case .action49:
//    state.value49 += "49"
//    return .none
  }
}

let composedReducer: Reducer<ComposedState, ComposedAction, Void> = .combine([
  simpleReducer.pullback(state: \ComposedState.value0, action: /ComposedAction.action0, environment: { _ in ()}),
  simpleReducer.pullback(state: \ComposedState.value1, action: /ComposedAction.action1, environment: { _ in ()}),
  simpleReducer.pullback(state: \ComposedState.value2, action: /ComposedAction.action2, environment: { _ in ()}),
  simpleReducer.pullback(state: \ComposedState.value3, action: /ComposedAction.action3, environment: { _ in ()}),
  simpleReducer.pullback(state: \ComposedState.value4, action: /ComposedAction.action4, environment: { _ in ()}),
  simpleReducer.pullback(state: \ComposedState.value5, action: /ComposedAction.action5, environment: { _ in ()}),
  simpleReducer.pullback(state: \ComposedState.value6, action: /ComposedAction.action6, environment: { _ in ()}),
  simpleReducer.pullback(state: \ComposedState.value7, action: /ComposedAction.action7, environment: { _ in ()}),
  simpleReducer.pullback(state: \ComposedState.value8, action: /ComposedAction.action8, environment: { _ in ()}),
  simpleReducer.pullback(state: \ComposedState.value9, action: /ComposedAction.action9, environment: { _ in ()}),
//  simpleReducer.pullback(state: \ComposedState.value10, action: /ComposedAction.action10, environment: { _ in ()}),
//  simpleReducer.pullback(state: \ComposedState.value11, action: /ComposedAction.action11, environment: { _ in ()}),
//  simpleReducer.pullback(state: \ComposedState.value12, action: /ComposedAction.action12, environment: { _ in ()}),
//  simpleReducer.pullback(state: \ComposedState.value13, action: /ComposedAction.action13, environment: { _ in ()}),
//  simpleReducer.pullback(state: \ComposedState.value14, action: /ComposedAction.action14, environment: { _ in ()}),
//  simpleReducer.pullback(state: \ComposedState.value15, action: /ComposedAction.action15, environment: { _ in ()}),
//  simpleReducer.pullback(state: \ComposedState.value16, action: /ComposedAction.action16, environment: { _ in ()}),
//  simpleReducer.pullback(state: \ComposedState.value17, action: /ComposedAction.action17, environment: { _ in ()}),
//  simpleReducer.pullback(state: \ComposedState.value18, action: /ComposedAction.action18, environment: { _ in ()}),
//  simpleReducer.pullback(state: \ComposedState.value19, action: /ComposedAction.action19, environment: { _ in ()}),
//  simpleReducer.pullback(state: \ComposedState.value20, action: /ComposedAction.action20, environment: { _ in ()}),
//  simpleReducer.pullback(state: \ComposedState.value21, action: /ComposedAction.action21, environment: { _ in ()}),
//  simpleReducer.pullback(state: \ComposedState.value22, action: /ComposedAction.action22, environment: { _ in ()}),
//  simpleReducer.pullback(state: \ComposedState.value23, action: /ComposedAction.action23, environment: { _ in ()}),
//  simpleReducer.pullback(state: \ComposedState.value24, action: /ComposedAction.action24, environment: { _ in ()}),
//  simpleReducer.pullback(state: \ComposedState.value25, action: /ComposedAction.action25, environment: { _ in ()}),
//  simpleReducer.pullback(state: \ComposedState.value26, action: /ComposedAction.action26, environment: { _ in ()}),
//  simpleReducer.pullback(state: \ComposedState.value27, action: /ComposedAction.action27, environment: { _ in ()}),
//  simpleReducer.pullback(state: \ComposedState.value28, action: /ComposedAction.action28, environment: { _ in ()}),
//  simpleReducer.pullback(state: \ComposedState.value29, action: /ComposedAction.action29, environment: { _ in ()}),
//  simpleReducer.pullback(state: \ComposedState.value30, action: /ComposedAction.action30, environment: { _ in ()}),
//  simpleReducer.pullback(state: \ComposedState.value31, action: /ComposedAction.action31, environment: { _ in ()}),
//  simpleReducer.pullback(state: \ComposedState.value32, action: /ComposedAction.action32, environment: { _ in ()}),
//  simpleReducer.pullback(state: \ComposedState.value33, action: /ComposedAction.action33, environment: { _ in ()}),
//  simpleReducer.pullback(state: \ComposedState.value34, action: /ComposedAction.action34, environment: { _ in ()}),
//  simpleReducer.pullback(state: \ComposedState.value35, action: /ComposedAction.action35, environment: { _ in ()}),
//  simpleReducer.pullback(state: \ComposedState.value36, action: /ComposedAction.action36, environment: { _ in ()}),
//  simpleReducer.pullback(state: \ComposedState.value37, action: /ComposedAction.action37, environment: { _ in ()}),
//  simpleReducer.pullback(state: \ComposedState.value38, action: /ComposedAction.action38, environment: { _ in ()}),
//  simpleReducer.pullback(state: \ComposedState.value39, action: /ComposedAction.action39, environment: { _ in ()}),
//  simpleReducer.pullback(state: \ComposedState.value40, action: /ComposedAction.action40, environment: { _ in ()}),
//  simpleReducer.pullback(state: \ComposedState.value41, action: /ComposedAction.action41, environment: { _ in ()}),
//  simpleReducer.pullback(state: \ComposedState.value42, action: /ComposedAction.action42, environment: { _ in ()}),
//  simpleReducer.pullback(state: \ComposedState.value43, action: /ComposedAction.action43, environment: { _ in ()}),
//  simpleReducer.pullback(state: \ComposedState.value44, action: /ComposedAction.action44, environment: { _ in ()}),
//  simpleReducer.pullback(state: \ComposedState.value45, action: /ComposedAction.action45, environment: { _ in ()}),
//  simpleReducer.pullback(state: \ComposedState.value46, action: /ComposedAction.action46, environment: { _ in ()}),
//  simpleReducer.pullback(state: \ComposedState.value47, action: /ComposedAction.action47, environment: { _ in ()}),
//  simpleReducer.pullback(state: \ComposedState.value48, action: /ComposedAction.action48, environment: { _ in ()}),
//  simpleReducer.pullback(state: \ComposedState.value49, action: /ComposedAction.action49, environment: { _ in ()})
])
