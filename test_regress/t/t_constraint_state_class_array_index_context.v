// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Verilator contributors
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

class Entry;
  bit mark;
  int offset;
  function int get_offset();
    return offset;
  endfunction
endclass

class NativeOnly;
  Entry entries[4];
  bit [64:0] state_idx;
  // verilator lint_off WIDTHTRUNC
  constraint marked {entries[state_idx].mark;}
  // verilator lint_on WIDTHTRUNC
endclass

class FunctionIndex;
  rand int idx;
  Entry entries[4];
  function bit marked(int i);
    return entries[i].mark;
  endfunction
  constraint pick {marked(idx);}
endclass

class GuardedComparison;
  rand int idx;
  Entry entries[4], holder;
  bit bypass;
  function bit marked(int i);
    return entries[i].mark;
  endfunction
  constraint compare {bypass || (entries[idx].mark == holder.mark);}
  constraint compare_func {bypass || (marked(idx) == holder.mark);}
endclass

class Reduced;
  rand bit [1:0] ids[2];
  rand int idx;
  rand bit dummy[1];
  Entry entries[4];
  constraint one {ids.sum() with (int'(entries[item].mark)) == 1;}
endclass

module t;
  Entry entries[4];
  int unsigned idx;
  bit dummy[1];
  function automatic int pick(int unsigned pin);
    return std::randomize(
        idx
    ) with {
      idx == pin;
      dummy.sum() with (int'(entries[idx].mark)) == 1;
    };
  endfunction

  initial begin
    static NativeOnly n = new;
    static FunctionIndex f = new;
    static GuardedComparison g = new;
    static Reduced r = new;
    int ok;

    foreach (n.entries[i]) n.entries[i] = new;
    n.entries[1].mark = 1;
    n.state_idx = 1;
    ok = n.randomize();
    `checkd(ok, 1)
    n.state_idx = 0;
    ok = n.randomize();
    `checkd(ok, 0)

    foreach (f.entries[i]) f.entries[i] = new;
    f.entries[0].mark = 1;
    `checkd(f.marked(0), 1'b1)
    `checkd(f.marked(1), 1'b0)
    ok = f.randomize() with {idx == 4;};
    `checkd(ok, 0)
    ok = f.randomize();
    `checkd(ok, 1)
    `checkd(f.idx, 0)

    g.bypass = 1;
    ok = g.randomize() with {idx == 7;};
    `checkd(ok, 1)
    ok = g.randomize() with {
      idx == 0;
      (idx == 0 || entries[idx+holder.get_offset()].mark);
    };
    `checkd(ok, 1)
    ok = g.randomize() with {
      idx == 1;
      (idx == 0 || entries[idx+holder.get_offset()].mark);
    };
    `checkd(ok, 0)
    g.bypass = 0;
    ok = g.randomize();
    `checkd(ok, 0)
    g.holder = new;
    g.entries[2] = new;
    ok = g.randomize();
    `checkd(ok, 1)
    `checkd(g.idx, 2)

    r.entries[0] = new;
    r.entries[1] = new;
    r.entries[1].mark = 1;
    ok = r.randomize() with {
      ids[0] == 0;
      ids[1] == 1;
    };
    `checkd(ok, 1)
    ok = r.randomize() with {
      ids[0] == 1;
      ids[1] == 0;
    };
    `checkd(ok, 1)
    ok = r.randomize() with {
      ids[0] == 1;
      ids[1] == 1;
    };
    `checkd(ok, 0)
    ok = r.randomize() with {
      ids[0] == 3;
      ids[1] == 1;
    };
    `checkd(ok, 0)

    ok = r.randomize() with {
      idx == 5;
      dummy.sum() with (int'(entries[idx].mark)) == 1;
    };
    `checkd(ok, 0)
    ok = r.randomize() with {
      idx == 1;
      dummy.sum() with (int'(entries[idx].mark)) == 1;
    };
    `checkd(ok, 1)

    entries[1] = new;
    entries[1].mark = 1;
    ok = pick(5);
    `checkd(ok, 0)
    ok = pick(1);
    `checkd(ok, 1)
    `checkd(idx, 32'd1)

    $write("*-* All Finished *-*\n");
    $finish;
  end
endmodule
