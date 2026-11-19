// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Verilator contributors
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

class Index;
  rand bit [3:0] idx;
endclass

class Payload;
  bit flag;
endclass

class Entry;
  Payload payload;
  bit mark;
  rand bit [64:0] tag;
endclass

class NestedIndex;
  rand Index subobj = new;
  Entry entries[16];
  constraint marked { entries[subobj.idx].mark == 1; }

  function new();
    foreach (entries[i]) entries[i] = new;
  endfunction
endclass

class DirectIndex;
  rand int idx;
  Entry entries[9:6];
  bit [64:0] target;
  constraint pick {
    idx inside {[6:9]};
    entries[idx].tag == target;
  }

  function new();
    foreach (entries[i]) begin
      entries[i] = new;
      entries[i].tag = 65'h1_0000_0000_0000_0000 + 65'(i);
    end
  endfunction
endclass

class SparseIndex;
  rand int idx;
  Entry entries[3];
  int pin_idx;
  bit bypass;
  constraint pin_index { idx == pin_idx; }
  constraint check_field { if (!bypass) entries[idx].payload.flag == 0; }
endclass

module t;
  initial begin
    static NestedIndex nested = new;
    static DirectIndex direct = new;
    static SparseIndex sparse = new;
    int ok;
    foreach (nested.entries[i]) begin
      nested.subobj.idx = 0;
      nested.entries[i].mark = 1;
      ok = nested.randomize();
      `checkd(ok, 1)
      `checkd(int'(nested.subobj.idx), i)
      nested.entries[i].mark = 0;
    end
    ok = nested.randomize();
    `checkd(ok, 0)

    foreach (direct.entries[i]) begin
      direct.idx = 6;
      direct.target = direct.entries[i].tag;
      ok = direct.randomize();
      `checkd(ok, 1)
      `checkd(direct.idx, i)
      `checkd(direct.entries[i].tag, 65'h1_0000_0000_0000_0000 + 65'(i))
    end
    direct.idx.rand_mode(0);
    ok = direct.randomize();
    `checkd(ok, 1)
    `checkd(direct.idx, 6)
    direct.target = direct.entries[9].tag;
    ok = direct.randomize();
    `checkd(ok, 0)
    direct.idx.rand_mode(1);
    ok = direct.randomize();
    `checkd(ok, 1)
    `checkd(direct.idx, 9)

    sparse.entries[1] = new;
    sparse.entries[1].payload = new;
    sparse.entries[2] = new;
    sparse.pin_index.constraint_mode(0);
    ok = sparse.randomize();
    `checkd(ok, 1)
    `checkd(sparse.idx, 1)
    sparse.pin_index.constraint_mode(1);
    sparse.pin_idx = 2;
    ok = sparse.randomize();
    `checkd(ok, 0)
    sparse.pin_idx = 5;
    ok = sparse.randomize();
    `checkd(ok, 0)
    sparse.bypass = 1;
    ok = sparse.randomize();
    `checkd(ok, 1)
    `checkd(sparse.idx, 5)
    ok = sparse.randomize() with { entries[idx].payload.flag == 0; };
    `checkd(ok, 0)
    sparse.pin_idx = 0;
    ok = sparse.randomize() with { entries[idx ^ 1].payload.flag == 0; };
    `checkd(ok, 1)
    `checkd(sparse.idx, 0)

    // The null entry at zero may be skipped by either a state or a solver-dependent guard.
    ok = sparse.randomize() with {
      (idx == 0 || entries[idx].payload.flag);
      ((idx != 0 && entries[idx].payload.flag) == 0);
      (idx == 0 ? 1'b1 : entries[idx].payload.flag);
      (idx != 0 ? entries[idx].payload.flag : 1'b1);
      (bypass ? 1'b1 : entries[idx].payload.flag);
    };
    `checkd(ok, 1)
    `checkd(sparse.idx, 0)
    sparse.pin_idx = 1;
    ok = sparse.randomize() with {
      entries[idx].payload.flag == entries[idx].mark;
    };
    `checkd(ok, 1)
    `checkd(sparse.idx, 1)

    $write("*-* All Finished *-*\n");
    $finish;
  end
endmodule
