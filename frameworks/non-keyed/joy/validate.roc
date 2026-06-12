app [main!] {
    pf: platform "https://github.com/growthagent/basic-cli/releases/download/0.27.0/G-A6F5ny0IYDx4hmF3t_YPHUSR28c9ZXMBnh0FEJjwk.tar.br",
    playwright: "https://github.com/niclas-ahden/roc-playwright/releases/download/0.6.0/t00zRqBa9zpsMFrqXnM3wU2Vucyci4nnHdk3y6DBGg4.tar.br",
}

# Local smoke test for the Joy benchmark entry (not part of the official harness). It
# drives the built app in a headless browser and asserts the same DOM facts the
# js-framework-benchmark runner checks (row counts, ids, the danger class, the " !!!"
# update, swap, remove, clear).
#
# Usage: serve the built dist via Joy's test-server, then:
#   BENCH_URL=http://localhost:8081 roc dev validate.roc --linker=legacy

import pf.Arg
import pf.Cmd
import pf.Env
import pf.Stdout

import playwright.Playwright {
    cmd_new: Cmd.new,
    cmd_args: Cmd.args,
    cmd_spawn_grouped!: Cmd.spawn_grouped!,
}

main! : List Arg.Arg => Result {} _
main! = |_args|
    base = Env.var!("BENCH_URL") |> Result.with_default("http://localhost:8081")

    { browser, page } = Playwright.launch_page!(Chromium)?
    Playwright.navigate!(page, "${base}/jsfw/index.html")?
    Playwright.wait_for!(page, "#run", Visible)
    |> Result.map_err(|e| AppDidNotLoad(Inspect.to_str(e)))?

    # create 1,000 rows
    Playwright.click!(page, "#run")?
    Playwright.wait_for!(page, "tbody>tr:nth-of-type(1000)", Attached)
    |> Result.map_err(|e| RunDidNotRender(Inspect.to_str(e)))?
    check!(page, count("tbody>tr"), "1000", "run creates 1000 rows")?
    check!(page, text("tbody>tr:nth-of-type(1)>td:nth-of-type(1)"), "1", "first row id is 1")?

    # update every 10th row -> row 991 (0-based 990) gets ' !!!' appended
    Playwright.click!(page, "#update")?
    check!(page, ends_with("tbody>tr:nth-of-type(991)>td:nth-of-type(2)>a", " !!!"), "true", "update appends ' !!!' to every 10th row")?

    # select row 2 -> exactly one .danger, on row 2
    Playwright.click!(page, "tbody>tr:nth-of-type(2)>td:nth-of-type(2)>a")?
    check!(page, count("tbody>tr.danger"), "1", "select marks exactly one row")?
    check!(page, has_class("tbody>tr:nth-of-type(2)", "danger"), "true", "the selected row is row 2")?

    # swap rows 2 and 999
    id2 = Playwright.evaluate!(page, text("tbody>tr:nth-of-type(2)>td:nth-of-type(1)"))?
    id999 = Playwright.evaluate!(page, text("tbody>tr:nth-of-type(999)>td:nth-of-type(1)"))?
    Playwright.click!(page, "#swaprows")?
    check!(page, text("tbody>tr:nth-of-type(2)>td:nth-of-type(1)"), id999, "swap: row 2 now holds row 999's id")?
    check!(page, text("tbody>tr:nth-of-type(999)>td:nth-of-type(1)"), id2, "swap: row 999 now holds row 2's id")?

    # remove a row via the X span. Dispatch the click in JS rather than via Playwright:
    # without the benchmark's Bootstrap CSS the empty glyphicon span has no size, so
    # Playwright would refuse to click it. The JS click still bubbles to the percy
    # handler on the enclosing <a>, exercising the real remove path.
    _ = Playwright.evaluate!(page, "(()=>{document.querySelector('tbody>tr:nth-of-type(2)>td:nth-of-type(3)>a>span:nth-of-type(1)').click();return 'ok';})()")?
    check!(page, count("tbody>tr"), "999", "remove drops one row")?

    # append 1,000 to a fresh 1,000 -> 2,000
    Playwright.click!(page, "#run")?
    Playwright.click!(page, "#add")?
    Playwright.wait_for!(page, "tbody>tr:nth-of-type(2000)", Attached)
    |> Result.map_err(|e| AddDidNotRender(Inspect.to_str(e)))?
    check!(page, count("tbody>tr"), "2000", "add appends 1000 rows")?

    # clear
    Playwright.click!(page, "#clear")?
    check!(page, count("tbody>tr"), "0", "clear removes all rows")?

    Playwright.close!(browser)?
    Stdout.line!("")?
    Stdout.line!("All checks passed.")?
    Ok({})

# Assert that evaluating `expr` in the page yields exactly `expected`.
check! = |page, expr, expected, label|
    actual = Playwright.evaluate!(page, expr)?
    if actual == expected then
        Stdout.line!("  ✓ ${label}")
    else
        Stdout.line!("  ✗ ${label}: expected ${expected}, got ${actual}")?
        Err(CheckFailed(label))

count : Str -> Str
count = |selector| "String(document.querySelectorAll('${selector}').length)"

text : Str -> Str
text = |selector| "((document.querySelector('${selector}')||{textContent:''}).textContent)"

ends_with : Str, Str -> Str
ends_with = |selector, suffix|
    "String(((document.querySelector('${selector}')||{textContent:''}).textContent).endsWith('${suffix}'))"

has_class : Str, Str -> Str
has_class = |selector, klass|
    "String((document.querySelector('${selector}')||{classList:{contains:()=>false}}).classList.contains('${klass}'))"
