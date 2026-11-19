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
endclass

class Group;
  Entry entries[2];
  function new();
    foreach (entries[i]) entries[i] = new;
  endfunction
endclass

class RandArray;
  rand Entry entries[4];
  rand int unsigned idx;
  constraint marked {entries[idx].mark;}

  function new();
    foreach (entries[i]) entries[i] = new;
    entries[1].mark = 1;
  endfunction

  function int pick(int pin);
    return std::randomize(
        idx
    ) with {
      idx == pin;
      entries[idx].mark;
    };
  endfunction
endclass

class Nested;
  rand Group groups[2];
  rand int unsigned row, col;
  constraint marked {groups[row].entries[col].mark;}
  function new();
    foreach (groups[i]) groups[i] = new;
    groups[1].entries[1].mark = 1;
  endfunction
endclass

class Mixed;
  Entry entries[2][2];
  rand int row;
  int col;
  bit [64:0] native_idx;
  constraint marked {entries[row][col].mark;}
  // A mutable 65-bit state index can select either column.
  // verilator lint_off WIDTHTRUNC
  constraint native_read {entries[0][native_idx].mark;}
  // verilator lint_on WIDTHTRUNC
  function new();
    foreach (entries[i, j]) entries[i][j] = new;
    entries[0][0].mark = 1;
  endfunction
endclass

class Shifted;
  rand bit [31:0] idx;
  Entry entries[-6:3];
  constraint marked {entries[idx].mark;}
  function new();
    entries[-6] = new;
    entries[-6].mark = 1;
    entries[1] = new;
    entries[1].mark = 1;
  endfunction
endclass

class Guarded;
  Entry entries[4];
  Entry holder;
  rand bit [1:0] idx;
  bit skip;
  constraint guarded {
    (skip ? 1'b1 : entries[int'(idx)+holder.offset].mark);
    (!skip ? entries[int'(idx)+holder.offset].mark : 1'b1);
    (skip || entries[int'(idx)+holder.offset].mark);
    (!skip -> entries[int'(idx)+holder.offset].mark);
    ((!skip && entries[int'(idx)+holder.offset].mark) == !skip);
    if (!skip) entries[int'(idx)+holder.offset].mark;
  }
endclass

module t;
  initial begin
    static RandArray r = new;
    static Nested n = new;
    static Mixed m = new;
    static Shifted s = new;
    static Guarded g = new;
    int ok;

    r.idx = 0;
    ok = r.randomize();
    `checkd(ok, 1)
    `checkd(r.idx, 1)
    ok = r.randomize() with {idx == 5;};
    `checkd(ok, 0)
    ok = r.pick(5);
    `checkd(ok, 0)
    ok = r.pick(1);
    `checkd(ok, 1)
    `checkd(r.idx, 1)

    ok = n.randomize() with {
      row == 3;
      col == 1;
    };
    `checkd(ok, 0)
    ok = n.randomize();
    `checkd(ok, 1)
    `checkd(n.row, 1)
    `checkd(n.col, 1)

    m.col = 2;
    ok = m.randomize() with {row == 0;};
    `checkd(ok, 0)
    m.col = 0;
    ok = m.randomize();
    `checkd(ok, 1)
    `checkd(m.row, 0)
    m.native_idx = 1;
    ok = m.randomize();
    `checkd(ok, 0)

    ok = s.randomize() with {idx == 32'hffff_fffa;};
    `checkd(ok, 0)
    ok = s.randomize();
    `checkd(ok, 1)
    `checkd(s.idx, 1)

    g.skip = 1;
    ok = g.randomize();
    `checkd(ok, 1)
    ok = g.randomize() with {
      idx == 0;
      (idx == 0 || entries[int'(idx)+holder.offset].mark);
    };
    `checkd(ok, 1)
    `checkd(g.idx, 0)
    ok = g.randomize() with {
      idx == 1;
      (idx == 0 || entries[int'(idx)+holder.offset].mark);
    };
    `checkd(ok, 0)
    g.skip = 0;
    g.holder = new;
    g.holder.offset = 1;
    g.entries[2] = new;
    g.entries[2].mark = 1;
    ok = g.randomize();
    `checkd(ok, 1)
    `checkd(int'(g.idx), 1)
    $write("*-* All Finished *-*\n");
    $finish;
  end
endmodule
