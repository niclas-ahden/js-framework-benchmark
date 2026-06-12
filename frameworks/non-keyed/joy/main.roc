app [Model, init!, update!, render] {
    # Joy lives next to this benchmark checkout (../../../../joy). Local-only: this path
    # assumes the `joy` repo is a sibling of `js-framework-benchmark` under the same parent.
    pf: platform "../../../../joy/platform/main.roc",
    html: "https://github.com/niclas-ahden/joy-html/releases/download/0.11.0/7rgWAa6Gu3IGfdGl1JKxHQyCBVK9IUbZXbDui0jIZSQ.tar.br",
}

# Joy implementation of the js-framework-benchmark table app, non-keyed.
#
# Every event produces a new Model and `render` rebuilds the whole virtual DOM, which
# percy then diffs and patches. percy diffs children by position (no keys), so this
# entry belongs in frameworks/non-keyed.
#
# The rendered DOM mirrors the vanillajs reference (button ids, table/row classes,
# aria-hidden) so the benchmark driver's selectors find everything.

import html.Html exposing [Html, div, h1, button, table, tbody, tr, td, a, span, text]
import html.Attribute exposing [id, class, attribute]
import html.Event
import pf.Action exposing [Action]

Row : { id : U64, label : Str }

Model : {
    rows : List Row,
    # The id of the selected row, or 0 for "none" (ids start at 1).
    selected : U64,
    # Monotonically increasing id source; never reset, matching the reference impl so
    # the first row after run N has id N*1000+1.
    next_id : U64,
}

init! : Str => Model
init! = |_flags|
    { rows: [], selected: 0, next_id: 1 }

Ev : [Run, RunLots, Add, Update, Clear, Swap, Select U64, Remove U64]

update! : Model, Str, List U8 => Action Model
update! = |model, raw, _payload|
    when decode_ev(raw) is
        Run -> create(model, 1000)
        RunLots -> create(model, 10000)
        Add ->
            new_rows = build(1000, model.next_id)
            { model & rows: List.concat(model.rows, new_rows), next_id: model.next_id + 1000 }
            |> Action.update

        Update ->
            new_rows =
                List.map_with_index(model.rows, |row, i|
                    if Num.rem(i, 10) == 0 then
                        { row & label: Str.concat(row.label, " !!!") }
                    else
                        row)
            { model & rows: new_rows } |> Action.update

        Clear ->
            { model & rows: [], selected: 0 } |> Action.update

        Swap ->
            if List.len(model.rows) > 998 then
                { model & rows: List.swap(model.rows, 1, 998) } |> Action.update
            else
                Action.update(model)

        Select(row_id) ->
            { model & selected: row_id } |> Action.update

        Remove(row_id) ->
            { model & rows: List.keep_if(model.rows, |row| row.id != row_id) }
            |> Action.update

create : Model, U64 -> Action Model
create = |model, count|
    { model & rows: build(count, model.next_id), next_id: model.next_id + count, selected: 0 }
    |> Action.update

build : U64, U64 -> List Row
build = |count, start_id|
    List.range({ start: At(0), end: Before(count) })
    |> List.map(|i|
        row_id = start_id + i
        { id: row_id, label: make_label(row_id) })

# Deterministic "adjective colour noun" label. Content isn't validated by the benchmark
# (only row counts, ids, and that `update` appends " !!!"), so a cheap spread over the
# reference word lists is enough to mimic realistic, varied labels.
make_label : U64 -> Str
make_label = |seed|
    adj = pick(adjectives, seed * 7)
    colour = pick(colours, seed * 13)
    noun = pick(nouns, seed * 17)
    "${adj} ${colour} ${noun}"

pick : List Str, U64 -> Str
pick = |words, n|
    when List.get(words, Num.rem(n, List.len(words))) is
        Ok(word) -> word
        Err(_) -> ""

adjectives : List Str
adjectives = ["pretty", "large", "big", "small", "tall", "short", "long", "handsome", "plain", "quaint", "clean", "elegant", "easy", "angry", "crazy", "helpful", "mushy", "odd", "unsightly", "adorable", "important", "inexpensive", "cheap", "expensive", "fancy"]

colours : List Str
colours = ["red", "yellow", "blue", "green", "pink", "brown", "purple", "brown", "white", "black", "orange"]

nouns : List Str
nouns = ["table", "chair", "house", "bbq", "desk", "car", "pony", "cookie", "sandwich", "burger", "pizza", "mouse", "keyboard"]

render : Model -> Html Model
render = |model|
    div([id("main")], [
        div([class("container")], [
            div([class("jumbotron")], [
                div([class("row")], [
                    div([class("col-md-6")], [h1([], [text("Joy")])]),
                    div([class("col-md-6")], [
                        div([class("row")], [
                            action_button("run", "Create 1,000 rows"),
                            action_button("runlots", "Create 10,000 rows"),
                            action_button("add", "Append 1,000 rows"),
                            action_button("update", "Update every 10th row"),
                            action_button("clear", "Clear"),
                            action_button("swaprows", "Swap Rows"),
                        ]),
                    ]),
                ]),
            ]),
            table([class("table table-hover table-striped test-data")], [
                tbody([id("tbody")], List.map(model.rows, |row| render_row(row, model.selected))),
            ]),
            span([class("preloadicon glyphicon glyphicon-remove"), attribute("aria-hidden", "true")], []),
        ]),
    ])

action_button : Str, Str -> Html Model
action_button = |button_id, label|
    div([class("col-sm-6 smallpad")], [
        button(
            [attribute("type", "button"), class("btn btn-primary btn-block"), id(button_id), Event.on_click(button_id)],
            [text(label)],
        ),
    ])

render_row : Row, U64 -> Html Model
render_row = |{ id: row_id, label }, selected|
    row_attrs = if selected == row_id then [class("danger")] else []
    id_str = Num.to_str(row_id)

    tr(row_attrs, [
        td([class("col-md-1")], [text(id_str)]),
        td([class("col-md-4")], [
            a([class("lbl"), Event.on_click("select:${id_str}")], [text(label)]),
        ]),
        td([class("col-md-1")], [
            a([class("remove"), Event.on_click("remove:${id_str}")], [
                span([class("remove glyphicon glyphicon-remove"), attribute("aria-hidden", "true")], []),
            ]),
        ]),
        td([class("col-md-6")], []),
    ])

decode_ev : Str -> Ev
decode_ev = |raw|
    when raw is
        "run" -> Run
        "runlots" -> RunLots
        "add" -> Add
        "update" -> Update
        "clear" -> Clear
        "swaprows" -> Swap
        _ ->
            when Str.split_first(raw, ":") is
                Ok({ before: "select", after }) -> Select(parse_id(after))
                Ok({ before: "remove", after }) -> Remove(parse_id(after))
                _ -> crash("Unsupported event: ${raw}")

parse_id : Str -> U64
parse_id = |s| Str.to_u64(s) |> Result.with_default(0)
